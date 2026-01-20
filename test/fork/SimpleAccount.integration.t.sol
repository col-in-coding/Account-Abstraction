// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SimpleAccount} from "../../src/SimpleAccount.sol";
import {SimpleAccountFactory} from "../../src/SimpleAccountFactory.sol";

contract SimpleAccountIntegrationTest is Test {
    EntryPoint public entryPoint;

    SimpleAccountFactory public factory;
    SimpleAccount public account;

    address public senderCreatorAddr;

    address public officialAdmin = makeAddr("official_admin");
    address public projectAdmin = makeAddr("project_admin");

    address public bundler = makeAddr("bundler");
    address public user;
    uint256 public userSK;

    address public stranger = makeAddr("stranger");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(officialAdmin);
        entryPoint = new EntryPoint();
        senderCreatorAddr = address(entryPoint.senderCreator());

        vm.prank(projectAdmin);
        factory = new SimpleAccountFactory(IEntryPoint(address(entryPoint)));

        (user, userSK) = makeAddrAndKey("user");

        // 给 bundler 一些 ETH 用于支付交易费用
        vm.deal(bundler, 100 ether);
    }

    function testFullUserOperationFlow() public {
        // 1. 创建用户账户
        address accountAddr = _createUserAccount();
        account = SimpleAccount(payable(accountAddr));

        // 2. 给账户充值（用于支付 gas）
        vm.deal(address(account), 10 ether);
        account.addDeposit{value: 5 ether}();

        // 3. 构建 UserOperation
        PackedUserOperation memory userOp = _buildUserOp();

        // 4. 签名 UserOperation
        userOp = _signUserOp(userOp);

        // 5. 模拟 Bundler 提交 UserOperation
        _simulateBundlerSubmission(userOp);

        // 6. 验证执行结果
        _verifyExecutionResult();
    }

    function _createUserAccount() internal returns (address) {
        // 通过 senderCreator 创建账户
        vm.prank(senderCreatorAddr);
        return factory.createAccount(user, 0);
    }

    function _buildUserOp() internal view returns (PackedUserOperation memory) {
        // 构建一个简单的转账 UserOperation
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", alice, 1 ether, "");

        return PackedUserOperation({
            sender: address(account),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: _packGasLimits(200000, 100000), // verificationGasLimit, callGasLimit
            preVerificationGas: 50000,
            gasFees: _packGasFees(2e9, 1e9), // maxFeePerGas, maxPriorityFeePerGas
            paymasterAndData: "",
            signature: "" // 稍后填充
        });
    }

    function _signUserOp(PackedUserOperation memory userOp) internal view returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userSK, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _simulateBundlerSubmission(PackedUserOperation memory userOp) internal {
        // 模拟 Bundler 调用 EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        uint256 bundlerBalanceBefore = bundler.balance;

        // 使用 startPrank 来确保 tx.origin 和 msg.sender 都是 bundler (EOA)
        vm.startPrank(bundler, bundler);
        entryPoint.handleOps(ops, payable(bundler));
        vm.stopPrank();

        uint256 bundlerBalanceAfter = bundler.balance;
        console.log("Bundler earned:", bundlerBalanceAfter - bundlerBalanceBefore);
    }

    function _verifyExecutionResult() internal {
        // 验证转账是否成功
        assertEq(alice.balance, 1 ether, "Alice should have received 1 ether");

        // 验证账户余额减少
        assertTrue(address(account).balance < 10 ether, "Account balance should decrease");

        // 验证 bundler 获得了收益
        assertTrue(bundler.balance > 100 ether, "Bundler should earn fees");
    }

    // 辅助函数：打包 gas 限制
    function _packGasLimits(uint128 verificationGasLimit, uint128 callGasLimit) internal pure returns (bytes32) {
        return bytes32(uint256(verificationGasLimit) << 128 | uint256(callGasLimit));
    }

    // 辅助函数：打包 gas 费用
    function _packGasFees(uint128 maxFeePerGas, uint128 maxPriorityFeePerGas) internal pure returns (bytes32) {
        return bytes32(uint256(maxFeePerGas) << 128 | uint256(maxPriorityFeePerGas));
    }
}
