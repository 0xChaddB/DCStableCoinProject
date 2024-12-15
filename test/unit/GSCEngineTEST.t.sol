// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {GSCEngine} from "../../src/GSCEngine.sol";
import {DeployGSC} from "../../script/DeployGSC.s.sol";
import {GorillaStableCoin} from "../../src/GorillaStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";

contract GSCEngineTest is Test {

    DeployGSC deployer;
    GorillaStableCoin gsc;
    GSCEngine gscEngine;
    HelperConfig helperConfig;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    uint256 amountToMint = 100 ether;
    uint256 AMOUNT_COLLATERAL = 10 ether;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant GSC_TO_MINT = 5 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    function setUp() public {
        deployer = new DeployGSC();
        (gsc, gscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }


    ///////////////////////
    // Constructor Tests //
    ///////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLenghtDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(GSCEngine.GSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new GSCEngine(tokenAddresses, priceFeedAddresses, address(gsc));
    }

    ///////////////////
    // Price Tests //
    ///////////////////

    function testGetUsdValue() view public {
        uint256 ethAmount = 15 ether; 
        //15e18 * 2000/ETH = 30.000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = gscEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() view public {
        uint256 usdAmount = 100 ether; 
        // $2000 / ETH, $15
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = gscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(gscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(GSCEngine.GSCEngine__MustBeMoreThanZero.selector);
        gscEngine.depositCollateral(weth, 0);
        vm.stopPrank();

    }
    
    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(GSCEngine.GSCEngine__NotAllowedToken.selector);
        gscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    modifier depositedCollateral(){
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(gscEngine), AMOUNT_COLLATERAL);
        gscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testDepositCollateral() public depositedCollateral {
        
        uint256 depositedAmount = gscEngine.getCollateralDeposited(USER, weth);
        assertEq(depositedAmount, AMOUNT_COLLATERAL);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalGscMinted, uint256 collateralValueInUsd) = gscEngine.getAccountInformation(USER);

        uint256 expectedTotalGscMinted = 0;

        uint256 expectedDepositAmount = gscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(expectedTotalGscMinted, totalGscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }


    ///////////////////////////////////////
    // depositCollateralAndMintGsc Tests //
    ///////////////////////////////////////

    function testMintFailsIfHealthFactorBroken() public depositedCollateral {

        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (AMOUNT_COLLATERAL * (uint256(price) * gscEngine.getAdditionalFeedPrecision())) / gscEngine.getPrecision();

        vm.startPrank(USER);
        uint256 expectedHealthFactor =
        gscEngine.calculateHealthFactor(amountToMint, gscEngine.getUsdValue(weth,AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(GSCEngine.GSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        gscEngine.mintGsc(amountToMint);
        vm.stopPrank();
    }


    modifier depositedCollateralAndMintedGsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(gscEngine), AMOUNT_COLLATERAL);
        gscEngine.depositCollateralAndMintGsc(weth, AMOUNT_COLLATERAL, amountToMint);
        vm.stopPrank();
        _;
    }

    ///////////////////
    // mintGsc Tests //
    ///////////////////

    function testCanMintGsc() public depositedCollateral {
        vm.prank(USER);
        gscEngine.mintGsc(GSC_TO_MINT);

        uint256 userBalance = gsc.balanceOf(USER);
        assertEq(userBalance, GSC_TO_MINT);
    }

    ///////////////////////
    // BurnGsc Tests     //
    ///////////////////////

    function testCanBurnGsc() public depositedCollateralAndMintedGsc {
        vm.startPrank(USER);

        uint256 userBalance = gsc.balanceOf(USER);
        console.log("Initial User Balance:", userBalance);

        // Verify healthFactor before burning
        uint256 initialHealthFactor = gscEngine.getHealthFactor(USER);
        console.log("Initial Health Factor:", initialHealthFactor);


        // Approve tokens if required
        gsc.approve(address(gscEngine), amountToMint);

        // Call burn function
        console.log("Calling burnGsc with amount:", amountToMint);
        gscEngine.burnGsc(amountToMint);

        vm.stopPrank();

        // Check final balance
        uint256 finalUserBalance = gsc.balanceOf(USER);
        console.log("Final User Balance:", finalUserBalance);
        assertEq(finalUserBalance, 0);
    }
    
    // Quick test refresher (without modifier)
    function testCanDepositAndMintAndBurnGsc() public {
        // Simulate a user
        vm.startPrank(USER);

        // Do i Need to Approve transfer 

        // Deposit Collateral and mint GSC
        gscEngine.depositCollateralAndMintGsc(weth, AMOUNT_COLLATERAL, amountToMint);

        // Verify state after minting
        (uint256 mintedAmount, ) = gscEngine.getAccountInformation(USER);
        console.log("GSC Minted:", mintedAmount);

        // Burn GSC
        gsc.approve(address(gscEngine), amountToMint);
        console.log("Burning GSC...");
        gscEngine.burnGsc(amountToMint);

        // Verify balance = 0 after burn
        uint256 finalBalance = gsc.balanceOf(USER);
        console.log("Final GSC Balance:", finalBalance);
        assertEq(finalBalance, 0);

        vm.stopPrank();
    }
}