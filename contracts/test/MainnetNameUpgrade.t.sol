// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {AgentcoinTvToken} from "../src/AgentcoinTvToken.sol";
import {AITVToken} from "../src/AITVToken.sol";

contract MainnetNameUpgradeTest is Test {
    AgentcoinTvToken private token;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 22718178);
        token = AgentcoinTvToken(payable(vm.envAddress("AITV_TOKEN_ADDRESS")));
    }

    function test_canUpgradeNameAndSymbol() public {
        assertEq(token.name(), "Agentcoin TV Token");
        assertEq(token.symbol(), "AITV");
        
        // The current (and only) 3 holders of the token
        assertEq(token.balanceOf(0x8c3FA50473065f1D90f186cA8ba1Aa76Aee409Bb), 633_051_592.1986 * 1e18);
        assertEq(token.balanceOf(0x73cD8626b3cD47B009E68380720CFE6679A3Ec3D), 338_370_251.2044 * 1e18);
        assertEq(token.balanceOf(0x1bb64AF7FE05fc69c740609267d2AbE3e119Ef82), 28_578_156.597 * 1e18);

        vm.prank(makeAddr("deployer"));
        address newAddress = address(new AITVToken());

        vm.startPrank(token.owner());
        token.upgradeToAndCall(address(newAddress), "");
        assertEq(token.name(), "AITV");
        assertEq(token.symbol(), "AITV");
        vm.stopPrank();

        assertEq(token.balanceOf(0x8c3FA50473065f1D90f186cA8ba1Aa76Aee409Bb), 633_051_592.1986 * 1e18);
        assertEq(token.balanceOf(0x73cD8626b3cD47B009E68380720CFE6679A3Ec3D), 338_370_251.2044 * 1e18);
        assertEq(token.balanceOf(0x1bb64AF7FE05fc69c740609267d2AbE3e119Ef82), 28_578_156.597 * 1e18);
    }
}
