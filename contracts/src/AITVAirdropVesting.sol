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

contract AITVAirdropVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidTokenAddress();
    error InvalidTreasuryAddress();
    error InvalidVotingEscrowAddress();
    error InvalidRecipientAddress();
    error InputLengthMismatch();
    error InvalidBeneficiaryAddress();
    error ZeroAllocationAmount();
    error BeneficiaryAlreadyRegistered();
    error NotEligible();
    error VestingFullyClaimed();
    error NothingToClaim();
    error InvalidUnlockTime();
    error LockDurationTooShort();
    error NoActiveLock();

    IERC20 public immutable token;
    address public immutable treasury;
    IVotingEscrow public immutable votingEscrow;

    uint256 public constant MAX_BASIS_POINTS = 1e4;
    uint256 public constant OPTION_A_BASIS_POINTS = 500; // 5% base vesting
    uint256 public constant VESTING_DURATION = 90 days;
    uint256 public constant MIN_STAKE_DURATION = 90 days;

    struct Beneficiary {
        uint256 allocation;
        uint256 startTime;
        uint256 claimedAmount;
    }

    mapping(address => Beneficiary) public beneficiaries;

    event Registered(address indexed user, uint256 amount, uint256 startTime);
    event Claimed(address indexed user, uint256 claimedAmount, uint256 forfeitedAmount);
    event ClaimedAndDepositedToLock(address indexed user, uint256 amount, uint256 unlockTime);

    constructor(address _token, address _treasury, address _votingEscrow) Ownable(msg.sender) {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_treasury == address(0)) revert InvalidTreasuryAddress();
        if (_votingEscrow == address(0)) revert InvalidVotingEscrowAddress();
        token = IERC20(_token);
        treasury = _treasury;
        votingEscrow = IVotingEscrow(_votingEscrow);
    }

    function claim() external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        if (b.allocation == 0) revert NotEligible();
        if (b.claimedAmount > 0) revert VestingFullyClaimed();

        uint256 elapsed = block.timestamp - b.startTime;
        uint256 allocation = b.allocation;
        uint256 claimableAmount;

        if (elapsed >= VESTING_DURATION) {
            claimableAmount = allocation;
        } else {
            uint256 unlockedPercent =
                OPTION_A_BASIS_POINTS + ((elapsed * (MAX_BASIS_POINTS - OPTION_A_BASIS_POINTS)) / VESTING_DURATION);
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

    /**
     * @notice Deposits the user's full allocation into their existing VE lock,
     *         provided the lock's duration meets the minimum requirement.
     * @dev The user must have already created a lock on the VotingEscrow contract.
     *      This function verifies the lock's end time before depositing.
     */
    function claimAndDepositToLock() external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        if (b.allocation == 0) revert NotEligible();
        if (b.claimedAmount > 0) revert VestingFullyClaimed();

        (, uint256 lockedEnd) = votingEscrow.locked(msg.sender);

        if (lockedEnd <= block.timestamp) revert NoActiveLock();

        if (lockedEnd < block.timestamp + MIN_STAKE_DURATION) revert LockDurationTooShort();

        uint256 allocation = b.allocation;
        b.claimedAmount = allocation;

        token.approve(address(votingEscrow), allocation);
        votingEscrow.deposit_for(msg.sender, allocation);

        emit ClaimedAndDepositedToLock(msg.sender, allocation, lockedEnd);
    }

    function registerBeneficiaries(address[] calldata _users, uint256[] calldata _amounts) external onlyOwner {
        if (_users.length != _amounts.length) revert InputLengthMismatch();
        uint256 length = _users.length;
        for (uint256 i = 0; i < length; ++i) {
            _register(_users[i], _amounts[i]);
        }
    }

    function rescueTokens(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert InvalidRecipientAddress();
        token.safeTransfer(_to, _amount);
    }

    function _register(address _user, uint256 _amount) internal {
        if (_user == address(0)) revert InvalidBeneficiaryAddress();
        if (_amount == 0) revert ZeroAllocationAmount();
        if (beneficiaries[_user].allocation != 0) revert BeneficiaryAlreadyRegistered();

        beneficiaries[_user] = Beneficiary({allocation: _amount, startTime: block.timestamp, claimedAmount: 0});

        emit Registered(_user, _amount, block.timestamp);
    }
}