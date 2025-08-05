// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

contract DeployVotingEscrow is Script {
    function run() public {
        address aitvTokenAddr = vm.envAddress("AITV_TOKEN_ADDRESS");

        vm.startBroadcast();

        address votingEscrowAddr = _deployVotingEscrow(aitvTokenAddr);

        vm.stopBroadcast();

        console.log("VotingEscrow deployed at %s", address(votingEscrowAddr));
    }

    function _deployVotingEscrow(address _token) internal returns (address) {
        string memory name = "veAITV";
        string memory symbol = "veAITV";
        string memory version = "1";
        string memory artifactPath = "vyper-out/VotingEscrow.vy/VotingEscrow.vy.json";
        string memory json = vm.readFile(artifactPath);

        string memory bytecodePath = "['lib/curve-dao-contracts/contracts/VotingEscrow.vy'].bytecode";
        bytes memory bytecode = vm.parseJsonBytes(json, bytecodePath);
        bytes memory constructorArgs = abi.encode(_token, name, symbol, version);
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);

        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(fullBytecode, 0x20), mload(fullBytecode))
        }
        return deployedAddress;
    }
}
