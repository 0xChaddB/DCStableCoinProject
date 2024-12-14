// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/* 
* @title GorillaStableCoin
* @author 0xChaddB
* Collateral : Exogenous (ETH & BTC)
* Minting : Algorithmic
* Relative Staility: Pegged to USD
*
* This is the contract meant to be governed by GSCEngine. This is just the ERC20 implementation
 of our StableCoin system.
*/

contract GorillaStableCoin is ERC20Burnable, Ownable {

    error GorillaStableCoin__MustBeMoreThanZero();
    error GorillaStableCoin__BurnAmountExceedsBalance();
    error GorillaStableCoin__NotZeroAdress();

    constructor(address initialOwner) Ownable(initialOwner) ERC20("GorillaStableCoin", "GSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0){
            revert GorillaStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert GorillaStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool) {
        if(_to == address(0)){
            revert GorillaStableCoin__NotZeroAdress();
        }
        if(_amount <= 0){
            revert GorillaStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
    
}