// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AITVAirdropVesting} from "../src/AITVAirdropVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockedERC20} from "./mocks/MockedERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TestSmartWalletChecker} from "./mocks/TestSmartWalletChecker.sol";

contract MaliciousToken is MockedERC20 {
    address public target;
    address public immutable attacker;

    constructor(address _target, address _attacker) {
        target = _target;
        attacker = _attacker;
    }

    function setTarget(address _newTarget) external {
        target = _newTarget;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        if (to == attacker) {
            AITVAirdropVesting(payable(target)).claim();
        }
        return true;
    }
}

interface ITestVotingEscrow {
    function create_lock(uint256 _value, uint256 _unlock_time) external;
    function deposit_for(address _addr, uint256 _value) external;
    function locked(address _addr) external view returns (int128 amount, uint256 end);
    function commit_smart_wallet_checker(address _addr) external;
    function apply_smart_wallet_checker() external;
}

contract AITVAirdropVestingTest is Test {
    uint256 constant MIN_STAKE_DURATION = 90 days;
    uint256 constant ONE_WEEK = 7 days;

    AITVAirdropVesting vesting;
    MockedERC20 token;
    ITestVotingEscrow votingEscrow; // Using the correct test interface
    TestSmartWalletChecker smartWalletChecker;

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
        votingEscrow = _deployVotingEscrow(address(token));

        vm.prank(owner);
        smartWalletChecker = new TestSmartWalletChecker();
        
        // Set the smart wallet checker in the voting escrow
        vm.startPrank(owner);
        votingEscrow.commit_smart_wallet_checker(address(smartWalletChecker));
        votingEscrow.apply_smart_wallet_checker();

        // This allows them to call create_lock from the test contract,
        // working around the testing environment's tx.origin behavior.
        smartWalletChecker.addToWhitelist(user1);
        smartWalletChecker.addToWhitelist(user2);
        
        vesting = new AITVAirdropVesting(address(token), treasury, address(votingEscrow));

        vm.stopPrank();

        token.mint(address(vesting), 1_000_000 ether);
        token.mint(user1, 100 ether);
        token.mint(user2, 100 ether);
    }

    function testRevertsOnDeployWithZeroAddressToken() public {
        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.InvalidTokenAddress.selector);
        new AITVAirdropVesting(address(0), treasury, address(votingEscrow));
    }

    function testRevertsOnDeployWithZeroAddressTreasury() public {
        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.InvalidTreasuryAddress.selector);
        new AITVAirdropVesting(address(token), address(0), address(votingEscrow));
    }

    function testRevertsOnDeployWithZeroAddressVotingEscrow() public {
        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.InvalidVotingEscrowAddress.selector);
        new AITVAirdropVesting(address(token), treasury, address(0));
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
        vm.expectRevert(AITVAirdropVesting.BeneficiaryAlreadyRegistered.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithInputLengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.InputLengthMismatch.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithZeroAddressBeneficiary() public {
        address[] memory users = new address[](1);
        users[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 ether;

        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.InvalidBeneficiaryAddress.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testRevertsOnRegisterWithZeroAllocationAmount() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        vm.prank(owner);
        vm.expectRevert(AITVAirdropVesting.ZeroAllocationAmount.selector);
        vesting.registerBeneficiaries(users, amounts);
    }

    function testClaimInstantly() public {
        registerSingle(user1, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);
        uint256 initialUserBalance = token.balanceOf(user1);

        vm.prank(user1);
        vesting.claim();

        uint256 expectedClaim = (1000 ether * vesting.OPTION_A_BASIS_POINTS()) / vesting.MAX_BASIS_POINTS();
        uint256 expectedForfeit = 1000 ether - expectedClaim;

        assertEq(token.balanceOf(user1), initialUserBalance + expectedClaim, "User1 balance mismatch");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance + expectedForfeit, "Treasury balance mismatch");

        (uint256 alloc, , uint256 claimed) = vesting.beneficiaries(user1);
        assertEq(alloc, 1000 ether, "Allocation should not change");
        assertEq(claimed, expectedClaim, "Claimed amount mismatch in struct");
    }

    function testClaimPartwayThroughVesting() public {
        registerSingle(user1, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);
        uint256 initialUserBalance = token.balanceOf(user1);

        uint256 halfDuration = vesting.VESTING_DURATION() / 2;
        vm.warp(block.timestamp + halfDuration);

        vm.prank(user1);
        vesting.claim();

        uint256 unlockedPercent = vesting.OPTION_A_BASIS_POINTS()
            + (halfDuration * (vesting.MAX_BASIS_POINTS() - vesting.OPTION_A_BASIS_POINTS())) / vesting.VESTING_DURATION();
        uint256 expectedClaim = (1000 ether * unlockedPercent) / vesting.MAX_BASIS_POINTS();
        uint256 expectedForfeit = 1000 ether - expectedClaim;

        assertEq(expectedClaim, 525 ether, "Calculation sanity check failed");
        assertEq(token.balanceOf(user1), initialUserBalance + expectedClaim, "User1 balance mismatch");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance + expectedForfeit, "Treasury balance mismatch");
    }

    function testClaimAfterFullVesting() public {
        registerSingle(user2, 1000 ether);
        uint256 initialTreasuryBalance = token.balanceOf(treasury);
        uint256 initialUserBalance = token.balanceOf(user2);

        vm.warp(block.timestamp + vesting.VESTING_DURATION() + 1 days);

        vm.prank(user2);
        vesting.claim();

        assertEq(token.balanceOf(user2), initialUserBalance + 1000 ether, "User2 should receive full allocation");
        assertEq(token.balanceOf(treasury), initialTreasuryBalance, "Treasury should receive nothing");

        (, , uint256 claimed) = vesting.beneficiaries(user2);
        assertEq(claimed, 1000 ether, "Claimed amount mismatch in struct");
    }

    function testRevertsOnSecondClaim() public {
        registerSingle(user1, 1000 ether);

        vm.prank(user1);
        vesting.claim();

        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.VestingFullyClaimed.selector);
        vesting.claim();
    }

    function testClaimAndDepositToLockSuccess() public {
        uint256 allocation = 1000 ether;
        registerSingle(user1, allocation);

        // User creates their own lock with sufficient duration
        uint256 initialUserLockAmount = 1 ether;
        // Escrow rounds down to the week, so we must calculate the unlock time this way
        uint256 unlockTime = ((block.timestamp + MIN_STAKE_DURATION + 1 days) / ONE_WEEK) * ONE_WEEK;
        vm.prank(user1);
        token.approve(address(votingEscrow), initialUserLockAmount);
        vm.prank(user1);
        votingEscrow.create_lock(initialUserLockAmount, unlockTime);

        // User calls the vesting contract to deposit their allocation
        // The event has 1 indexed topic (user) and 2 data fields (amount, unlockTime).
        // Therefore, we check topic1=true, topic2=false, topic3=false, data=true.
        vm.expectEmit(true, false, false, true);
        emit AITVAirdropVesting.ClaimedAndDepositedToLock(user1, allocation, unlockTime);

        vm.prank(user1);
        vesting.claimAndDepositToLock();

        (int128 finalAmount, uint256 finalEnd) = votingEscrow.locked(user1);
        assertEq(uint256(int256(finalAmount)), initialUserLockAmount + allocation, "VE lock amount is incorrect");
        assertEq(finalEnd, unlockTime, "VE lock end time is incorrect");

        (, , uint256 claimed) = vesting.beneficiaries(user1);
        assertEq(claimed, allocation, "Claimed amount in struct should be full allocation");
    }

    function testRevertsClaimAndDepositToLockWhenLockIsTooShort() public {
        registerSingle(user1, 1000 ether);

        // User creates a lock with INSUFFICIENT duration
        uint256 initialUserLockAmount = 1 ether;
        uint256 unlockTime = ((block.timestamp + MIN_STAKE_DURATION - 2 days) / ONE_WEEK) * ONE_WEEK;
        vm.prank(user1);
        token.approve(address(votingEscrow), initialUserLockAmount);
        vm.prank(user1);
        votingEscrow.create_lock(initialUserLockAmount, unlockTime);

        // Expect revert when they try to claim and deposit
        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.LockDurationTooShort.selector);
        vesting.claimAndDepositToLock();
    }

    function testRevertsClaimAndDepositToLockWhenNoLockExists() public {
        registerSingle(user1, 1000 ether);

        // User has NOT created a lock.
        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.NoActiveLock.selector);
        vesting.claimAndDepositToLock();
    }

    function testRevertsRegularClaimAfterClaimAndDepositToLock() public {
        registerSingle(user1, 1000 ether);

        // User creates a valid lock
        // The lock's end time must be >= block.timestamp + MIN_STAKE_DURATION *at the time of the claim*.
        // Because time advances between creating the lock and claiming, we must add a small buffer
        // to ensure the lock is still valid when claimAndDepositToLock is called.
        uint256 unlockTime = ((block.timestamp + MIN_STAKE_DURATION + 1 days) / ONE_WEEK) * ONE_WEEK;
        vm.prank(user1);
        token.approve(address(votingEscrow), 1 ether);
        vm.prank(user1);
        votingEscrow.create_lock(1 ether, unlockTime);

        // User claims and deposits
        vm.prank(user1);
        vesting.claimAndDepositToLock();

        // User cannot call regular claim afterwards
        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.VestingFullyClaimed.selector);
        vesting.claim();
    }

    function testRevertsClaimAndDepositToLockAfterRegularClaim() public {
        registerSingle(user1, 1000 ether);
        vm.prank(user1);
        vesting.claim();

        // User then creates a lock
        uint256 unlockTime = ((block.timestamp + MIN_STAKE_DURATION + 1 days) / ONE_WEEK) * ONE_WEEK;
        vm.prank(user1);
        token.approve(address(votingEscrow), 1 ether);
        vm.prank(user1);
        votingEscrow.create_lock(1 ether, unlockTime);

        // User cannot call claimAndDepositToLock afterwards
        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.VestingFullyClaimed.selector);
        vesting.claimAndDepositToLock();
    }

    function testRevertsClaimAndDepositToLockWhenNotEligible() public {
        // User2 is not registered
        vm.prank(user2);
        vm.expectRevert(AITVAirdropVesting.NotEligible.selector);
        vesting.claimAndDepositToLock();
    }

    function testRevertsOnClaimWhenNotEligible() public {
        vm.prank(user2);
        vm.expectRevert(AITVAirdropVesting.NotEligible.selector);
        vesting.claim();
    }

    function testRevertsOnClaimWhenNothingToClaim() public {
        registerSingle(user1, 1);

        vm.prank(user1);
        vm.expectRevert(AITVAirdropVesting.NothingToClaim.selector);
        vesting.claim();
    }

    function testRevertsOnClaimReentrancy() public {
        address attacker = makeAddr("attacker");
        MaliciousToken maliciousToken = new MaliciousToken(address(0), attacker);

        vm.prank(owner);
        AITVAirdropVesting vestingWithMaliciousToken =
            new AITVAirdropVesting(address(maliciousToken), treasury, address(votingEscrow));

        maliciousToken.setTarget(address(vestingWithMaliciousToken));

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
        vm.expectRevert(AITVAirdropVesting.InvalidRecipientAddress.selector);
        vesting.rescueTokens(address(0), 100 ether);
    }

    function testRevertsOnRescueMoreThanBalance() public {
        uint256 balance = token.balanceOf(address(vesting));
        uint256 rescueAmount = balance + 1;

        vm.prank(owner);
        vm.expectRevert();
        vesting.rescueTokens(owner, rescueAmount);
    }

    function registerSingle(address _user, uint256 _amount) internal {
        address[] memory users = new address[](1);
        users[0] = _user;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        vm.prank(owner);
        vesting.registerBeneficiaries(users, amounts);
    }

    function _deployVotingEscrow(address _token) internal returns (ITestVotingEscrow) {
        string memory name = "Vote-escrowed CRV";
        string memory symbol = "veCRV";
        string memory version = "1";
        string memory artifactPath = "out/VotingEscrow.vy/VotingEscrow.vy.json";
        string memory json = vm.readFile(artifactPath);

        string memory bytecodePath = "['lib/curve-dao-contracts/contracts/VotingEscrow.vy'].bytecode";
        bytes memory bytecode = vm.parseJsonBytes(json, bytecodePath);
        bytes memory constructorArgs = abi.encode(_token, name, symbol, version);
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);

        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(fullBytecode, 0x20), mload(fullBytecode))
        }
        return ITestVotingEscrow(deployedAddress);
    }
}