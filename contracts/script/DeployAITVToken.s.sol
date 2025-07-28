// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AITVToken} from "../src/AITVToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AgentcoinTvToken} from "../src/AgentcoinTvToken.sol";

contract DeployAITVToken is Script {
    function setUp() public {}

    function run() public {
        HelperConfig helper = new HelperConfig();

        deploy(helper.getConfig());
    }

    function deploy(HelperConfig.AgentcoinTvTokenConfig memory config) public returns (AITVToken) {
        vm.startBroadcast();

        AITVToken implementation = new AITVToken();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(AgentcoinTvToken.initialize, (config.owner, config.recipient))
        );

        vm.stopBroadcast();

        console.log("AITVToken implementation deployed at %s", address(proxy));
        console.log("AITVToken proxy deployed at %s", address(proxy));

        return AITVToken(address(proxy));
    }
}
