// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {AgentcoinTvToken} from "../src/AgentcoinTvToken.sol";
import {AITVToken} from "../src/AITVToken.sol";

contract MainnetNameUpgradeTest is Test {
    AgentcoinTvToken private token;
    address private owner = makeAddr("owner");
    address private recipient = makeAddr("recipient");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
        token = AgentcoinTvToken(payable(vm.envAddress("AITV_TOKEN_ADDRESS")));
    }

    function test_canUpgradeNameAndSymbol() public {
        assertEq(token.name(), "Agentcoin TV Token");
        assertEq(token.symbol(), "AITV");

        vm.prank(makeAddr("deployer"));
        address newAddress = address(new AITVToken());

        vm.startPrank(token.owner());
        token.upgradeToAndCall(address(newAddress), "");
        assertEq(token.name(), "AITV");
        assertEq(token.symbol(), "AITV");
        vm.stopPrank();
    }
}
