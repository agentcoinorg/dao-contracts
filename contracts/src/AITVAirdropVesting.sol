// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IVotingEscrow {
    function deposit_for(address _addr, uint256 _value) external;
    function locked(address _addr) external view returns (int128 amount, uint256 end);
}

/// @title AITVAirdropVesting
/// @notice Manages the vesting of airdropped tokens for beneficiaries. Users can either claim tokens over time or deposit their entire allocation into a voting escrow lock.
/// @dev Implements a linear vesting schedule with an initial immediate unlock. It integrates with a VotingEscrow contract to allow staking of the full airdrop amount, bypassing the normal vesting schedule if the lock duration is sufficient.
contract AITVAirdropVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidTokenAddress();
    error InvalidTreasuryAddress();
    error NoVotingEscrowConfigured();
    error InvalidRecipientAddress();
    error InputLengthMismatch();
    error InvalidBeneficiaryAddress();
    error ZeroAllocationAmount();
    error BeneficiaryAlreadyRegistered();
    error NotEligible();
    error AlreadyClaimed();
    error NothingToClaim();
    error InvalidUnlockTime();
    error LockDurationTooShort();
    error NoActiveLock();
    error MissingBeneficiary();

    /// @notice The ERC20 token being vested.
    IERC20 public immutable token;
    /// @notice The address where forfeited tokens are sent.
    address public immutable treasury;
    /// @notice The Voting Escrow contract for staking airdropped tokens.
    IVotingEscrow public immutable votingEscrow;

    /// @notice The total basis points representing 100% (10,000).
    uint256 public constant MAX_BASIS_POINTS = 1e4;
    /// @notice The percentage of tokens unlocked immediately, in basis points (500 = 5%).
    uint256 public constant IMMEDIATE_UNLOCK_BASIS_POINTS = 500;
    /// @notice The total duration over which the remaining tokens vest.
    uint256 public constant VESTING_DURATION = 90 days;
    /// @notice The minimum required duration for a user's lock in the VotingEscrow.
    uint256 public constant MIN_STAKE_DURATION = 90 days;

    /// @notice Struct to store vesting details for each beneficiary.
    struct Beneficiary {
        /// @param allocation The total number of tokens allocated to the beneficiary.
        uint256 allocation;
        /// @param startTime The timestamp when the vesting period begins.
        uint256 startTime;
        /// @param claimedAmount The amount of tokens already claimed by the beneficiary.
        uint256 claimedAmount;
    }

    /// @notice Mapping from a beneficiary's address to their vesting details.
    mapping(address => Beneficiary) public beneficiaries;

    event Registered(address indexed user, uint256 amount, uint256 startTime);
    event Claimed(address indexed user, uint256 claimedAmount, uint256 forfeitedAmount);
    event ClaimedAndDepositedToLock(address indexed user, uint256 amount, uint256 unlockTime);

    /// @notice Initializes the vesting contract.
    /// @param _token The address of the ERC20 token to be vested.
    /// @param _treasury The address of the treasury to receive forfeited tokens.
    /// @param _votingEscrow The address of the Voting Escrow contract for staking. Can be address(0) if not used.
    constructor(address _owner, address _token, address _treasury, address _votingEscrow) Ownable(_owner) {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_treasury == address(0)) revert InvalidTreasuryAddress();
        token = IERC20(_token);
        treasury = _treasury;

        if (_votingEscrow != address(0)) {
            votingEscrow = IVotingEscrow(_votingEscrow);
        }
    }

    /// @notice Allows a beneficiary to claim their currently vested tokens.
    /// @dev Calculates the claimable amount based on a linear vesting schedule. Any unvested tokens are forfeited to the treasury. This can only be called once.
    function claimAndForfeitRemaining() external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        if (b.allocation == 0) revert NotEligible();
        if (b.claimedAmount > 0) revert AlreadyClaimed();

        uint256 elapsed = block.timestamp - b.startTime;
        uint256 allocation = b.allocation;
        uint256 claimableAmount;

        if (elapsed >= VESTING_DURATION) {
            claimableAmount = allocation;
        } else {
            uint256 unlockedPercent =
                IMMEDIATE_UNLOCK_BASIS_POINTS + ((elapsed * (MAX_BASIS_POINTS - IMMEDIATE_UNLOCK_BASIS_POINTS)) / VESTING_DURATION);
            claimableAmount = (allocation * unlockedPercent) / MAX_BASIS_POINTS;
        }

        if (claimableAmount == 0) revert NothingToClaim();

        uint256 forfeitedAmount = allocation - claimableAmount;

        b.claimedAmount = claimableAmount;
        emit Claimed(msg.sender, claimableAmount, forfeitedAmount);

        token.safeTransfer(msg.sender, claimableAmount);
        if (forfeitedAmount > 0) {
            token.safeTransfer(treasury, forfeitedAmount);
        }
    }

    /// @notice Allows a beneficiary to claim their full allocation and deposit it into an existing Voting Escrow lock.
    /// @dev Bypasses the standard vesting schedule. The user must have an active lock in the Voting Escrow contract with a duration meeting `MIN_STAKE_DURATION`. Requires prior approval for the Voting Escrow contract.
    function claimAndDepositToLock() external nonReentrant {
        if (address(votingEscrow) == address(0)) revert NoVotingEscrowConfigured();

        Beneficiary storage b = beneficiaries[msg.sender];
        if (b.allocation == 0) revert NotEligible();
        if (b.claimedAmount > 0) revert AlreadyClaimed();

        (, uint256 lockedEnd) = votingEscrow.locked(msg.sender);

        if (lockedEnd <= block.timestamp) revert NoActiveLock();

        if (lockedEnd < block.timestamp + MIN_STAKE_DURATION) revert LockDurationTooShort();

        uint256 allocation = b.allocation;
        b.claimedAmount = allocation;

        // The VotingEscrow contract's deposit_for function pulls funds from the user's balance
        // Therefore, this contract must first transfer the tokens to the user (msg.sender)
        token.safeTransfer(msg.sender, allocation);

        // Now that the user has the tokens, we can call deposit_for on their behalf
        // This will trigger a `transferFrom` from the user's balance to the VotingEscrow
        // This requires the user to have approved the VotingEscrow contract in a prior transaction
        votingEscrow.deposit_for(msg.sender, allocation);

        emit ClaimedAndDepositedToLock(msg.sender, allocation, lockedEnd);
    }

    /// @notice Registers multiple beneficiaries and their allocations.
    /// @dev Only the owner can call this function.
    /// @param _users An array of beneficiary addresses.
    /// @param _amounts An array of token allocation amounts corresponding to each user.
    function registerBeneficiaries(address[] calldata _users, uint256[] calldata _amounts) external onlyOwner {
        if (_users.length == 0 || _amounts.length == 0) revert MissingBeneficiary();

        if (_users.length != _amounts.length) revert InputLengthMismatch();
        uint256 length = _users.length;
        for (uint256 i = 0; i < length; ++i) {
            _register(_users[i], _amounts[i]);
        }
    }

    /// @notice Allows the owner to withdraw any excess tokens from this contract.
    /// @dev Useful for recovering tokens sent to the contract by mistake, or for migrating to a new contract.
    /// @param _to The address to receive the rescued tokens.
    /// @param _amount The amount of tokens to rescue.
    function rescueTokens(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert InvalidRecipientAddress();
        token.safeTransfer(_to, _amount);
    }

    /// @notice Internal function to register a single beneficiary.
    /// @dev Sets the beneficiary's allocation and start time. Reverts if the user is already registered.
    /// @param _user The address of the beneficiary to register.
    /// @param _amount The token allocation for the beneficiary.
    function _register(address _user, uint256 _amount) internal {
        if (_user == address(0)) revert InvalidBeneficiaryAddress();
        if (_amount == 0) revert ZeroAllocationAmount();
        if (beneficiaries[_user].allocation != 0) revert BeneficiaryAlreadyRegistered();

        beneficiaries[_user] = Beneficiary({
            allocation: _amount, 
            startTime: block.timestamp, 
            claimedAmount: 0
        });

        emit Registered(_user, _amount, block.timestamp);
    }
}