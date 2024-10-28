// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Agentcoin Token
/// @notice The following is an ERC20 token contract for the Agentcoin token
/// @dev It is upgradable and has snapshot functionality
/// The Agentcoin token is minted with a maximum supply of 1,000,000,000 tokens
contract AgentcoinToken is ERC20VotesUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address recipient) initializer public {
        string memory name = "Agentcoin Token";
        string memory symbol = "AGENT";

        __ERC20_init(name, symbol);
        __ERC20Votes_init();
        __Ownable_init(owner);
        __UUPSUpgradeable_init();

        _mint(recipient, MAX_TOTAL_SUPPLY);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner() {}
}
