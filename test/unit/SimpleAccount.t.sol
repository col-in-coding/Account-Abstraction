// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UnitTestHelper} from "./UnitTestHelper.sol";
import {SimpleAccount} from "../../src/SimpleAccount.sol";

contract SimpleAccountTest is UnitTestHelper {
    function setUp() public override {
        super.setUp();

        vm.prank(senderCreatorAddr);
        uint256 salt = 0;
        account = SimpleAccount(payable(factory.createAccount(owner, salt)));
    }

    function testInitialization() public {
        assertEq(account.owner(), owner);
        assertEq(address(account.entryPoint()), address(entryPoint));
    }

    function testTransferETH() public {
        vm.deal(owner, 10 ether);
        uint256 accountBalance = address(account).balance;

        // 转入
        vm.prank(owner);
        (bool success,) = address(account).call{value: 2 ether}("");
        assertTrue(success, "Transfer should succeed");
        assertEq(address(account).balance, accountBalance + 2 ether);

        // 转出 - 通过 owner 调用
        accountBalance = address(account).balance;
        vm.prank(owner);
        account.execute(alice, 1 ether, "");
        assertEq(address(account).balance, 1 ether);
        assertEq(alice.balance, 1 ether);

        // 转出 - 通过 EntryPoint 调用
        accountBalance = address(account).balance;
        vm.prank(address(entryPoint));
        account.execute(alice, 1 ether, "");
        assertEq(address(account).balance, 0 ether);
    }

    function testStrangerCannotExecute() public {
        // 给账户充值
        vm.deal(address(account), 2 ether);

        // 陌生人不能调用
        vm.prank(stranger);
        vm.expectRevert();
        account.execute(alice, 1 ether, "");
    }
}
