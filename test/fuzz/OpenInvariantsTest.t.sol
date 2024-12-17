// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.20;

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployGSC} from "../../script/DeployGSC.s.sol";
// import {GSCEngine} from "../../src/GSCEngine.sol";
// import {GorillaStableCoin} from "../../src/GorillaStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
 

// // revert on false = good for quicktest 
// contract OpenInvariantsTest is StdInvariant, Test {

//     DeployGSC deployer;
//     GSCEngine gscEngine;
//     GorillaStableCoin gsc;
//     HelperConfig helperConfig;
//     address weth;
//     address wbtc;

//     function setUp() public {
//         deployer = new DeployGSC();
//         (gsc, gscEngine, helperConfig) = deployer.run();
//         (,, weth, wbtc , ) = helperConfig.activeNetworkConfig();
//         targetContract(address(gscEngine));
        
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all the debt (gsc)
//         uint256 totalSupply = gsc.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(gscEngine));
//         uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(gscEngine)); 

//         uint256 wethValue = gscEngine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = gscEngine.getUsdValue(wbtc, totalWbtcDeposited);

//         console.log("weth value:", wethValue);
//         console.log("wbtc value:", wbtcValue);
//         console.log("total supply:", totalSupply);

//         assert(wethValue + wbtcValue >= totalSupply);   
//     }


// }



// Properties

// Invariants

// 1. The total supply of GSC should always be less than the total value of collateral

// 2. Getter view functions should never revert <- evergreen invariant