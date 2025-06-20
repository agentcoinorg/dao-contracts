// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {AITVToken} from "../src/AITVToken.sol";

contract UpgradeAITVTokenScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        AITVToken implementation = new AITVToken();
        vm.stopBroadcast();

        console.log("AITVToken implementation deployed at: %s", address(implementation));
    }
}
