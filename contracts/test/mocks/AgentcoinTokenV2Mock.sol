// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AgentcoinToken} from "../../src/AgentcoinToken.sol";

contract AgentcoinTokenV2Mock is AgentcoinToken {
    function testFunction() public pure returns (uint256) {
        return 1;
    }
}
