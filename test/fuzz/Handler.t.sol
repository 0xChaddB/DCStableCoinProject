// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GSCEngine} from "../../src/GSCEngine.sol";
import {GorillaStableCoin} from "../../src/GorillaStableCoin.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
    // price feed
    // weth token 
    // wbtc token

contract Handler is Test {
    GSCEngine gscEngine;
    GorillaStableCoin gsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    uint256 public timesPriceFeedUpdated;
    address[] public usersWithCollateralDeposited;
    MockV3Aggregator public ethUsdPriceFeed;
    
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; // the max uint96 value

    constructor(GSCEngine _gscEngine, GorillaStableCoin _gsc) {
        gscEngine = _gscEngine;
        gsc = _gsc;

        address[] memory collateralTokens = gscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(gscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    // @note continue on revert : quicker looser test
    // @note fail on revert : EVERY TRANSACTION RUNNING PASSING TEST

    function mintGsc(uint256 amount, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0) {
            return;
        }
        
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalGscMinted, uint256 collateralValueInUsd) = gscEngine.getAccountInformation(sender);
        int256 maxGscToMint = (int256(collateralValueInUsd) / 2) - int(totalGscMinted);

        // Next time ill try using vm.assume if possible 
        if(maxGscToMint < 0) {
            return;
        }

        amount = bound(amount, 0, uint256(maxGscToMint));
        if (amount == 0) {
            return;
        }

        vm.startPrank(sender);

        gscEngine.mintGsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);


        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(gscEngine), amountCollateral);
        gscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        // double push if same address twice ??
        usersWithCollateralDeposited.push(msg.sender);

    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = gscEngine.getCollateralDeposited(address(collateral), msg.sender);

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        // vm.assume(maxCollateralToRedeem == 0); ???
            
        gscEngine.redeemCollateral(address(collateral), amountCollateral);
        
    }
    
    // this breaks invariants why?
    /////////////////////////////
    // Aggregator //                       
    /////////////////////////////
    // function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
    //     int256 intNewPrice = int256(uint256(newPrice));
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     MockV3Aggregator priceFeed = MockV3Aggregator(gscEngine.getCollateralTokenPriceFeed(address(collateral)));

    //     priceFeed.updateAnswer(intNewPrice);
    // }

    //  And why this dont break invariant? 
    function updateCollateralPriceINeedToAnswer(uint96 newPrice) public {
        int256 intNewPrice = int256(uint256(newPrice));
        ethUsdPriceFeed.updateAnswer(intNewPrice);
    }



    // Helper Functions 
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if (collateralSeed % 2 == 0) {
            
        }
        return wbtc;
    }

}