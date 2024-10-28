// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AgentcoinToken} from "../src/AgentcoinToken.sol";
import {DeployAgentcoinTokenScript} from "../script/DeployAgentcoinToken.s.sol";
import {AgentcoinTokenV2Mock} from "./mocks/AgentcoinTokenV2Mock.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract AgentcoinTokenTest is Test {
    AgentcoinToken private token;
    address private owner = makeAddr("owner");
    address private recipient = makeAddr("recipient");

    function setUp() public {
        DeployAgentcoinTokenScript script = new DeployAgentcoinTokenScript();

        token = script.deploy(
            HelperConfig.AgentcoinTokenConfig({
                owner: owner,
                recipient: recipient
            })
        );
    }

    function test_SupplyShouldBe1Billion() public view {
        assertEq(token.totalSupply(), 1_000_000_000 * 10 ** 18);
    }

    function test_RecipientShouldBeHaveAllSupply() public view {
        assertEq(token.balanceOf(recipient), 1_000_000_000 * 10 ** 18);
    }

    function test_OwnerIsSetCorrectly() public view {
        assertEq(token.owner(), owner);
    }

    function test_OwnerCanUpgrade() public {
        vm.startPrank(owner);

        token.upgradeToAndCall(address(new AgentcoinToken()), "");

        vm.stopPrank();
    }

    function test_OwnerCannotUpgradeToNonContract() public {
        vm.startPrank(owner);

        vm.expectRevert();
        token.upgradeToAndCall(address(0), "");

        vm.expectRevert();
        token.upgradeToAndCall(makeAddr("nonContract"), "");

        vm.stopPrank();
    }

    function test_NonOwnerCannotUpgrade() public {
        address newImplementation = address(new AgentcoinToken());

        vm.startPrank(makeAddr("nonOwner"));
    
        vm.expectPartialRevert(OwnableUpgradeable.OwnableUnauthorizedAccount.selector);
        token.upgradeToAndCall(newImplementation, "");

        vm.stopPrank();
    }

    function test_NewImplementationWorks() public {
        AgentcoinTokenV2Mock newImplementation = new AgentcoinTokenV2Mock();

        vm.startPrank(owner);

        token.upgradeToAndCall(address(newImplementation), "");

        uint result = AgentcoinTokenV2Mock(address(token)).testFunction();

        assertEq(result, 1);

        console.logUint(token.totalSupply() / 10 ** 18);

        vm.stopPrank();
    }

    function test_CannotCallInitializerInImplementation() public {
        AgentcoinTokenV2Mock newImplementation = new AgentcoinTokenV2Mock();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        newImplementation.initialize(owner, recipient);
    }

    function test_CanRenounceOwnership() public {
        vm.startPrank(owner);

        token.renounceOwnership();

        address newImplementation = address(new AgentcoinToken());

        vm.expectPartialRevert(OwnableUpgradeable.OwnableUnauthorizedAccount.selector);
        token.upgradeToAndCall(newImplementation, "");

        vm.stopPrank();
    }

    function test_CanTransferOwnership() public {
        vm.startPrank(owner);

        token.transferOwnership(makeAddr("newOwner"));
       
        address newImplementation = address(new AgentcoinToken());

        vm.expectPartialRevert(OwnableUpgradeable.OwnableUnauthorizedAccount.selector);
        token.upgradeToAndCall(newImplementation, "");
       
        vm.stopPrank();

        vm.startPrank(makeAddr("newOwner"));

        token.upgradeToAndCall(newImplementation, "");

        vm.stopPrank();
    }

    function test_CanTransferTokens() public {
        vm.startPrank(recipient);

        token.transfer(makeAddr("new-recipient"), 100);

        assertEq(token.balanceOf(makeAddr("new-recipient")), 100);

        vm.stopPrank();
    }
}
