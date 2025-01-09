// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract OldDLCStaking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    IERC20 public rewardToken;

    enum  StakeLockTimeType {
        days90,
        days180
    }

    uint256 constant DAYS_90_TOTAL_REWARD_AMOUNT = 2_000_000_000 * 1e18;
    uint256 constant DAYS_180_TOTAL_REWARD_AMOUNT = 2_000_000_000 * 1e18;
    uint256 constant DAYS_90_STAKE_MAX_AMOUNT = 6_666_666_666 * 1e18;
    uint256 constant DAYS_180_STAKE_MAX_AMOUNT = 2_500_000_000 * 1e18;

    uint256 public currentDays90totalStakedAmount;
    uint256 public currentDays180totalStakedAmount;

    uint256 public currentDays90totalClaimedRewardAmount;
    uint256 public currentDays180totalClaimedRewardAmount;

    mapping(address => uint256) public addressToLastStakeIndex;
    mapping(address => mapping(uint256 => StakeInfo)) public addressToStakeInfos;
    uint256 public minStakeAmountLimit;
    mapping(address => uint256[]) address2StakeIndexList;

    struct StakeInfo {
        uint256 stakeIndex;
        uint256 startTimestamp;
        uint256 amount;
        bool inStaking;
        StakeLockTimeType lockTimeType;
        uint256 totalRewardAmount;
        uint256 lastClaimedTimestamp;
        uint256 rewardAmountPerSeconds;
        uint256 claimedRewardAmount;
    }

    struct TopStaker {
        address staker;
        uint256 totalStakedAmount;
        uint256 stakeIndex;
        uint256 startAtTimestamp;
    }

    TopStaker[] public days90Top100Stakers;
    TopStaker[] public days180Top100Stakers;

    struct top100StakerInfo {
        address staker;
        uint256 totalStakedAmount;
        uint256 rewardAmount;
        uint256 startAtTimestamp;
    }

    struct stakeInfoForShowing {
        uint256 stakeIndex;
        uint256 stakedAmount;
        uint256 totalRewardAmount;
        uint256 dailyRewardAmount;
        uint256 claimedRewardAmount;
    }

    modifier canStake(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount) {
        require(stakeAmount >= minStakeAmountLimit, "Stake amount should be greater than min stake amount limit(10000)");
        require(leftAmountCanStake(stakeLockTimeType) >= stakeAmount, "Not enough left amount to stake");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _rewardToken) public initializer {
        require(_rewardToken != address(0), "Reward token address should not be zero");
        __ReentrancyGuard_init();
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        rewardToken = IERC20(_rewardToken);
        minStakeAmountLimit = 10_000 * 1e18;
        days90Top100Stakers = new TopStaker[](100);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getTotalStakeAmount() external view returns (uint256) {
        return currentDays90totalStakedAmount + currentDays180totalStakedAmount;
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

    function getMyStakingInfo(address holder, uint256 pageNumber, uint256 pageSize)
    external
    view
    returns (stakeInfoForShowing[] memory infos, uint256 total)
    {
        require(pageSize > 0, "Page size must be greater than zero");
        require(pageNumber > 0, "Page number must be greater than zero");

        uint256[] memory ids = address2StakeIndexList[holder];
        uint256 totalStakings = ids.length;

        uint256 startIndex = (pageNumber - 1) * pageSize;
        uint256 endIndex = startIndex + pageSize;

        // Adjust endIndex if it exceeds the total number of stakings
        if (endIndex > totalStakings) {
            endIndex = totalStakings;
        }

        // Ensure the startIndex is within range
        require(startIndex < totalStakings, "Page number exceeds total pages");

        uint256 resultLength = endIndex - startIndex;
        infos = new stakeInfoForShowing[](resultLength);

        uint256 index = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            uint256 id = ids[i];
            StakeInfo memory stakeInfo = addressToStakeInfos[holder][id];

            if (stakeInfo.inStaking) {
                infos[index] = stakeInfoForShowing(
                    stakeInfo.stakeIndex,
                    stakeInfo.amount,
                    getRewardAmount(holder, id),
                    stakeInfo.rewardAmountPerSeconds * 1 days,
                    stakeInfo.claimedRewardAmount
                );
                index++;
            }
        }

        return (infos, totalStakings);
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

    function _updateTop100(address staker, uint256 stakeIndex, uint256 amount,uint256 startAtTimestamp,TopStaker[] storage targetTopStakers)
    internal
    {

        bool inserted = false;
        for (uint256 i = 0; i < targetTopStakers.length; i++) {
            if (targetTopStakers[i].staker == address(0) || amount > targetTopStakers[i].totalStakedAmount) {
                for (uint256 j = targetTopStakers.length - 1; j > i; j--) {
                    targetTopStakers[j] = targetTopStakers[j - 1];
                }
                targetTopStakers[i] = TopStaker({
                    staker: staker,
                    stakeIndex: stakeIndex,
                    totalStakedAmount: amount,
                    startAtTimestamp:startAtTimestamp
                });
                inserted = true;
                break;
            }
        }

        if (!inserted) {
            for (uint256 i = 0; i < targetTopStakers.length; i++) {
                if (targetTopStakers[i].staker == address(0)) {
                    targetTopStakers[i] = TopStaker({
                        staker: staker,
                        stakeIndex: stakeIndex,
                        totalStakedAmount: amount,
                        startAtTimestamp:startAtTimestamp
                    });
                    break;
                }
            }
        }
    }

    function updateTop100(address staker, uint256 stakeIndex, uint256 amount, StakeLockTimeType lockTimeType,uint256 startAtTimestamp)
    internal
    {
        if (lockTimeType == StakeLockTimeType.days90) {
            _updateTop100(staker, stakeIndex, amount,startAtTimestamp,days90Top100Stakers);
        }else if (lockTimeType == StakeLockTimeType.days180) {
            _updateTop100(staker, stakeIndex, amount,startAtTimestamp,days180Top100Stakers);
        }


    }

    //    function getTopStakeHolders() external view returns (top100StakerInfo[] memory) {
    //        top100StakerInfo[] memory top10StakeInfo = new top100StakerInfo[](100);
    //        for (uint256 i = 0; i < top100Stakers.length; i++) {
    //            TopStaker memory stakerInfo = top100Stakers[i];
    //
    //            uint256 rewardAmount = getRewardAmount(stakerInfo.staker, stakerInfo.stakeIndex);
    //
    //            AppendStakeInfo[] memory appendStakeInfosOfStaker =
    //                appendStakeInfos[stakerInfo.staker][stakerInfo.lockTimeType];
    //            for (uint256 j = 0; j < appendStakeInfosOfStaker.length; j++) {
    //                AppendStakeInfo memory appendStakeInfo = appendStakeInfosOfStaker[j];
    //                rewardAmount += getRewardAmount(stakerInfo.staker, appendStakeInfo.stakeIndex);
    //            }
    //
    //            top10StakeInfo[i] =
    //                top100StakerInfo(stakerInfo.staker, stakerInfo.totalStakedAmount, stakerInfo.lockTimeType, rewardAmount);
    //        }
    //        return top10StakeInfo;
    //    }

    function getTopStakeHolders(StakeLockTimeType lockTimeType, uint256 pageNumber, uint256 pageSize)
    external
    view
    returns (top100StakerInfo[] memory, uint256)
    {
        require(pageSize > 0, "Page size must be greater than zero");
        require(pageNumber > 0, "Page number must be greater than zero");

        TopStaker[] memory targetTopStakers;
        if (lockTimeType == StakeLockTimeType.days90) {
            targetTopStakers = days90Top100Stakers;
        }else if (lockTimeType == StakeLockTimeType.days180) {
            targetTopStakers = days180Top100Stakers;
        }

        uint256 totalStakers = targetTopStakers.length;
        uint256 startIndex = (pageNumber - 1) * pageSize;
        uint256 endIndex = startIndex + pageSize;

        // If endIndex exceeds totalStakers, adjust it to totalStakers
        if (endIndex > totalStakers) {
            endIndex = totalStakers;
        }

        // Ensure the startIndex is within range
        require(startIndex < totalStakers, "Page number exceeds total pages");

        uint256 resultLength = endIndex - startIndex;
        top100StakerInfo[] memory pagedStakers = new top100StakerInfo[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            uint256 currentIndex = startIndex + i;
            TopStaker memory stakerInfo = targetTopStakers[currentIndex];

            uint256 rewardAmount = getRewardAmount(stakerInfo.staker, stakerInfo.stakeIndex);

            pagedStakers[i] =
                            top100StakerInfo(stakerInfo.staker, stakerInfo.totalStakedAmount, rewardAmount,stakerInfo.startAtTimestamp);
        }

        return (pagedStakers, totalStakers);
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
            getRewardPerSeconds(stakeLockTimeType, getTotalRewardAmount(stakeLockTimeType, stakeAmount)),
            0
        );
    }

    function stake(StakeLockTimeType stakeLockTimeType, uint256 stakeAmount)
    external
    nonReentrant
    canStake(stakeLockTimeType, stakeAmount)
    {
        require(rewardToken.allowance(msg.sender, address(this)) >= stakeAmount, "token not approved");
        rewardToken.transferFrom(msg.sender, address(this), stakeAmount);

        StakeInfo memory stakeInfo = newStakeInfo(stakeLockTimeType, stakeAmount);
        addressToStakeInfos[msg.sender][stakeInfo.stakeIndex] = stakeInfo;
        address2StakeIndexList[msg.sender].push(stakeInfo.stakeIndex);
        if (stakeLockTimeType == StakeLockTimeType.days90) {
            currentDays90totalStakedAmount += stakeAmount;
        } else if (stakeLockTimeType == StakeLockTimeType.days180) {
            currentDays180totalStakedAmount += stakeAmount;
        }
        updateTop100(msg.sender, stakeInfo.stakeIndex, stakeAmount, stakeLockTimeType,stakeInfo.startTimestamp);
    }

    function claim(uint256 stakeIndex) external nonReentrant {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        require(stakeInfo.inStaking, "This stake is not in staking");
        uint256 rewardAmount = getRewardAmount(msg.sender, stakeIndex);
        require(rewardAmount > 0, "No reward to claim");
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Not enough reward token balance");
        rewardToken.transfer(msg.sender, rewardAmount);
        stakeInfo.lastClaimedTimestamp = block.timestamp;
        stakeInfo.totalRewardAmount = stakeInfo.totalRewardAmount - rewardAmount;
        stakeInfo.claimedRewardAmount += rewardAmount;
        if (stakeInfo.lockTimeType == StakeLockTimeType.days90) {
            currentDays90totalClaimedRewardAmount += rewardAmount;
        } else if (stakeInfo.lockTimeType == StakeLockTimeType.days180) {
            currentDays180totalClaimedRewardAmount += rewardAmount;
        }
    }

    function canExitStake(uint256 stakeIndex) external view returns (bool) {
        StakeInfo storage stakeInfo = addressToStakeInfos[msg.sender][stakeIndex];
        return stakeInfo.inStaking && block.timestamp >= unlockedAtTimestamp(stakeIndex, stakeInfo.lockTimeType);
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

    function claimLeftRewardToken() external onlyOwner {
        require(rewardToken.balanceOf(address(this)) > 0, "No reward token balance");
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    function version() external pure returns (uint256) {
        return 0;
    }
}
