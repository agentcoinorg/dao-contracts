// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AgentcoinTvToken} from "../../src/AgentcoinTvToken.sol";

contract AgentcoinTvTokenV2Mock is AgentcoinTvToken {
    function testFunction() public pure returns (uint256) {
        return 1;
    }
}
