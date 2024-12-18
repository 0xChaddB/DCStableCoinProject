// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployGSC} from "../../script/DeployGSC.s.sol";
import {GSCEngine} from "../../src/GSCEngine.sol";
import {GorillaStableCoin} from "../../src/GorillaStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
 

// revert on false = good for quicktest 
contract InvariantsTest is StdInvariant, Test {

    DeployGSC deployer;
    GSCEngine gscEngine;
    GorillaStableCoin gsc;
    HelperConfig helperConfig;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployGSC();
        (gsc, gscEngine, helperConfig) = deployer.run();
        (,, weth, wbtc , ) = helperConfig.activeNetworkConfig();
        // targetContract(address(gscEngine));

        handler = new Handler(gscEngine, gsc);
        targetContract(address (handler));
        
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the debt (gsc)
        uint256 totalSupply = gsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(gscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(gscEngine)); 

        uint256 wethValue = gscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = gscEngine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value:", wethValue);
        console.log("wbtc value:", wbtcValue);
        console.log("total supply:", totalSupply);
        console.log("mint called:", handler.timesMintIsCalled());
        console.log("PRICE FEED UPDATED:", handler.timesPriceFeedUpdated());
        assert(wethValue + wbtcValue >= totalSupply);   
    }

    function invariant_gettersShouldNotRevert() public view {
                // ARGUMENTS ????????????
        // gscEngine.getAccountCollateralValue();
        // gscEngine.getAccountInformation();
        // gscEngine.getAdditionalFeedPrecision();
        // gscEngine.getCollateralDeposited();
        // gscEngine.getCollateralTokenPriceFeed();
        // gscEngine.getCollateralTokens();
        // gscEngine.getGsc();
        // gscEngine.getHealthFactor();
        // gscEngine.getLiquidationBonus();
        // gscEngine.getLiquidationPrecision();
        // gscEngine.getLiquidationThreshold();
        // gscEngine.getMinHealthFactor();
        // gscEngine.getPrecision();
        // gscEngine.getTokenAmountFromUsd();
        // gscEngine.getUsdValue();

    }

}