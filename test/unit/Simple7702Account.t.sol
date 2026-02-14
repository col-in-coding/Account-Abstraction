// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {BaseAccount} from "lib/account-abstraction/contracts/core/BaseAccount.sol";
import {Simple7702Account} from "src/Simple7702Account.sol";
import {UnitTestHelper} from "./UnitTestHelper.sol";

contract Simple7702AccountTest is UnitTestHelper {
    Simple7702Account public eip7702delegate;

    function setUp() public virtual override {
        super.setUp();

        eip7702delegate = new Simple7702Account(IEntryPoint(address(entryPoint)));
        vm.signAndAttachDelegation(address(eip7702delegate), ownerPrivateKey);
    }

    function testInitialize() public {
        assertEq(address(eip7702delegate.entryPoint()), address(entryPoint));
        bytes memory expectedCode = abi.encodePacked(hex"ef0100", address(eip7702delegate));
        assertEq(owner.code, expectedCode);
    }

    function testExecute() public {
        vm.deal(owner, 10 ether);
        uint256 initialBalance = alice.balance;

        // 通过 owner 调用
        vm.prank(owner);
        Simple7702Account(payable(owner)).execute(alice, 1 ether, "");
        assertEq(alice.balance, initialBalance + 1 ether);
        assertEq(owner.balance, 9 ether);
    }

    function testBatchExecute() public {
        vm.deal(owner, 10 ether);
        uint256 initialBalanceAlice = alice.balance;
        uint256 initialBalanceBob = bob.balance;

        // 通过 owner 调用批量执行
        BaseAccount.Call[] memory calls = new BaseAccount.Call[](2);
        calls[0] = BaseAccount.Call(alice, 1 ether, "");
        calls[1] = BaseAccount.Call(bob, 2 ether, "");
        vm.prank(owner);
        Simple7702Account(payable(owner)).executeBatch(calls);

        assertEq(alice.balance, initialBalanceAlice + 1 ether);
        assertEq(bob.balance, initialBalanceBob + 2 ether);
        assertEq(owner.balance, 7 ether);
    }
}
