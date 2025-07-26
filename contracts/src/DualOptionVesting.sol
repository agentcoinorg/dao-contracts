// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DualOptionVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable treasury;

    uint256 public constant OPTION_A_PERCENT = 5;
    uint256 public constant VESTING_DURATION = 90 days;

    enum VestingChoice { None, Instant, Delayed }

    struct Beneficiary {
        uint256 allocation;
        uint256 startTime;
        VestingChoice choice;
        uint256 claimedAmount;
    }

    mapping(address => Beneficiary) public beneficiaries;

    event Registered(address indexed user, uint256 amount, uint256 startTime);
    event OptionChosen(address indexed user, VestingChoice choice);
    event Claimed(address indexed user, uint256 amount, VestingChoice choice);

    constructor(address _token, address _treasury) Ownable(msg.sender) {
        require(_token != address(0), "Token required");
        require(_treasury != address(0), "Treasury required");
        token = IERC20(_token);
        treasury = _treasury;
    }

    // 🔁 Batch add beneficiaries
    function registerBeneficiaries(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        require(users.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < users.length; i++) {
            _register(users[i], amounts[i]);
        }
    }

    function _register(address user, uint256 amount) internal {
        require(user != address(0), "Zero address");
        require(amount > 0, "Zero amount");
        require(beneficiaries[user].allocation == 0, "Already registered");

        beneficiaries[user] = Beneficiary({
            allocation: amount,
            startTime: block.timestamp,
            choice: VestingChoice.None,
            claimedAmount: 0
        });

        emit Registered(user, amount, block.timestamp);
    }

    function chooseOption(bool instant) external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        require(b.allocation > 0, "Not eligible");
        require(b.choice == VestingChoice.None, "Already chosen");

        if (instant) {
            b.choice = VestingChoice.Instant;

            uint256 claimAmount = (b.allocation * OPTION_A_PERCENT) / 100;
            uint256 forfeited = b.allocation - claimAmount;

            b.claimedAmount = claimAmount;

            // ✅ Effects before interactions
            emit OptionChosen(msg.sender, VestingChoice.Instant);
            emit Claimed(msg.sender, claimAmount, VestingChoice.Instant);

            token.safeTransfer(msg.sender, claimAmount);
            token.safeTransfer(treasury, forfeited);
        } else {
            b.choice = VestingChoice.Delayed;
            emit OptionChosen(msg.sender, VestingChoice.Delayed);
        }
    }

    function claimDelayed() external nonReentrant {
        Beneficiary storage b = beneficiaries[msg.sender];
        require(b.choice == VestingChoice.Delayed, "Not delayed");
        require(b.claimedAmount < b.allocation, "Fully claimed");

        uint256 elapsed = block.timestamp - b.startTime;
        uint256 claimable;

        if (elapsed >= VESTING_DURATION) {
            claimable = b.allocation - b.claimedAmount;
        } else {
            uint256 unlockedPercent = OPTION_A_PERCENT + ((elapsed * (100 - OPTION_A_PERCENT)) / VESTING_DURATION);
            uint256 totalUnlocked = (b.allocation * unlockedPercent) / 100;
            claimable = totalUnlocked - b.claimedAmount;
        }

        require(claimable > 0, "Nothing to claim");

        b.claimedAmount += claimable;

        emit Claimed(msg.sender, claimable, VestingChoice.Delayed);
        token.safeTransfer(msg.sender, claimable);
    }

    function rescueTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        token.safeTransfer(to, amount);
    }
}
