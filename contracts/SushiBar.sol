// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract SushiBar is ERC20{
    using SafeMath for uint256;
    IERC20 public sushi;

    uint256 intervalDuration; // unstaking interval duration 
    uint256 intervals; // number of intervals to unstake
    
    uint256 totalAmountStaked;

    struct UserStake {
        uint256 startTimestamp;
        uint256 amount;
        address user;
    }


    mapping (bytes32 => UserStake) userStakings;
    mapping (address => uint256) userStakingCount;


    constructor(IERC20 _sushi) ERC20("SushiBar", "xSUSHI") {
        sushi = _sushi;
    }

    // Enter the bar. Pay some SUSHIs. Earn some shares.
    function enter(uint256 _amount) public {
        uint256 totalSushi = sushi.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalSushi == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            _mint(msg.sender, what);
        }
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SUSHIs.
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        sushi.transfer(msg.sender, what);
    }
}