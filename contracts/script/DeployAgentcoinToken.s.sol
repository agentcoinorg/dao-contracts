// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AgentcoinToken} from "../src/AgentcoinToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployAgentcoinTokenScript is Script {
    function setUp() public {}

    function run() public {
        HelperConfig helper = new HelperConfig();

        deploy(helper.getConfig());
    }

    function deploy(HelperConfig.AgentcoinTokenConfig memory config) public returns (AgentcoinToken) {
        vm.startBroadcast();

        AgentcoinToken implementation = new AgentcoinToken();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(AgentcoinToken.initialize, (config.owner, config.recipient))
        );

        vm.stopBroadcast();

        return AgentcoinToken(address(proxy));
    }
}
