// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AgentcoinTvToken} from "../../src/AgentcoinTvToken.sol";

contract AgentcoinTvTokenV3Mock is AgentcoinTvToken {
    function name() public pure override returns (string memory) {
        return "Agentcoin TV Token V3";
    }

    function symbol() public pure override returns (string memory) {
        return "AITVV3";
    }
}
