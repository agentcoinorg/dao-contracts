// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AgentcoinTvToken} from "../src/AgentcoinTvToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployAgentcoinTvTokenScript is Script {
    function setUp() public {}

    function run() public {
        HelperConfig helper = new HelperConfig();

        deploy(helper.getConfig());
    }

    function deploy(HelperConfig.AgentcoinTvTokenConfig memory config) public returns (AgentcoinTvToken) {
        vm.startBroadcast();

        AgentcoinTvToken implementation = new AgentcoinTvToken();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(AgentcoinTvToken.initialize, (config.owner, config.recipient))
        );

        vm.stopBroadcast();

        return AgentcoinTvToken(address(proxy));
    }
}
