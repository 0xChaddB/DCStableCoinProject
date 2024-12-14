// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


import {GorillaStableCoin} from "./GorillaStableCoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


/* 
* @title GSCEngine
* @author 0xChaddB
*
* This system is designed to be as minimal as possible, and have the tokens maintain a 1token == $1 peg.
* The stablecoin has the properties:
* - Exogenous Collateral
* - pegged to USD
* - Algorithmic Stable
*
* It is similar do DAI if DAI had no governance, no fees, and was only backed by WETH AND WBTC
*
* Our GSC system should always be "overcollateralized". 
*At no point, should the value of all collateral <= the $ backed value of all the GSC.
*
* @notice This contract is the core of the GSC System. It handles all the logic for mining and redeeming GSC, as well a depositing  withdrawing collateral.
* @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
*/

contract GSCEngine is ReentrancyGuard {

    //////////////
    // Errors  //
    /////////////

    error GSCEngine__MustBeMoreThanZero();
    error GSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error GSCEngine__NotAllowedToken();
    error GSCEngine__TransferFailed();
    error GSCENGINE__BreaksHealthFactor(uint256 healthFactor);
    error GSCEngine__MintFailed();
    error GSCEngine__HealthFactorOk();
    error GSCEngine__HealthFactorNotImproved();

    /////////////////////
    // State Variable //
    ////////////////////

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_TRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // means 10% bonus for liquidators


    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountGscMinted) private s_GSCMinted;

    address[] private s_collateralTokens;

    GorillaStableCoin private immutable i_gsc;

    /////////////////
    //   Events    //
    /////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);

    /////////////////
    // Modifiers //
    /////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert GSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert GSCEngine__NotAllowedToken(); 
        }
        _;
    }


    /////////////////
    // Functions  //
    /////////////////

    constructor(
        address[] memory tokenAddresses, 
        address[] memory priceFeedAddresses, 
        address gscAddress
    ) {
        // USD PriceFeeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert GSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_gsc = GorillaStableCoin(gscAddress);
    }

    ///////////////////////////
    // External Functions  //
    ///////////////////////////

    /*
    *  @param tokenCollateralAddress The address of the token to deposit as collateral
    *  @param amountCollateral The amount of collateral to deposit
    *  @param amountGscToMint The amount of Gorilla Stable Coin to mint
    *  @notice this function will deposit your collateral and mint GSC in one transaction !
    */

    function depositCollateralAndMintGsc(
        address tokenCollateralAddress, 
        uint256 amountCollateral, 
        uint256 amountGscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintGsc(amountGscToMint);
    }


    /*
    *   @param tokenCollateralAddress The collateral address to redeem
    *   @param amountCollateral The amount of collateral to redeem
    *   @param amountGscToBurn The amount of GSC to burn
    *   This function burns GSC and redeems underlying collateral in one transaction
    */
    function redeemCollateralForGsc(
        address tokenCollateralAddress, 
        uint256 amountCollateral, 
        uint256 amountGscToBurn
        ) 
        external 
    {
        burnGsc(amountGscToBurn);
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        // redeemCollateral already checks health factor
    }

    // in order to redeem collateral :
    // 1. health factor must be ober 1 after collateral pulled
    //DRY: don't repeat yourself

    function redeemCollateral(
        address tokenCollateralAddress, 
        uint256 amountCollateral
    ) 
        external 
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }


    // do we need to check if this breaks health factor?
    function burnGsc(uint256 amount) public moreThanZero(amount){
        _burnGsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //I don't thinks this would ever hit ....
    }
    // If someone is almost undercollateralized, we will pay you to liquidate them!

    /*
    * @param collateral The ERC20 collateral address to liquidate from the user
    * @param user The user who has broken the health factor threshold. 
    Their _healthFactor should be below MIN_HEALTH_FACTOR
    * @param debtToCover The amount of GSC you want to burn to improve users health factor
    * @notice You can partially liquidate a user.
    * @notice You will get a liquidation bonus for taking the users funds
    * @notice This function working asssumes the protocol will be roughly 200%
    overcollateralized in order for this to work.
    * @notice A known bug would be if the protocol were 100% or less coillateralized,
    then we wouldn't be able to incentive the liquidators
    * For exemple, if the price of the collateral plummeted before anyone could be liquidated.
    */


    function liquidate(address collateral, address user, uint256 debtToCover) 
        external 
        moreThanZero(debtToCover) 
        nonReentrant 
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert GSCEngine__HealthFactorOk();
        }
        // We want to burn their GSC "debt"
        // And take their collateral
        // Bad User : $140ETH, $100GSC
        // debtToCover = $100
        // $100 of GSC == ??? ETH?
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bonus 
        // So we are giving the liquidator $110 of WETH for 100 GSC
        // We should implement a feature to liquidate in the event the protocol is insolvetn
        // and sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        // We want to burn the GSC:
        _burnGsc(debtToCover, user, msg.sender);    
        
        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor){
            revert GSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);


    }
    //////////////////////
    // Public Functions //
    //////////////////////

    /*
    * @param amountGscToMint The amount of Gorilla Stable Coin to mint
    * @notice The amount of collateral must be > the amount of GSC minmum treshold
    */
    // Check if the collateral value > GSC amount. Price feeds, values, etc
    function mintGsc(uint256 amountGscToMint) public moreThanZero(amountGscToMint) nonReentrant {
        s_GSCMinted[msg.sender] += amountGscToMint;
        //if they minted too much ($150 GSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_gsc.mint(msg.sender, amountGscToMint);
        if (!minted) {
            revert GSCEngine__MintFailed();
        }
    }

    /*
    * @param tokenCollateralAddress The address of the token to deposit as collateral
    * @param amountCollateral The amount of collateral to deposit
    */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert GSCEngine__TransferFailed();
        }
    }

    function getHealthFactor() external view returns (uint256) {}

    ////////////////////////////////////////
    // Private & Internal View Functions  //
    ////////////////////////////////////////


    /*
    * @dev Low-level internal function, do not call unless the functio calling it is checking
    * for health factors being broken
    */
    function _burnGsc(uint256 amountGscToBurn, address onBehalfOf, address gscFrom) private {
        s_GSCMinted[onBehalfOf] -= amountGscToBurn;
        bool success = i_gsc.transferFrom(gscFrom, address(this), amountGscToBurn);
        //this conditional is hypothiutcally unreachable
        if (!success) {
            revert GSCEngine__TransferFailed();
        }
        i_gsc.burn(amountGscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert GSCEngine__TransferFailed();
        }
    }
    function _getAccountInformation(address user)
        private 
        view 
        returns(uint256 totalGscMinted, uint256 collateralValueInUsd) 
    {
        totalGscMinted = s_GSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }
    /*
    * Returns how close to liquidation a user is
    * If a user goes below 1, they are at risk of liquidation
    */

    function _healthFactor(address user) internal view returns (uint256) {
        //total GSC minted / total collateral VALUE
        (uint256 totalGscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForTreshold = (collateralValueInUsd * LIQUIDATION_TRESHOLD) / LIQUIDATION_PRECISION;
        // $150 ETH / 100 GSC = 1.5
        // 150 * 50 = 7500 
        // 7500/100 = 75
        // 75/100 < 1

        // $1000 ETH / 100 GSC 
        // 1000 * 50 = 50000 /100 = (500 /100) > 1
        //
        return (collateralAdjustedForTreshold * PRECISION) / totalGscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view{
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert GSCENGINE__BreaksHealthFactor(userHealthFactor);
            
        }
    }   

    ////////////////////////////////////////
    // Public & External View Functions  //
    ////////////////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //$10e18 * 1e18 / ($2000e8 * 1e10)
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        //loop through each collateral token, get the amount 
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += amount * getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8.
        // ((PRICE * 1e10) * AMOUNT) / 1e18.
        return ((uint256(price) *ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;

    }
}