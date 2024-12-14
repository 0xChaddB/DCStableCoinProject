// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {GorillaStableCoin} from "../src/GorillaStableCoin.sol";
import {GSCEngine} from "../src/GSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployGSC  is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (GorillaStableCoin, GSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);
        address deployerPublicAddress = vm.addr(deployerKey);
        GorillaStableCoin gsc = new GorillaStableCoin(deployerPublicAddress);
        GSCEngine gscEngine = new GSCEngine(tokenAddresses, priceFeedAddresses, address(gsc));
        gsc.transferOwnership(address(gscEngine));
        vm.stopBroadcast();
        return (gsc, gscEngine, helperConfig);
    }
    
}   