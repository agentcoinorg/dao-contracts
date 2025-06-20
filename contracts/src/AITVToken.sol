// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AgentcoinTvToken} from "./AgentcoinTvToken.sol";

contract AITVToken is AgentcoinTvToken {
    function name() public pure override returns (string memory) {
        return "AITV";
    }

    function symbol() public pure override returns (string memory) {
        return "AITV";
    }
}
