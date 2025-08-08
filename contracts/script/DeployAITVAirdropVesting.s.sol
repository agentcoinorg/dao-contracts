// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AITVToken} from "../src/AITVToken.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {AITVAirdropVesting} from "../src/AITVAirdropVesting.sol";

contract DeployAITVAirdropVesting is Script {
    function setUp() public {}

    function run() public {
        address ownerAddr = vm.envAddress("TEST_OWNER");
        address aitvTokenAddr = vm.envAddress("AITV_TOKEN_ADDRESS");
        address votingEscrowAddr = vm.envAddress("VOTING_ESCROW_ADDRESS");
        address treasuryAddr = vm.envAddress("TREASURY_ADDRESS");

        vm.startBroadcast();

        AITVAirdropVesting vesting = new AITVAirdropVesting(ownerAddr, aitvTokenAddr, treasuryAddr, votingEscrowAddr);

        vm.stopBroadcast();

        console.log("AITVAirdropVesting deployed at %s", address(vesting));
    }
}
