// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DualOptionVesting.sol";
import {MockedERC20} from "./mocks/MockedERC20.sol";

contract DualOptionVestingTest is Test {
    DualOptionVesting vesting;
    MockedERC20 token;

    address owner;
    address treasury;
    address user1;
    address user2;
    address user3;

    // Declare reusable arrays for batch operations
    address[] users = new address[](2);
    uint256[] amounts = new uint256[](2);

    function setUp() public {
        owner = address(this);
        treasury = address(0xBEEF);
        user1 = address(0xAAA1);
        user2 = address(0xAAA2);
        user3 = address(0xAAA3);

        token = new MockedERC20();
        vesting = new DualOptionVesting(address(token), treasury);

        // Mint tokens to the test contract (owner) first
        token.mint(owner, 1_000_000 ether);
        
        // Transfer tokens to the vesting contract
        token.transfer(address(vesting), 800_000 ether);
    }

    function testRegisterBatch() public {
        users[0] = user1;
        users[1] = user2;
        amounts[0] = 1000 ether;
        amounts[1] = 2000 ether;

        vesting.registerBeneficiaries(users, amounts);

        (uint256 alloc,,,) = vesting.beneficiaries(user1);
        assertEq(alloc, 1000 ether);
    }

    function testChooseOptionAInstant() public {
        registerSingle(user1, 1000 ether);

        vm.prank(user1);
        vesting.chooseOption(true);

        uint256 expected = 50 ether;
        assertEq(token.balanceOf(user1), expected);
        assertEq(token.balanceOf(treasury), 950 ether);
    }

    function testChooseOptionBDelayedFullClaim() public {
        registerSingle(user2, 1000 ether);

        vm.prank(user2);
        vesting.chooseOption(false);

        // Wait 91 days
        vm.warp(block.timestamp + 91 days);

        vm.prank(user2);
        vesting.claimDelayed();

        assertEq(token.balanceOf(user2), 1000 ether);
    }

    function testChooseOptionBDelayedPartialClaim() public {
        registerSingle(user3, 1000 ether);

        vm.prank(user3);
        vesting.chooseOption(false);

        // Wait 30 days (~33% into vesting)
        vm.warp(block.timestamp + 30 days);

        vm.prank(user3);
        vesting.claimDelayed();

        // unlocked = 5% + 30/90 * 95% = 5 + 31 = 36% (integer division truncates)
        uint256 expected = 360 ether; // 36% of 1000 ether
        assertApproxEqAbs(token.balanceOf(user3), expected, 1e14);
    }

    function testDoubleRegistrationReverts() public {
        // Only use the first slot for single registration
        users[0] = user1;
        amounts[0] = 1000 ether;
        // Truncate arrays to length 1 for single registration
        address[] memory singleUser = new address[](1);
        uint256[] memory singleAmount = new uint256[](1);
        singleUser[0] = user1;
        singleAmount[0] = 1000 ether;

        vesting.registerBeneficiaries(singleUser, singleAmount);

        vm.expectRevert();
        vesting.registerBeneficiaries(singleUser, singleAmount);
    }

    function testDoubleOptionReverts() public {
        registerSingle(user1, 1000 ether);

        vm.prank(user1);
        vesting.chooseOption(true);

        vm.prank(user1);
        vm.expectRevert();
        vesting.chooseOption(true);
    }

    function testOverclaimReverts() public {
        registerSingle(user2, 1000 ether);

        vm.prank(user2);
        vesting.chooseOption(false);

        // Wait full period and claim
        vm.warp(block.timestamp + 91 days);
        vm.prank(user2);
        vesting.claimDelayed();

        // Try to claim again
        vm.prank(user2);
        vm.expectRevert();
        vesting.claimDelayed();
    }

    function testRescueTokens() public {
        // Test that owner can rescue tokens from vesting contract
        uint256 initialBalance = token.balanceOf(owner);
        uint256 vestingBalance = token.balanceOf(address(vesting));
        
        vesting.rescueTokens(owner, 100_000 ether);
        
        assertEq(token.balanceOf(owner), initialBalance + 100_000 ether);
        assertEq(token.balanceOf(address(vesting)), vestingBalance - 100_000 ether);
    }

    function testRescueTokensRevertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        vesting.rescueTokens(user1, 1000 ether);
    }

    function registerSingle(address user, uint256 amount) internal {
        address[] memory singleUser = new address[](1);
        uint256[] memory singleAmount = new uint256[](1);
        singleUser[0] = user;
        singleAmount[0] = amount;

        vesting.registerBeneficiaries(singleUser, singleAmount);
    }
}
