// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:oz-upgrades-from OldCexStaking
contract CexStaking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
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
    uint256 public minStakeAmountLimit;

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

    struct TopStaker {
        address staker;
        uint256 totalStakedAmount;
        uint256 stakeIndex;
        StakeLockTimeType lockTimeType;
        uint256 initStakeAmount;
    }

    mapping(address => mapping(StakeLockTimeType => AppendStakeInfo[])) appendStakeInfos;

    struct AppendStakeInfo {
        uint256 stakeIndex;
        uint256 appendStakeAmount;
    }

    TopStaker[] public top10Stakers;

    uint256 public day90TotalStakeAmount;
    uint256 public day180TotalStakeAmount;

    struct top10StakerInfo {
        address staker;
        uint256 totalStakedAmount;
        StakeLockTimeType lockTimeType;
        uint256 rewardAmount;
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
        minStakeAmountLimit = 1000 * 1e18;
        top10Stakers = new TopStaker[](10);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getTotalStakeAmount() external view returns (uint256) {
        return day90TotalStakeAmount + day180TotalStakeAmount;
    }

    function leftAmountCanStake(StakeLockTimeType stakeLockTimeType) public view returns (uint256) {
        if (stakeLockTimeType == StakeLockTimeType.days90) {
            return DAYS_90_STAKE_MAX_AMOUNT - currentDays90totalStakedAmount;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            return DAYS_180_STAKE_MAX_AMOUNT - currentDays180totalStakedAmount;
        }

        return 0;
    }

    function getUnclaimedStakedDays(StakeInfo memory stakeInfo) internal view returns (uint256) {
        return (block.timestamp - stakeInfo.lastClaimedTimestamp) / 1 days;
    }

    function getRewardAmount(address account, uint256 stakeIndex) public view returns (uint256) {
        StakeInfo memory stakeInfo = addressToStakeInfos[account][stakeIndex];
        uint256 rewardAmount = stakeInfo.rewardAmountPerSeconds * (block.timestamp - stakeInfo.lastClaimedTimestamp);
        rewardAmount = rewardAmount > stakeInfo.totalRewardAmount ? stakeInfo.totalRewardAmount : rewardAmount;
        return rewardAmount;
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
            return totalRewardAmount / 90 days / 24 hours / 60 minutes / 60 seconds;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            return totalRewardAmount / 180 days / 24 hours / 60 minutes / 60 seconds;
        }

        return 0;
    }

    function updateTop10(address staker, uint256 stakeIndex, uint256 amount, StakeLockTimeType lockTimeType) internal {
        for (uint256 i = 0; i < top10Stakers.length; i++) {
            if (top10Stakers[i].staker == staker && top10Stakers[i].lockTimeType == lockTimeType) {
                appendStakeInfos[staker][lockTimeType].push(
                    AppendStakeInfo({stakeIndex: stakeIndex, appendStakeAmount: amount})
                );

                top10Stakers[i].totalStakedAmount += amount;

                // sort
                for (
                    uint256 j = i;
                    j > 0 && top10Stakers[j].totalStakedAmount > top10Stakers[j - 1].totalStakedAmount;
                    j--
                ) {
                    TopStaker memory temp = top10Stakers[j];
                    top10Stakers[j] = top10Stakers[j - 1];
                    top10Stakers[j - 1] = temp;
                }
                return;
            }
        }

        bool inserted = false;
        for (uint256 i = 0; i < top10Stakers.length; i++) {
            if (top10Stakers[i].staker == address(0) || amount > top10Stakers[i].totalStakedAmount) {
                for (uint256 j = 9; j > i; j--) {
                    top10Stakers[j] = top10Stakers[j - 1];
                }
                top10Stakers[i] = TopStaker({
                    staker: staker,
                    stakeIndex: stakeIndex,
                    totalStakedAmount: amount,
                    initStakeAmount: amount,
                    lockTimeType: lockTimeType
                });
                inserted = true;
                break;
            }
        }

        if (!inserted) {
            for (uint256 i = 0; i < top10Stakers.length; i++) {
                if (top10Stakers[i].staker == address(0)) {
                    top10Stakers[i] = TopStaker({
                        staker: staker,
                        stakeIndex: stakeIndex,
                        totalStakedAmount: amount,
                        initStakeAmount: amount,
                        lockTimeType: lockTimeType
                    });
                    break;
                }
            }
        }
    }

    function getTopStakeHolders() external view returns (top10StakerInfo[] memory) {
        top10StakerInfo[] memory top10StakeInfo = new top10StakerInfo[](10);
        for (uint256 i = 0; i < top10Stakers.length; i++) {
            TopStaker memory stakerInfo = top10Stakers[i];

            uint256 rewardAmount = getRewardAmount(stakerInfo.staker, stakerInfo.stakeIndex);

            AppendStakeInfo[] memory appendStakeInfosOfStaker =
                appendStakeInfos[stakerInfo.staker][stakerInfo.lockTimeType];
            for (uint256 j = 0; j < appendStakeInfosOfStaker.length; j++) {
                AppendStakeInfo memory appendStakeInfo = appendStakeInfosOfStaker[j];
                rewardAmount += getRewardAmount(stakerInfo.staker, appendStakeInfo.stakeIndex);
            }

            top10StakeInfo[i] =
                top10StakerInfo(stakerInfo.staker, stakerInfo.totalStakedAmount, stakerInfo.lockTimeType, rewardAmount);
        }
        return top10StakeInfo;
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
        require(rewardToken.allowance(msg.sender, address(this)) >= stakeAmount);
        rewardToken.transferFrom(msg.sender, address(this), stakeAmount);

        StakeInfo memory stakeInfo = newStakeInfo(stakeLockTimeType, stakeAmount);
        addressToStakeInfos[msg.sender][stakeInfo.stakeIndex] = stakeInfo;

        if (stakeLockTimeType == StakeLockTimeType.days90) {
            currentDays90totalStakedAmount = currentDays90totalStakedAmount + stakeAmount;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            currentDays180totalStakedAmount = currentDays180totalStakedAmount + stakeAmount;
        }
        updateTop10(msg.sender, stakeInfo.stakeIndex, stakeAmount, stakeLockTimeType);
    }

    function claim(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        require(stakeInfo.inStaking, "This stake is not in staking");
        require(block.timestamp >= stakeInfo.lastClaimedTimestamp + 1 seconds, "Can't claim yet");
        uint256 rewardAmount = getRewardAmount(msg.sender, stakeIndex);
        require(rewardAmount > 0, "No reward to claim");
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
        if (startTimestamp == 0) {
            return 0;
        }
        if (lockTimeType == StakeLockTimeType.days90) {
            return startTimestamp + 90 days;
        } else if (lockTimeType == StakeLockTimeType.days180) {
            return startTimestamp + 180 days;
        }
        return 0;
    }

    function version() external pure returns (uint256) {
        return 2;
    }
}
