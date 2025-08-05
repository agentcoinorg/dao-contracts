// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AITVToken} from "../src/AITVToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AgentcoinTvToken} from "../src/AgentcoinTvToken.sol";
import {AITVTestToken} from "../test/mocks/AITVTestToken.sol";

contract DeployAITVTestToken is Script {
    function run() public {
        address ownerAddr = vm.envAddress("TEST_OWNER");
        address recipientAddr = ownerAddr;

        vm.startBroadcast();

        AITVTestToken implementation = new AITVTestToken();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(AgentcoinTvToken.initialize, (ownerAddr, recipientAddr))
        );

        vm.stopBroadcast();

        console.log("AITVToken Test implementation deployed at %s", address(implementation));
        console.log("AITVToken Test proxy deployed at %s", address(proxy));
    }
}
