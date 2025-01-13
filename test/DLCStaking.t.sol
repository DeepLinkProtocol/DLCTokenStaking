// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "ds-test/test.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/DLCStaking.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DLCStakingTest is Test {
    MockERC20 public rewardToken;
    DLCStaking public DlcStaking;
    address public owner;
    address public user1;
    address public user2;

    address public staker1;
    address public staker2;
    address public staker3;
    address public staker4;
    address public staker5;
    address public staker6;
    address public staker7;
    address public staker8;
    address public staker9;
    address public staker10;

    uint256 stakeAmount = 10000 * 1e18;
    uint256 additionalStakeAmount = 50000 * 1e18;

    function setUp() public {
        owner = address(this);
        user1 = address(0x123);
        user2 = address(0x456);

        staker1 = address(0x1);
        staker2 = address(0x2);
        staker3 = address(0x3);

        rewardToken = new MockERC20("Reward Token", "RWT");

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new DLCStaking()),
            abi.encodeWithSelector(DlcStaking.initialize.selector, owner, address(rewardToken))
        );
        DlcStaking = DLCStaking(address(proxy));

        rewardToken.mint(address(DlcStaking), 4_000_000_000 * 1e18);
        rewardToken.mint(user1, 10_000_000 * 1e18);
        rewardToken.mint(user2, 10_000_000 * 1e18);

        rewardToken.mint(staker1, 1000000 * 1e18);
        rewardToken.mint(staker2, 1000000 * 1e18);
        rewardToken.mint(staker3, 1000000 * 1e18);
    }

    function testInitialSetup() public view {
        assertEq(rewardToken.balanceOf(address(DlcStaking)), 4_000_000_000 * 1e18);
        assertEq(rewardToken.balanceOf(user1), 10_000_000 * 1e18);
        assertEq(rewardToken.balanceOf(user2), 10_000_000 * 1e18);
    }

    function testStakeDays90() public {
        vm.startPrank(user1);

        rewardToken.approve(address(DlcStaking), 1_000_000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 1_000_000 * 1e18);

        (uint256 stakeIndex,, uint256 amount,,, uint256 totalRewardAmount,, uint256 rewardPerSeconds,,) =
            DlcStaking.addressToStakeInfos(user1, 1);

        assertEq(stakeIndex, 1);
        assertEq(amount, 1_000_000 * 1e18);
        assertEq(totalRewardAmount, 300_000 * 1e18);
        assertGt(rewardPerSeconds, 0);
        assertEq(DlcStaking.currentDays90totalStakedAmount(), 1_000_000 * 1e18);

        vm.stopPrank();
    }

    function testStakeDays180() public {
        vm.startPrank(user2);

        rewardToken.approve(address(DlcStaking), 2_000_000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days180, 2_000_000 * 1e18);

        (uint256 stakeIndex,, uint256 amount,,, uint256 totalRewardAmount,, uint256 rewardPerSeconds,,) =
            DlcStaking.addressToStakeInfos(user2, 1);
        assertEq(stakeIndex, 1);
        assertEq(amount, 2_000_000 * 1e18);
        assertEq(totalRewardAmount, 1_600_000 * 1e18);
        assertGt(rewardPerSeconds, 0);
        assertEq(DlcStaking.currentDays180totalStakedAmount(), 2_000_000 * 1e18);

        vm.stopPrank();
    }

    function testClaimReward() public {
        vm.startPrank(user1);

        rewardToken.approve(address(DlcStaking), 1_000_000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 1_000_000 * 1e18);

        vm.warp(block.timestamp + 30 days);

        uint256 rewardAmount = DlcStaking.getRewardAmount(user1, 1);
        assertGt(rewardAmount, 0);

        uint256 initialBalance = rewardToken.balanceOf(user1);
        DlcStaking.claim(1);

        assertEq(rewardToken.balanceOf(user1), initialBalance + rewardAmount);
        vm.stopPrank();
    }

    function testExitStake() public {
        vm.startPrank(user2);

        rewardToken.approve(address(DlcStaking), 1_000_000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days180, 1_000_000 * 1e18);

        vm.warp(block.timestamp + 180 days);

        uint256 rewardAmount = DlcStaking.getRewardAmount(user2, 1);
        uint256 initialBalance = rewardToken.balanceOf(user2);

        DlcStaking.exitStake(1);

        assertEq(rewardToken.balanceOf(user2), initialBalance + 1_000_000 * 1e18 + rewardAmount);
        vm.stopPrank();
    }

    function testUpdateTop10_StakerInserted() public {
        vm.startPrank(staker1);
        rewardToken.approve(address(DlcStaking), 10000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 10000 * 1e18);
        vm.stopPrank();

        (address stakerAddr, uint256 stakerAmount,,) = DlcStaking.days90Top100Stakers(0);
        assertEq(stakerAddr, staker1, "Top 10 staker should be staker1");
        assertEq(stakerAmount, 10000 * 1e18, "Staker1's stake amount should be 1000");

        vm.startPrank(staker2);
        rewardToken.approve(address(DlcStaking), 20000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 20000 * 1e18);
        vm.stopPrank();

        (address stakerAddr1, uint256 stakerAmount1,,) = DlcStaking.days90Top100Stakers(0);
        assertEq(stakerAddr1, staker2, "Top 10 staker should be staker2");
        assertEq(stakerAmount1, 20000 * 1e18, "Staker2's stake amount should be 2000");

        (address stakerAddr2,,,) = DlcStaking.days90Top100Stakers(1);
        assertEq(stakerAddr2, staker1, "Top 10 staker should be staker1 at position 1");
    }

    function testUpdateTop10_ReplaceOldStaker() public {
        vm.startPrank(staker1);
        rewardToken.approve(address(DlcStaking), 10000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 10000 * 1e18);
        vm.stopPrank();

        vm.startPrank(staker2);
        rewardToken.approve(address(DlcStaking), 20000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 20000 * 1e18);
        vm.stopPrank();

        vm.startPrank(staker3);
        rewardToken.approve(address(DlcStaking), 50000 * 1e18);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, 50000 * 1e18);
        vm.stopPrank();

        (address stakerAddr,,,) = DlcStaking.days90Top100Stakers(0);
        assertEq(stakerAddr, staker3, "Top 10 staker should be staker3");

        (address stakerAddr1,,,) = DlcStaking.days90Top100Stakers(1);
        assertEq(stakerAddr1, staker2, "Top 10 staker should be staker2");

        (address stakerAddr2,,,) = DlcStaking.days90Top100Stakers(2);
        assertEq(stakerAddr2, staker1, "Top 10 staker should be staker1");
    }

    function testTop100ArrayIsFull() public {
        for (uint256 i = 1; i <= 100; i++) {
            address staker = address(uint160(i));
            uint256 stakeAmount_ = i * 10000 * 1e18;
            rewardToken.mint(staker, 1000000 * 1e18);
            vm.startPrank(staker);
            rewardToken.approve(address(DlcStaking), stakeAmount_);
            DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, stakeAmount_);
            vm.stopPrank();
        }

        for (uint256 i = 0; i < 100; i++) {
            (address stakerAddr1, uint256 totalStakedAmount,,) = DlcStaking.days90Top100Stakers(i);
            assertEq(stakerAddr1, address(uint160(100 - i)), "Top staker should match expected address");
            assertEq(totalStakedAmount, (100 - i) * 10000 * 1e18, "Top staker amount should match expected amount");
        }
    }

    function testUpdateTop100StakersOnNewStake() public {
        vm.startPrank(staker1);
        rewardToken.approve(address(DlcStaking), stakeAmount);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, stakeAmount); // staker1
        vm.stopPrank();

        vm.startPrank(staker2);
        rewardToken.approve(address(DlcStaking), additionalStakeAmount);
        DlcStaking.stake(DLCStaking.StakeLockTimeType.days90, additionalStakeAmount); // staker2
        vm.stopPrank();
        DLCStaking.TopStakerResponse memory r =
            DlcStaking.getTopStakeHolders(DLCStaking.StakeLockTimeType.days90, 1, 20);
        DLCStaking.top100StakerInfo[] memory topStakers = r.topStakers;
        assertEq(topStakers[0].staker, staker2, "staker2 should be the top staker.");
        assertEq(topStakers[1].staker, staker1, "staker1 should be the second staker.");
    }
}
