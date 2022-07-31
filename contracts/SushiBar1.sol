// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract SushiBar is ERC20{
    using SafeMath for uint256;
    IERC20 public sushi;

    uint256 intervalUnlockDuration; // unstaking interval duration 
    uint256 intervals; // number of intervals to unstake
    
    uint256 totalAmountStaked;

    struct UserStake {
        uint256 startTimestamp; // staking start timestamp
        uint256 initialPricePerShare;
        uint256 shares;
        address user;   // user
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
        bytes32 stakeId = getStakeIdForUser(msg.sender);
        if (totalShares == 0 || totalSushi == 0) {
            userStakings[stakeId] = UserStake(
                block.timestamp,
                1,
                _amount,
                msg.sender
            );
            _mint(address(this), _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            userStakings[stakeId] = UserStake(
                block.timestamp,
                _amount.div(what),
                what,
                msg.sender
            );
            _mint(address(this), what);
        }
        ++userStakingCount[msg.sender];
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SUSHIs.
    function leave(uint256 _share, bytes32 stakingId) public {
        UserStake memory stake = userStakings[stakingId];
        require(block.timestamp - stake.startTimestamp > intervalUnlockDuration, "ERR_LOCKED_STAKING");
        // calculate how much user can withdraw
        uint256 unstakeLimit = getUnstakeLimitForStake(stake);
        require(_share <= unstakeLimit, "ERR_SHARES_LOCKED");
        uint256 totalShares = totalSupply();
        uint256 pricePerShare = sushi.balanceOf(address(this)).div(totalShares);
        // get rewards
        uint256 rewards = _share.mul(pricePerShare - stake.initialPricePerShare);
        // calculate tax on rewards
        uint256 taxOnRewards = getTaxOnRewards(stake, rewards);
        uint256 what = (_share.mul(sushi.balanceOf(address(this))).div(totalShares)).sub(taxOnRewards);
        userStakings[stakingId].shares -= _share;
        _burn(address(this), _share);
        sushi.transfer(msg.sender, what);
    }

    function getTaxOnRewards(UserStake memory _stake, uint256 _reward) public view returns (uint256) {
        uint256 redeemCycle = ((block.timestamp).sub(_stake.startTimestamp)).div(intervalUnlockDuration);
        if(redeemCycle >= intervals) {
            return _reward;
        }
        return (_reward.mul(intervals - redeemCycle)).div(intervals);
    }

    function getUnstakeLimitForStake(UserStake memory _stake) public view returns (uint256) {
        uint256 redeemCycle = ((block.timestamp).sub(_stake.startTimestamp)).div(intervalUnlockDuration);
        if(redeemCycle > intervals) {
            return balanceOf(msg.sender);
        }
        return (balanceOf(msg.sender).mul(redeemCycle)).div(intervals);
    }

    function getTaxLimit() public view returns (uint256) {

    }

    function getStakeIdForUser(address _user) public view returns (bytes32) {
        return getStakeIdForUserAtIndex(_user, userStakingCount[_user]);
    }

    function getStakeIdForUserAtIndex(address _user, uint256 _userStakingIndex) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _userStakingIndex));
    }

}