// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/WstResolv.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";

contract WstResolvTest is Test {
    WstResolv public vault;

    // Mainnet addresses
    address constant ST_RESOLV = 0xFE4BCE4b3949c35fB17691D8b03c3caDBE2E5E23; // Replace with actual stRESOLV address
    address constant RESOLV = 0x259338656198eC7A76c729514D3CB45Dfbf768A1; // Replace with actual RESOLV address

    // Test addresses
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Interfaces for mainnet contracts
    IERC20 stResolv;
    IERC20 resolv;

    function setUp() public {
        // Fork mainnet
        vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(0);

        // Initialize contract interfaces
        stResolv = IERC20(ST_RESOLV);
        resolv = IERC20(RESOLV);

        // Deploy vault
        vault = new WstResolv(ST_RESOLV, RESOLV, "Wrapped Staked RESOLV", "wstRESOLV", owner);

        deal(owner, 10 ether);
        deal(user1, 10 ether);
        deal(user2, 10 ether);

        vm.prank(owner);

        // Get some stRESOLV tokens for testing
        deal(ST_RESOLV, user1, 1000e18);
        deal(ST_RESOLV, user2, 500e18);
    }

    function testDeployment() public {
        assertEq(vault.name(), "Wrapped Staked RESOLV");
        assertEq(vault.symbol(), "wstRESOLV");
        assertEq(vault.owner(), owner);
        assertEq(address(vault.asset()), ST_RESOLV);
        assertEq(address(vault.resolv()), RESOLV);
    }

    function testDeposit() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(user1);
        stResolv.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user1);

        assertEq(vault.balanceOf(user1), shares);
        assertEq(vault.totalAssets(), depositAmount);
        assertGt(shares, 0);
        vm.stopPrank();
    }

    function testMint() public {
        uint256 sharesToMint = 50e18;

        vm.startPrank(user1);
        stResolv.approve(address(vault), type(uint256).max);

        uint256 assets = vault.mint(sharesToMint, user1);

        assertEq(vault.balanceOf(user1), sharesToMint);
        assertEq(vault.totalAssets(), assets);
        assertGt(assets, 0);
        vm.stopPrank();
    }

    function testWithdraw() public {
        // First deposit
        uint256 depositAmount = 100e18;
        vm.startPrank(user1);
        stResolv.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);

        // Then withdraw
        uint256 withdrawAmount = 50e18;
        uint256 sharesBurned = vault.withdraw(withdrawAmount, user1, user1);

        assertEq(stResolv.balanceOf(user1), 950e18); // Original - deposit + withdraw
        assertLt(vault.balanceOf(user1), depositAmount); // Should have fewer shares
        vm.stopPrank();
    }

    function testHarvest() public {
        // Deposit some assets first
        uint256 depositAmount = 100e18;
        vm.startPrank(user1);
        stResolv.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 preBalance = stResolv.balanceOf(address(vault));

        // Skip time to allow harvest
        vm.warp(block.timestamp + 2 hours);

        // Call harvest
        uint256 gained = vault.harvest();

        // Should have updated lastHarvest
        assertEq(vault.lastHarvest(), block.timestamp);
        assertEq(resolv.balanceOf(address(vault)), 0);
        assertEq(stResolv.balanceOf(address(vault)), preBalance + gained);

        // If there were rewards, gained should be > 0
        console.log("Gained from harvest:", gained);
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);
        vault.pause();
        assertTrue(vault.paused());

        vm.stopPrank();

        // Should revert when paused
        vm.startPrank(user1);
        stResolv.approve(address(vault), 100e18);
        vm.expectRevert();
        vault.deposit(100e18, user1);
        vm.stopPrank();

        // Unpause
        vm.prank(owner);
        vault.unpause();
        assertFalse(vault.paused());

        // Should work again
        vm.startPrank(user1);
        vault.deposit(100e18, user1);
        vm.stopPrank();
    }

    function testRescueERC20() public {
        // Deploy a dummy ERC20
        ERC20Mock dummyToken = new ERC20Mock();
        dummyToken.mint(address(vault), 1000e18);

        vm.prank(owner);
        vault.rescueERC20(address(dummyToken), owner, 500e18);

        assertEq(dummyToken.balanceOf(owner), 500e18);
    }

    function testRescueERC20Reverts() public {
        vm.startPrank(owner);

        // Should revert for asset
        vm.expectRevert("cannot rescue asset");
        vault.rescueERC20(ST_RESOLV, owner, 100);

        // Should revert for shares
        vm.expectRevert("cannot rescue shares");
        vault.rescueERC20(address(vault), owner, 100);

        vm.stopPrank();
    }

    function testFuzz_DepositWithdraw(uint256 depositAmount) public {
        // Bound the fuzz input
        depositAmount = bound(depositAmount, 1e18, 500e18);

        vm.startPrank(user1);
        stResolv.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, user1);
        uint256 withdrawn = vault.redeem(shares, user1, user1);

        // Should get back approximately the same amount (minus any fees)
        assertApproxEqRel(withdrawn, depositAmount, 0.01e18); // 1% tolerance
        vm.stopPrank();
    }
}
