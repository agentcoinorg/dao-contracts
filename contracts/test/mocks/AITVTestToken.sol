// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AgentcoinTvToken} from "../../src/AgentcoinTvToken.sol";

contract AITVTestToken is AgentcoinTvToken {
    function name() public pure override returns (string memory) {
        return "AITV Test Token";
    }

    function symbol() public pure override returns (string memory) {
        return "AITVT";
    }
}