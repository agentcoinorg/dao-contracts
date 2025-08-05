// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// This interface matches the one expected by the VotingEscrow.vy contract
interface ISmartWalletChecker {
    function check(address _addr) external returns (bool);
}

contract TestSmartWalletChecker is Ownable, ISmartWalletChecker {
    mapping(address => bool) public whitelist;

    constructor() Ownable(msg.sender) {}

    function check(address _addr) external view override returns (bool) {
        return whitelist[_addr];
    }

    function addToWhitelist(address _addr) external onlyOwner {
        whitelist[_addr] = true;
    }
}