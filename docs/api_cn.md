# CexStaking 合约接口文档

## 简介
CexStaking 合约提供了代币质押和奖励管理功能，支持多种锁仓期，用户可以通过质押获取奖励，并在锁仓期结束后提取质押和奖励。

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
    rewardToken.approve(address(cexStaking), 1_000_000 * 1e18);
    cexStaking.stake(StakeLockTimeType.days90, 1_000_000 * 1e18);
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
uint256 rewardAmount = cexStaking.getRewardAmount(user1, 1);
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
cexStaking.claim(1);
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
cexStaking.exitStake(1);
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

### 4. `getTopStakeHolders() → (top10StakerInfo[] memory)`
获取按质押数量排行的前 10 位质押者信息。

#### 返回值
- `top10StakerInfo[]`: 按质押数量排行的前 10 位质押者信息。
 ```
  struct top10StakerInfo {
       address staker;   // staker address
       uint256 totalStakedAmount; // staked amount
       StakeLockTimeType lockTimeType; // lock-up period enum type (0:90 days, 1:180 days)
       uint256 rewardAmount; // reward amount 
  }
  
  ```
---