# DLCStaking Contract API Documentation

## Introduction
The DLCStaking contract provides token staking and reward management functionalities. It supports multiple lock-up periods, allowing users to stake tokens, earn rewards, and withdraw their stakes and rewards after the lock-up period ends.

---

## Contract Address
To be updated after deployment.

---

## Data Structures
### StakeLockTimeType (Enum)
Represents the supported lock-up period types:
- `days90`: 90-day lock-up period the enum value is 0.
- `days180`: 180-day lock-up period the enum value is 1.

---

## Public Methods

### 1. `initialize(address owner, address rewardToken)`
Initializes the contract by setting the admin address and the reward token address.

#### Parameters
- `owner`: Admin address.
- `rewardToken`: ERC20 contract address of the reward token.

#### Returns
None.

---

### 2. `stake(StakeLockTimeType lockTimeType, uint256 amount)`
Allows users to stake tokens and select a lock-up period. minimum stake amount required is 10000 token.


#### Parameters
- `lockTimeType`: Lock-up period type, either `StakeLockTimeType.days90` or `StakeLockTimeType.days180`.
- `amount`: Amount of tokens to stake.

#### Returns
None.

#### Example
```solidity
rewardToken.approve(address(DLCStaking), 1_000_000 * 1e18);
DLCStaking.stake(StakeLockTimeType.days90, 1_000_000 * 1e18);
```

---

### 3. `getRewardAmount(address user, uint256 stakeIndex) → uint256`
Retrieves the current claimable reward for a specific stake.

#### Parameters
- `user`: User address.
- `stakeIndex`: Index of the stake.

#### Returns
- `rewardAmount`: The amount of claimable rewards.

#### Example
```solidity
uint256 rewardAmount = DLCStaking.getRewardAmount(user1, 1);
```

---

### 4. `claim(uint256 stakeIndex)`
Claims the rewards for a specific stake.

#### Parameters
- `stakeIndex`: Index of the stake.

#### Returns
None.

#### Example
```solidity
DLCStaking.claim(1);
```

---

### 5. `exitStake(uint256 stakeIndex)`
Withdraws the staked tokens and rewards after the lock-up period ends.

#### Parameters
- `stakeIndex`: Index of the stake.

#### Returns
None.

#### Example
```solidity
DLCStaking.exitStake(1);
```


### 6. `canExitStake(uint256 stakeIndex) returns (bool)`
If can exit stake.

#### Parameters
- `stakeIndex`：stake index.

#### Returns
- `bool`:If true, can exit stake; else can not exit stake.

#### Example
```solidity
bool canExit = DLCStaking.canExitStake(1);
```


### 7. `getTopStakeHolders(StakeLockTimeType lockTimeType,uint256 pageNumber, uint256 pageSize) → (top100StakerInfo[] memory，uint256)`
Get the information of the top 100 stake holders ranked by the number of staking

#### Parameters
- `lockTimeType`：lock-up period enum type (0:90 days, 1:180 days).
- `pageNumber`：Page number (starting from 1).
- `pageSize`：QuantityPerPage.

#### Returns
- `TopStakerResponse`: Information and quantity of the top 100 staker ranked by stake quantity.
 ```

  struct TopStakerResponse {
      top100StakerInfo[] topStakers;
      uint256 totalStakers;
  }
    
  struct top100StakerInfo {
       address staker;   // staker address
       uint256 totalStakedAmount; // staked amount
       uint256 rewardAmount; // reward amount 
       uint256 startAtTimestamp; // stake start timestamp
  }
  
  ```
#### Example
```solidity
TopStakerResponse memory response = DLCStaking.getTopStakeHolders(0,1,20);
```

### 8. `function getMyStakingInfo(address holder, uint256 pageNumber, uint256 pageSize)returns (stakeInfoForShowing[] memory infos, uint256 total)`
Get the staker's staking information list.

#### Parameters
- `holder`: stakeholder address.
- `pageNumber`：Page number (starting from 1).
- `pageSize`：QuantityPerPage


#### Returns
- `stakeInfoForShowing[] infos`: list of staking information of the stake holder
- `uint256 total`: The total number of pledge information of the stake holder.


