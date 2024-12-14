// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GSCEngine} from "../../src/GSCEngine.sol";
import {DeployGSC} from "../../script/DeployGSC.s.sol";
import {GorillaStableCoin} from "../../src/GorillaStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

contract GSCEngineTest is Test {
    DeployGSC deployer;
    GorillaStableCoin gsc;
    GSCEngine gscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;


    function setUp() public {
        deployer = new DeployGSC();
        (gsc, gscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }


    ///////////////////
    // Price Tests //
    ///////////////////

    function testGetUsdValue() view public {
        uint256 ethAmount = 15e18; // 15 ETH
        //15e18 * 2000/ETH = 30.000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = gscEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
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
}