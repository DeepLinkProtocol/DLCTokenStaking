// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract OldCexStaking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    IERC20 public rewardToken;

    enum StakeLockTimeType {
        days90,
        days180
    }

    uint256 constant DAYS_90_TOTAL_REWARD_AMOUNT = 2_000_000_000 * 1e18;
    uint256 constant DAYS_180_TOTAL_REWARD_AMOUNT = 2_000_000_000 * 1e18;
    uint256 constant DAYS_90_STAKE_MAX_AMOUNT = 6_666_666_666 * 1e18;
    uint256 constant DAYS_180_STAKE_MAX_AMOUNT = 2_500_000_000 * 1e18;

    uint256 public currentDays90totalStakedAmount;
    uint256 public currentDays180totalStakedAmount;

    mapping(address => uint256) public addressToLastStakeIndex;
    mapping(address => mapping(uint256 => StakeInfo)) public addressToStakeInfos;

    struct StakeInfo {
        uint256 stakeIndex;
        uint256 startTimestamp;
        uint256 amount;
        bool inStaking;
        StakeLockTimeType lockTimeType;
        uint256 totalRewardAmount;
        uint256 lastClaimedTimestamp;
        uint256 rewardAmountPerSeconds;
    }

    modifier canStake(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount) {
        require(stakeAmount > 0, "Stake amount should be greater than 0");
        require(leftAmountCanStake(stakeLockTimeType) >= stakeAmount, "Not enough left amount to stake");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _rewardToken) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        rewardToken = IERC20(_rewardToken);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function leftAmountCanStake(StakeLockTimeType stakeLockTimeType) public view returns (uint256) {
        if (stakeLockTimeType == StakeLockTimeType.days90) {
            return DAYS_90_STAKE_MAX_AMOUNT - currentDays90totalStakedAmount;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            return DAYS_180_STAKE_MAX_AMOUNT - currentDays180totalStakedAmount;
        }

        return 0;
    }

    function getTotalRewardAmount(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount)
        internal
        pure
        returns (uint256)
    {
        if (stakeLockTimeType == StakeLockTimeType.days90) {
            return stakeAmount * 3 / 10;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            return stakeAmount * 4 / 5;
        }

        return 0;
    }

    function getRewardPerSeconds(StakeLockTimeType stakeLockTimeType, uint256 totalRewardAmount)
        internal
        pure
        returns (uint256)
    {
        if (stakeLockTimeType == StakeLockTimeType.days90) {
            return totalRewardAmount / 90 days;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            return totalRewardAmount / 180 days;
        }

        return 0;
    }

    function newStakeInfo(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount)
        internal
        returns (StakeInfo memory)
    {
        addressToLastStakeIndex[msg.sender] = addressToLastStakeIndex[msg.sender] + 1;
        return StakeInfo(
            addressToLastStakeIndex[msg.sender],
            block.timestamp,
            stakeAmount,
            true,
            stakeLockTimeType,
            getTotalRewardAmount(stakeLockTimeType, stakeAmount),
            block.timestamp,
            getRewardPerSeconds(stakeLockTimeType, getTotalRewardAmount(stakeLockTimeType, stakeAmount))
        );
    }

    function stake(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount)
        external
        nonReentrant
        canStake(stakeLockTimeType, stakeAmount)
    {
        rewardToken.transferFrom(msg.sender, address(this), stakeAmount);

        StakeInfo memory stakeInfo = newStakeInfo(stakeLockTimeType, stakeAmount);
        addressToStakeInfos[msg.sender][stakeInfo.stakeIndex] = stakeInfo;
    }

    function claim(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        require(stakeInfo.inStaking, "This stake is not in staking");
        require(block.timestamp >= stakeInfo.lastClaimedTimestamp + 1 seconds, "Can't claim yet");
        uint256 rewardAmount = (block.timestamp - stakeInfo.lastClaimedTimestamp) * stakeInfo.rewardAmountPerSeconds;
        require(rewardAmount > 0, "No reward to claim");
        rewardAmount = rewardAmount > stakeInfo.totalRewardAmount ? stakeInfo.totalRewardAmount : rewardAmount;
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Not enough reward token balance");
        rewardToken.transfer(msg.sender, rewardAmount);
        stakeInfo.lastClaimedTimestamp = block.timestamp;
        stakeInfo.totalRewardAmount = stakeInfo.totalRewardAmount - rewardAmount;
    }

    function exitStake(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        require(stakeInfo.inStaking, "This stake is not in staking");
        require(block.timestamp >= unlockedAtTimestamp(stakeInfo.stakeIndex, stakeInfo.lockTimeType), "Can't exit yet");
        uint256 rewardAmount = (block.timestamp - stakeInfo.startTimestamp) * stakeInfo.rewardAmountPerSeconds;
        rewardAmount = rewardAmount > stakeInfo.totalRewardAmount ? stakeInfo.totalRewardAmount : rewardAmount;
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Not enough reward token balance");
        rewardToken.transfer(msg.sender, stakeInfo.amount + rewardAmount);
        stakeInfo.inStaking = false;
    }

    function unlockedAtTimestamp(uint256 stakeIndex, StakeLockTimeType lockTimeType) public view returns (uint256) {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        uint256 startTimestamp = stakeInfo.startTimestamp;
        if (lockTimeType == StakeLockTimeType.days90) {
            return startTimestamp + 90 days;
        } else if (lockTimeType == StakeLockTimeType.days180) {
            return startTimestamp + 180 days;
        }
        return 0;
    }
}
