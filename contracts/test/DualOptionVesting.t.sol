// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/DualOptionVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockedERC20} from "./mocks/MockedERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MaliciousToken is MockedERC20 {
    address public immutable target;
    address public immutable attacker;

    constructor(address _target, address _attacker) {
        target = _target;
        attacker = _attacker;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        if (to == attacker) {
            DualOptionVesting(payable(target)).claim();
        }
        return true;
    }
}

contract DualOptionVestingTest is Test {
    DualOptionVesting vesting;
    MockedERC20 token;

    address owner;
    address treasury;
    address user1;
    address user2;

    function setUp() public {
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new MockedERC20();

        vm.prank(owner);
        vesting = new DualOptionVesting(address(token), treasury);

        token.mint(address(vesting), 1_000_000 ether);
    }

    function testRevertsOnDeployWithZeroAddressToken() public {
        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.InvalidTokenAddress.selector);
        new DualOptionVesting(address(0), treasury);
    }

    function testRevertsOnDeployWithZeroAddressTreasury() public {
        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.InvalidTreasuryAddress.selector);
        new DualOptionVesting(address(token), address(0));
    }

    function testRegisterBatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 ether;
        amounts[1] = 2000 ether;

        uint256 expectedStartTime = block.timestamp + 1;
        vm.warp(expectedStartTime);

        vm.prank(owner);
        vesting.registerBeneficiaries(users, amounts);

        (uint256 alloc1, uint256 startTime1, ) = vesting.beneficiaries(user1);
        assertEq(alloc1, 1000 ether, "User1 allocation mismatch");
        assertEq(startTime1, expectedStartTime, "User1 start time mismatch");

        (uint256 alloc2, uint256 startTime2, ) = vesting.beneficiaries(user2);
        assertEq(alloc2, 2000 ether, "User2 allocation mismatch");
        assertEq(startTime2, expectedStartTime, "User2 start time mismatch");
    }

    function testRegisterWithEmptyArrays() public {
        address[] memory users = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(owner);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterByNonOwner() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnDoubleRegistration() public {
        registerSingle(user1, 1000 ether);

        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.BeneficiaryAlreadyRegistered.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithInputLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.InputLengthMismatch.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithZeroAddressBeneficiary() public {
        address[] memory users = new address[](1);
        users[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.InvalidBeneficiaryAddress.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithZeroAllocationAmount() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.ZeroAllocationAmount.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testClaimInstantly() public {
        registerSingle(user1, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);

        vm.prank(user1);
        vesting.claim();

        uint256 expectedClaim = (1000 ether * vesting.OPTION_A_BASIS_POINTS()) / vesting.MAX_BASIS_POINTS();
        uint256 expectedForfeit = 1000 ether - expectedClaim;

        assertEq(token.balanceOf(user1), expectedClaim, "User1 balance mismatch");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance + expectedForfeit, "Treasury balance mismatch");

        (uint256 alloc, , uint256 claimed) = vesting.beneficiaries(user1);
        assertEq(alloc, 1000 ether, "Allocation should not change");
        assertEq(claimed, expectedClaim, "Claimed amount mismatch in struct");
    }

    function testClaimPartwayThroughVesting() public {
        registerSingle(user1, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);

        uint256 halfDuration = vesting.VESTING_DURATION() / 2;
        vm.warp(block.timestamp + halfDuration);

        vm.prank(user1);
        vesting.claim();

        uint256 unlockedPercent = vesting.OPTION_A_BASIS_POINTS()
            + (halfDuration * (vesting.MAX_BASIS_POINTS() - vesting.OPTION_A_BASIS_POINTS())) / vesting.VESTING_DURATION();
        uint256 expectedClaim = (1000 ether * unlockedPercent) / vesting.MAX_BASIS_POINTS();
        uint256 expectedForfeit = 1000 ether - expectedClaim;

        assertEq(expectedClaim, 525 ether, "Calculation sanity check failed");
        assertEq(token.balanceOf(user1), expectedClaim, "User1 balance mismatch");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance + expectedForfeit, "Treasury balance mismatch");
    }

    function testClaimAfterFullVesting() public {
        registerSingle(user2, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);

        vm.warp(block.timestamp + vesting.VESTING_DURATION() + 1 days);

        vm.prank(user2);
        vesting.claim();

        assertEq(token.balanceOf(user2), 1000 ether, "User2 should receive full allocation");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance, "Treasury should receive nothing");

        (, , uint256 claimed) = vesting.beneficiaries(user2);
        assertEq(claimed, 1000 ether, "Claimed amount mismatch in struct");
    }

    function testRevertsOnSecondClaim() public {
        registerSingle(user1, 1000 ether);

        vm.prank(user1);
        vesting.claim();

        vm.prank(user1);
        vm.expectRevert(DualOptionVesting.VestingFullyClaimed.selector);
        vesting.claim();
    }

    function testRevertsOnClaimWhenNotEligible() public {
        vm.prank(user2);
        vm.expectRevert(DualOptionVesting.NotEligible.selector);
        vesting.claim();
    }

    function testRevertsOnClaimWhenNothingToClaim() public {
        registerSingle(user1, 1);

        vm.prank(user1);
        vm.expectRevert(DualOptionVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function testRevertsOnClaimReentrancy() public {
        address attacker = makeAddr("attacker");
        address vestingAddr = address(0);
        MaliciousToken maliciousToken = new MaliciousToken(vestingAddr, attacker);
        
        vm.prank(owner);
        DualOptionVesting vestingWithMaliciousToken = new DualOptionVesting(address(maliciousToken), treasury);
        
        // vm.etch(address(maliciousToken), new MaliciousToken(address(vestingWithMaliciousToken), attacker).code);

        maliciousToken.mint(address(vestingWithMaliciousToken), 1000 ether);
        
        address[] memory users = new address[](1);
        users[0] = attacker;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;
        
        vm.prank(owner);
        vestingWithMaliciousToken.registerBeneficiaries(users, amounts);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        vestingWithMaliciousToken.claim();
    }
    
    function testOwnerCanRescueTokens() public {
        address recipient = makeAddr("recipient");
        uint256 initialVestingBalance = token.balanceOf(address(vesting));
        uint256 rescueAmount = 100_000 ether;

        vm.prank(owner);
        vesting.rescueTokens(recipient, rescueAmount);

        assertEq(token.balanceOf(recipient), rescueAmount);
        assertEq(token.balanceOf(address(vesting)), initialVestingBalance - rescueAmount);
    }

    function testOwnerCanDrainAllocatedFunds() public {
        registerSingle(user1, 1000 ether);
        uint256 contractBalance = token.balanceOf(address(vesting));

        vm.prank(owner);
        vesting.rescueTokens(owner, contractBalance);
        assertEq(token.balanceOf(address(vesting)), 0);

        vm.prank(user1);
        vm.expectRevert(bytes("ERC20: subtraction underflow"));
        vesting.claim();
    }

    function testRevertsOnRescueTokensByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        vesting.rescueTokens(user1, 1000 ether);
    }

    function testRevertsOnRescueToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DualOptionVesting.InvalidRecipientAddress.selector);
        vesting.rescueTokens(address(0), 100 ether);
    }

    function testRevertsOnRescueMoreThanBalance() public {
        uint256 balance = token.balanceOf(address(vesting));
        uint256 rescueAmount = balance + 1;

        vm.prank(owner);
        vm.expectRevert();
        vesting.rescueTokens(owner, rescueAmount);
    }

    function registerSingle(address user, uint256 amount) internal {
        address[] memory users = new address[](1);
        users[0] = user;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(owner);
        vesting.registerBeneficiaries(users, amounts);

        (uint256 allocation, uint256 startTime, uint256 claimedAmount) = vesting.beneficiaries(user);
        assertEq(allocation, amount, "Helper: Allocation mismatch");
        assertTrue(startTime > 0, "Helper: Start time not set");
        assertEq(claimedAmount, 0, "Helper: Claimed amount should be 0");
    }
}