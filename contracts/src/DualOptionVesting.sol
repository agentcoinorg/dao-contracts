// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DualOptionVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidTokenAddress();
    error InvalidTreasuryAddress();
    error InvalidRecipientAddress();
    error InputLengthMismatch();
    error InvalidBeneficiaryAddress();
    error ZeroAllocationAmount();
    error BeneficiaryAlreadyRegistered();
    error NotEligible();
    error VestingFullyClaimed();
    error NothingToClaim();

    IERC20 public immutable token;
    address public immutable treasury;

    uint256 public constant MAX_BASIS_POINTS = 1e4;
    uint256 public constant OPTION_A_BASIS_POINTS = 500; // 5% base vesting
    uint256 public constant VESTING_DURATION = 90 days;

    struct Beneficiary {
        uint256 allocation;
        uint256 startTime;
        uint256 claimedAmount;
    }

    mapping(address => Beneficiary) public beneficiaries;

    event Registered(address indexed user, uint256 amount, uint256 startTime);
    event Claimed(address indexed user, uint256 claimedAmount, uint256 forfeitedAmount);

    constructor(address _token, address _treasury) Ownable(msg.sender) {
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_treasury == address(0)) revert InvalidTreasuryAddress();
        token = IERC20(_token);
        treasury = _treasury;
    }

    function claim() external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        if (b.allocation == 0) revert NotEligible();
        if (b.claimedAmount > 0) revert VestingFullyClaimed(); // Already claimed

        uint256 elapsed = block.timestamp - b.startTime;
        uint256 allocation = b.allocation;
        uint256 claimableAmount;

        if (elapsed >= VESTING_DURATION) {
            claimableAmount = allocation;
        } else {
            // Vested amount is 5% base + a linear portion of the remaining 95%
            uint256 unlockedPercent = OPTION_A_BASIS_POINTS + ((elapsed * (MAX_BASIS_POINTS - OPTION_A_BASIS_POINTS)) / VESTING_DURATION);
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

    function registerBeneficiaries(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        if (users.length != amounts.length) revert InputLengthMismatch();
        uint256 length = users.length;

        for (uint256 i = 0; i < length; ++i) {
            _register(users[i], amounts[i]);
        }
    }

    function rescueTokens(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert InvalidRecipientAddress();
        token.safeTransfer(to, amount);
    }

    function _register(address user, uint256 amount) internal {
        if (user == address(0)) revert InvalidBeneficiaryAddress();
        if (amount == 0) revert ZeroAllocationAmount();
        if (beneficiaries[user].allocation != 0) revert BeneficiaryAlreadyRegistered();

        beneficiaries[user] = Beneficiary({
            allocation: amount,
            startTime: block.timestamp,
            claimedAmount: 0
        });

        emit Registered(user, amount, block.timestamp);
    }
}