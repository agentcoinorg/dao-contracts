// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

abstract contract Constants {
    uint256 public constant CHAIN_ID_ETHEREUM = 1;
    uint256 public constant CHAIN_ID_SEPOLIA = 11155111;
}

contract HelperConfig is Constants, Script {
    struct AgentcoinTvTokenConfig {
        address owner;
        address recipient;
    }

    function getConfig() public view returns (AgentcoinTvTokenConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) private view returns (AgentcoinTvTokenConfig memory) {
        if (chainId == CHAIN_ID_ETHEREUM) {
            return getEthereumConfig();
        } else if (chainId == CHAIN_ID_SEPOLIA) {
            return getSepoliaConfig();
        } else {
            revert("Invalid chain id");
        }
    }

    function getEthereumConfig() private view returns (AgentcoinTvTokenConfig memory) {
        return AgentcoinTvTokenConfig({
            owner: vm.envAddress("ETHEREUM_OWNER"),
            recipient: vm.envAddress("ETHEREUM_RECIPIENT")
        });
    }

    function getSepoliaConfig() private view returns (AgentcoinTvTokenConfig memory) {
        return
            AgentcoinTvTokenConfig({owner: vm.envAddress("SEPOLIA_OWNER"), recipient: vm.envAddress("SEPOLIA_RECIPIENT")});
    }
}