#### Example
```solidity
(stakeInfoForShowing[] memory infos, uint256 total) = DLCStaking.getMyStakingInfo(0x01,1,20);
```
 ```
   struct stakeInfoForShowing {
        uint256 stakeIndex; // stake index
        uint256 stakedAmount; // staked amount
        uint256 totalRewardAmount; // total reward amount
        uint256 dailyRewardAmount; // daily reward amount
        uint256 claimedRewardAmount; // claimed reward amount
        bool inStaking; // stake is in staking or not
        uint256 startAtTimestamp; // start at timestamp
        StakeLockTimeType lockTimeType; // lock time type
        bool canExitStaking; // can exit staking or not
    }

  ```

### 9. `function getMyStakingInfoSummary(address holder) external view returns (uint256 days90StakedAmount, uint256 days90RewardAmount, uint256 days180StakedAmount, uint256 days180RewardAmount)`
Get the staker s staking summary information

#### 参数
- `holder`: Address of the stakeholder.


#### 返回值
- `days90StakedAmount`:  The total staking amount during the 90-day lock-up period.
- `days90RewardAmount`: The total amount of rewards staking during the 90-day lock-up period.
- `days180StakedAmount`: The total staking amount during the 180-day lock-up period.
- `days180RewardAmount`: The total amount of rewards staking during the 180-day lock-up period.


#### 示例
```solidity
 (uint256 days90StakedAmount, uint256 days90RewardAmount, uint256 days180StakedAmount, uint256 days180RewardAmount) = DLCStaking.getMyStakingInfoSummary(0x01,1,20);
```

---

## Events

### 1. `Staked(address indexed user, StakeLockTimeType lockTimeType, uint256 amount)`
Triggered when a user successfully stakes tokens.

#### Parameters
- `user`: Address of the user staking tokens.
- `lockTimeType`: Type of the lock-up period.
- `amount`: Amount of tokens staked.

---

### 2. `RewardClaimed(address indexed user, uint256 stakeIndex, uint256 rewardAmount)`
Triggered when a user successfully claims rewards.

#### Parameters
- `user`: Address of the user claiming rewards.
- `stakeIndex`: Index of the stake.
- `rewardAmount`: Amount of rewards claimed.

---

### 3. `StakeExited(address indexed user, uint256 stakeIndex, uint256 amount, uint256 rewardAmount)`
Triggered when a user successfully withdraws their stake and rewards.

#### Parameters
- `user`: Address of the user withdrawing.
- `stakeIndex`: Index of the stake.
- `amount`: Amount of staked tokens withdrawn.
- `rewardAmount`: Amount of rewards withdrawn.

---

## State Variables

### 1. `addressToStakeInfos(address user) → (uint256 stakeIndex, ..., uint256 amount, ..., uint256 totalRewardAmount, ..., uint256 rewardPerSeconds)`
Retrieves the staking information for a user.

#### Parameters
- `user`: User address.

#### Returns
- `stakeIndex`: Index of the stake.
- `amount`: Amount of tokens staked.
- `totalRewardAmount`: Total projected reward amount.
- `rewardPerSeconds`: Reward amount per second.

---

### 2. `currentDays90totalStakedAmount() → uint256`
Retrieves the total staked amount for the 90-day lock-up period.

#### Returns
- `totalAmount`: Total staked amount for the 90-day lock-up period.

---

### 3. `currentDays180totalStakedAmount() → uint256`
Retrieves the total staked amount for the 180-day lock-up period.

#### Returns
- `totalAmount`: Total staked amount for the 180-day lock-up period.

---

### 4. `getTopStakeHolders() → (top10StakerInfo[] memory)`
Get top 10 stakers info with highest staked amount

#### Returns
- `top10StakerInfo[]`: top 10 stakers info with highest staked amount.
 ```
  struct top10StakerInfo {
       address staker;   // staker address
       uint256 totalStakedAmount; // staked amount
       StakeLockTimeType lockTimeType; // lock-up period enum type (0:90 days, 1:180 days)
       uint256 rewardAmount; // reward amount 
  }
  
  ```
---


