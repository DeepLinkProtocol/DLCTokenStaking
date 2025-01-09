# DLCStaking 合约接口文档

## 简介
DLCStaking 合约提供了代币质押和奖励管理功能，支持多种锁仓期，用户可以通过质押获取奖励，并在锁仓期结束后提取质押和奖励。

---

## 合约地址
待部署后更新。

---

## 数据结构
### StakeLockTimeType (枚举)
表示支持的锁仓期类型：
- `days90`: 90 天锁仓期 枚举值为0。 
- `days180`: 180 天锁仓期 枚举值为1。

---

## 公共方法

### 1. `initialize(address owner, address rewardToken)`
初始化合约，设置管理员地址和奖励代币地址。

#### 参数
- `owner`：管理员地址。
- `rewardToken`：奖励代币的 ERC20 合约地址。

#### 返回值
无。

---

### 2. `stake(StakeLockTimeType lockTimeType, uint256 amount)`
用户质押代币并选择锁仓期 最小的质押金额是10000个。

#### 参数
- `lockTimeType`：锁仓期类型，接受 `StakeLockTimeType.days90` 或 `StakeLockTimeType.days180`。
- `amount`：质押的代币数量。

#### 返回值
无。

#### 示例
```solidity
    rewardToken.approve(address(DLCStaking), 1_000_000 * 1e18);
    DLCStaking.stake(StakeLockTimeType.days90, 1_000_000 * 1e18);
```

---

### 3. `getRewardAmount(address user, uint256 stakeIndex) → uint256`
获取用户某次质押的当前可领取奖励。

#### 参数
- `user`：用户地址。
- `stakeIndex`：质押索引。

#### 返回值
- `rewardAmount`：可领取的奖励数量。

#### 示例
```solidity
uint256 rewardAmount = DLCStaking.getRewardAmount(user1, 1);
```

---

### 4. `claim(uint256 stakeIndex)`
领取指定质押的奖励。

#### 参数
- `stakeIndex`：质押索引。

#### 返回值
无。

#### 示例
```solidity
DLCStaking.claim(1);
```

---

### 5. `exitStake(uint256 stakeIndex)`
提取质押和奖励，适用于锁仓期结束后的操作。

#### 参数
- `stakeIndex`：质押索引。

#### 返回值
无。

#### 示例
```solidity
DLCStaking.exitStake(1);
```

### 6. `canExitStake(uint256 stakeIndex) returns (bool)`
获取是否可以退出质押。

#### 参数
- `stakeIndex`：质押索引。

#### 返回值
- `bool`:是否可以退出质押的布尔值。

#### 示例
```solidity
bool canExit = DLCStaking.canExitStake(1);
```


### 7. `getTopStakeHolders(StakeLockTimeType lockTimeType,uint256 pageNumber, uint256 pageSize) → (top100StakerInfo[] memory，uint256)`
获取按质押数量排行的前 100 位质押者信息。

#### 参数
- `lockTimeType`：锁仓期类型枚举 (0:90 days, 1:180 days)。
- `pageNumber`：页码(从1开始)。
- `pageSize`：每页数量。

#### 返回值
- `top100StakerInfo[]`: 按质押数量排行的前 100 位质押者信息。
- `uint256 staker`: 质押数量排行的总人数。
 ```
  struct top100StakerInfo {
       address staker;   // staker address
       uint256 totalStakedAmount; // staked amount
       uint256 rewardAmount; // reward amount 
       uint256 startAtTimestamp; // stake start timestamp
  }
  
  ```
#### Example
```solidity
(top100StakerInfo[] memory topStakers，uint256 total) = DLCStaking.getTopStakeHolders(0,1,20);
```

### 8. `function getMyStakingInfo(address holder, uint256 pageNumber, uint256 pageSize)returns (stakeInfoForShowing[] memory infos, uint256 total)`
获取质押者质押信息列表。

#### 参数
- `holder`: 质押者地址。
- `pageNumber`：页码(从1开始)。
- `pageSize`：每页数量。


#### 返回值
- `stakeInfoForShowing[] infos`: 质押者的质押信息列表。
- `uint256 total`: 质押者的质押信息总数。


#### 示例
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
    }

  ```

---

## 事件

### 1. `Staked(address indexed user, StakeLockTimeType lockTimeType, uint256 amount)`
当用户成功质押时触发。

#### 参数
- `user`：质押的用户地址。
- `lockTimeType`：锁仓期类型。
- `amount`：质押数量。

---

### 2. `RewardClaimed(address indexed user, uint256 stakeIndex, uint256 rewardAmount)`
当用户成功领取奖励时触发。

#### 参数
- `user`：领取奖励的用户地址。
- `stakeIndex`：质押索引。
- `rewardAmount`：领取的奖励数量。

---

### 3. `StakeExited(address indexed user, uint256 stakeIndex, uint256 amount, uint256 rewardAmount)`
当用户成功提取质押和奖励时触发。

#### 参数
- `user`：提取的用户地址。
- `stakeIndex`：质押索引。
- `amount`：提取的质押数量。
- `rewardAmount`：提取的奖励数量。

---

## 状态变量

### 1. `addressToStakeInfos(address user) → (uint256 stakeIndex, ..., uint256 amount, ..., uint256 totalRewardAmount, ..., uint256 rewardPerSeconds)`
获取用户的质押信息。

#### 参数
- `user`：用户地址。

#### 返回值
- `stakeIndex`：质押索引。
- `amount`：质押的代币数量。
- `totalRewardAmount`：预计的总奖励数量。
- `rewardPerSeconds`：每秒奖励数量。

---

### 2. `currentDays90totalStakedAmount() → uint256`
获取当前 90 天锁仓期的总质押量。

#### 返回值
- `totalAmount`：90 天锁仓期的总质押量。

---

### 3. `currentDays180totalStakedAmount() → uint256`
获取当前 180 天锁仓期的总质押量。

#### 返回值
- `totalAmount`：180 天锁仓期的总质押量。
---