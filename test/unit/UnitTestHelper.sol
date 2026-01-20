// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MockEntryPoint, MockSenderCreator} from "../mocks/MockEntryPoint.sol";
import {SimpleAccount} from "../../src/SimpleAccount.sol";
import {SimpleAccountFactory} from "../../src/SimpleAccountFactory.sol";

contract UnitTestHelper is Test {
    MockEntryPoint public entryPoint;
    SimpleAccountFactory public factory;
    SimpleAccount public account;

    address public senderCreatorAddr;

    address public officialAdmin = makeAddr("official_admin");
    address public projectAdmin = makeAddr("project_admin");
    address public owner = makeAddr("owner");
    address public stranger = makeAddr("stranger");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public virtual {
        vm.prank(officialAdmin);
        entryPoint = new MockEntryPoint();
        senderCreatorAddr = address(entryPoint.senderCreator());
        vm.prank(projectAdmin);
        factory = new SimpleAccountFactory(IEntryPoint(address(entryPoint)));
    }

}