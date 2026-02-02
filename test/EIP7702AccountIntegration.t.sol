// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {Simple7702Account} from "src/Simple7702Account.sol";
import {Paymaster} from "src/Paymaster.sol";

contract EIP7702AccountTest is Test {
    address public officialAdmin = makeAddr("official_admin");
    address public projectAdmin = makeAddr("project_admin");
    address private stranger = makeAddr("stranger");
    address public bundler = makeAddr("bundler");
    address private user;
    uint256 private userPrivateKey;
    address public paymasterSigner;
    uint256 public paymasterSignerPrivateKey;

    EntryPoint public entryPoint;
    Simple7702Account public eip7702delegate;
    Paymaster public paymaster;

    function setUp() public {
        (user, userPrivateKey) = makeAddrAndKey("user");
        (paymasterSigner, paymasterSignerPrivateKey) = makeAddrAndKey("paymaster_signer");

        vm.deal(projectAdmin, 20 ether); // 给 projectAdmin 充值，用于调用 addStake 和 deposit
        vm.deal(bundler, 100 ether); // 给 bundler 一些 ETH 用于支付交易费用

        vm.prank(officialAdmin);
        entryPoint = new EntryPoint();

        vm.startPrank(projectAdmin);
        eip7702delegate = new Simple7702Account(entryPoint);
        console.log("eip7702delegate address:", address(eip7702delegate));
        vm.deal(user, 10 ether);
        // 模拟 EIP-7702 授权
        vm.signAndAttachDelegation(address(eip7702delegate), userPrivateKey);

        paymaster = new Paymaster(entryPoint);
        // Stake: 质押资金，有锁定期，用于安全保证
        paymaster.addStake{value: 5 ether}(1 days);
        // Deposit: 存款资金，无锁定期，用于支付 gas 费用
        paymaster.deposit{value: 5 ether}();
        // Paymaster 设置签名者和启用签名验证
        paymaster.setSignatureRequired(true);
        paymaster.setVerifyingSigner(paymasterSigner);
        paymaster.setMaxGasCostPerOp(0.01 ether);
        vm.stopPrank();
    }

    function test_SucceedSendCallFromOwner() public {
        address recipient = makeAddr("recipient");
        uint256 initialBalance = recipient.balance;

        vm.prank(user);
        Simple7702Account(payable(user)).execute(recipient, 1 ether, "");
        assertEq(recipient.balance, initialBalance + 1 ether, "recipient should receive 1 ETH");
    }

    function test_FailCallFromAnotherAccount() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSignature("NotFromEntryPoint(address,address,address)", stranger, user, address(entryPoint))
        );
        Simple7702Account(payable(user)).execute(makeAddr("recipient"), 1 ether, "");
    }

    function test_SendCallFromEntryPoint() public {
        require(user.code.length > 0, "Delegate contract should be attached");

        uint256 transferAmount = 1 ether;
        address recipient = makeAddr("recipient2");
        uint256 initialBalance = recipient.balance;
        Simple7702Account account = Simple7702Account(payable(user));

        // 充值 EntryPoint 以支付 gas 费用
        vm.prank(user);
        entryPoint.depositTo{value: 0.1 ether}(user);
        uint256 initEntryPointBalance = entryPoint.balanceOf(user);
        console.log("EntryPoint balance for user:", initEntryPointBalance);

        uint256 nonce = entryPoint.getNonce(user, 0);
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", recipient, transferAmount, "");

        // 构建一个简单的转账 PackedUserOperation
        PackedUserOperation memory userOp = _buildUserOp();
        userOp.sender = user;
        userOp.nonce = nonce;
        userOp.callData = callData;
        userOp = _signUserOp(userOp);
        _simulateBundlerSubmission(userOp);

        assertEq(recipient.balance, initialBalance + transferAmount, "Transfer via EntryPoint should succeed");

        nonce = entryPoint.getNonce(user, 0);
        assertEq(nonce, 1, "Nonce should increment after operation");

        uint256 entryPointBalance = entryPoint.balanceOf(user);
        assertLe(entryPointBalance, initEntryPointBalance, "EntryPoint balance should decrease after paying gas");
    }

    function test_PaymasterSponsorship() public {
        require(user.code.length > 0, "Delegate contract should be attached");

        uint256 transferAmount = 1 ether;
        address recipient = makeAddr("recipient2");
        uint256 initialBalance = recipient.balance;
        Simple7702Account account = Simple7702Account(payable(user));

        // 充值 EntryPoint，测试 Paymaster 支付 gas 费用
        vm.prank(user);
        entryPoint.depositTo{value: 0.1 ether}(user);
        uint256 initEntryPointBalance = entryPoint.balanceOf(user);

        uint256 nonce = entryPoint.getNonce(user, 0);
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", recipient, transferAmount, "");

        bytes memory paymasterData = _paymasterSignatureData(nonce);
        // 按照 EntryPoint 规范，补充 16字节 verificationGasLimit 和 16字节 postOpGasLimit
        uint128 paymasterVerificationGasLimit = 100000;
        uint128 paymasterPostOpGasLimit = 100000;
        // paymasterAndData = paymaster(20) || verificationGasLimit(16) || postOpGasLimit(16) || paymasterData
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster), // 20 bytes: paymaster address
            paymasterVerificationGasLimit, // 16 bytes
            paymasterPostOpGasLimit, // 16 bytes
            paymasterData // paymasterData
        );

        // 构建一个简单的转账 PackedUserOperation
        PackedUserOperation memory userOp = _buildUserOp();
        userOp.sender = user;
        userOp.nonce = nonce;
        userOp.callData = callData;
        userOp.paymasterAndData = paymasterAndData;
        userOp = _signUserOp(userOp);
        _simulateBundlerSubmission(userOp);

        assertEq(recipient.balance, initialBalance + transferAmount, "Transfer via EntryPoint should succeed");

        nonce = entryPoint.getNonce(user, 0);
        assertEq(nonce, 1, "Nonce should increment after operation");

        uint256 entryPointBalance = entryPoint.balanceOf(user);
        assertEq(entryPointBalance, initEntryPointBalance, "EntryPoint balance should remain the same as Paymaster pays gas");
    }

    function _buildUserOp() internal view returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: _packGasLimits(200000, 100000), // verificationGasLimit, callGasLimit
            preVerificationGas: 50000,
            gasFees: _packGasFees(2e9, 1e9), // maxFeePerGas, maxPriorityFeePerGas
            paymasterAndData: "",
            signature: "" // 稍后填充
        });
    }

    function _signUserOp(PackedUserOperation memory userOp) internal view returns (PackedUserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _simulateBundlerSubmission(PackedUserOperation memory userOp) internal {
        // 模拟 Bundler 调用 EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // 使用 startPrank 来确保 tx.origin 和 msg.sender 都是 bundler (EOA)
        vm.startPrank(bundler, bundler);
        entryPoint.handleOps(ops, payable(bundler));
        vm.stopPrank();
    }

    function _paymasterSignatureData(uint256 nonce) internal view returns (bytes memory paymasterData) {
        uint48 validAfter = 0;
        uint48 validUntil = uint48(block.timestamp + 1 hours); // 1小时有效期

        // 构造 paymasterData：validUntil(6) + validAfter(6) + userType(1) + extraData(32)
        bytes memory payload = abi.encodePacked(
            validUntil, // 6 bytes: 有效期结束时间
            validAfter, // 6 bytes: 有效期开始时间
            uint8(1), // 1 byte: 用户类型 (1=普通用户, 2=VIP用户)
            keccak256("user_identifier") // 32 bytes: 用户身份标识哈希
        );

        bytes32 dataHash = keccak256(
            abi.encodePacked(
                address(entryPoint), // EntryPoint 地址
                address(paymaster), // Paymaster 地址
                user, // 用户账户地址
                nonce,
                validUntil,
                validAfter,
                payload
            )
        );

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(paymasterSignerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        paymasterData = abi.encodePacked(payload, signature);
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
