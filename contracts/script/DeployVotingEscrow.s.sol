// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";

contract DeployVotingEscrow is Script {
    bytes32 constant KNOWN_GOOD_BYTECODE_HASH = 0x8a86daf75b8794b9b4dea4b92bf794ce2449e283ef3bad54bc67b063b3363e3c;

    function run() public {
        string memory artifactPath = "vyper-out/VotingEscrow.vy/VotingEscrow.vy.json";
        string memory json = vm.readFile(artifactPath);

        string memory bytecodePath = "['lib/curve-dao-contracts/contracts/VotingEscrow.vy'].bytecode";
        bytes memory bytecode = vm.parseJsonBytes(json, bytecodePath);

        _verifyArtifact(json, bytecode);

        address aitvTokenAddr = vm.envAddress("AITV_TOKEN_ADDRESS");
        vm.startBroadcast();
        address votingEscrowAddr = _deployVotingEscrow(aitvTokenAddr, bytecode);
        vm.stopBroadcast();

        console.log("VotingEscrow deployed at %s", votingEscrowAddr);
    }

    function _deployVotingEscrow(address _token, bytes memory bytecode) internal returns (address) {
        string memory name    = "veAITV";
        string memory symbol  = "veAITV";
        string memory version = "1";
        bytes memory ctorArgs = abi.encode(_token, name, symbol, version);

        bytes memory fullBytecode = abi.encodePacked(bytecode, ctorArgs);

        address deployed;
        assembly {
            deployed := create(0, add(fullBytecode, 0x20), mload(fullBytecode))
        }

        require(
            deployed != address(0),
            "VotingEscrow deployment failed, check the bytecode and artifact"
        );
        return deployed;
    }

    function _verifyArtifact(string memory json, bytes memory bytecode) internal pure {
        bytes32 actualHash = keccak256(bytecode);
        require(
            actualHash == KNOWN_GOOD_BYTECODE_HASH,
            "Bytecode hash mismatch, possible tampering"
        );

        string memory selectorPath = 
           "['lib/curve-dao-contracts/contracts/VotingEscrow.vy']"
           ".method_identifiers"
           "['__init__(address,string,string,string)']";

        bytes memory raw = vm.parseJsonBytes(json, selectorPath);
        bytes4 actualSel;
        assembly {
            actualSel := mload(add(raw, 32))
        }

        bytes4 expectedSel = bytes4(
            keccak256(bytes("__init__(address,string,string,string)"))
        );

        require(
            actualSel == expectedSel,
            "Constructor selector mismatch, artifact may be compromised"
        );
    }
}
