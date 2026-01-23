// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {SimpleEIP7702Account} from "../../src/SimpleEIP7702Account.sol";
import {EntryPointViaNonceManager as EntryPoint} from "../../src/EntryPointViaNonceManager.sol";
import {IEntryPoint} from "../../src/interfaces/IEntryPoint.sol";
import {SimplePaymaster} from "../../src/SimplePaymaster.sol";

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
    SimpleEIP7702Account public eip7702delegate;
    SimplePaymaster public paymaster;

    function setUp() public {
        (user, userPrivateKey) = makeAddrAndKey("user");
        (paymasterSigner, paymasterSignerPrivateKey) = makeAddrAndKey("paymaster_signer");

        vm.deal(projectAdmin, 20 ether); // 给 projectAdmin 充值，用于调用 addStake 和 deposit
        vm.deal(bundler, 100 ether); // 给 bundler 一些 ETH 用于支付交易费用

        vm.prank(officialAdmin);
        entryPoint = new EntryPoint();

        vm.startPrank(projectAdmin);
        eip7702delegate = new SimpleEIP7702Account(IEntryPoint(address(entryPoint)));
        console.log("eip7702delegate address:", address(eip7702delegate));
        paymaster = new SimplePaymaster(address(entryPoint));

        // Stake: 质押资金，有锁定期，用于安全保证
        paymaster.addStake{value: 5 ether}(1 days);
        // Deposit: 存款资金，无锁定期，用于支付 gas 费用
        paymaster.deposit{value: 5 ether}();
        // Paymaster 设置签名者和启用签名验证
        paymaster.setVerifyingSigner(paymasterSigner);
        paymaster.setSignatureRequired(true);
        paymaster.setMaxGasCostPerOp(0.01 ether); // 增加 gas 限制
        vm.stopPrank();

        vm.deal(user, 10 ether);
        // 模拟 EIP-7702 授权
        vm.signAndAttachDelegation(address(eip7702delegate), userPrivateKey);
    }

    function test_SetUp_EIP7702Authorization() public view {
        assertTrue(user.code.length > 0, "user should have code after EIP-7702 authorization");
        assertEq(user.balance, 10 ether, "user should have 10 ETH");

        bytes memory expectedCode = abi.encodePacked(hex"ef0100", address(eip7702delegate));
        assertEq(user.code, expectedCode, "user code should be EIP-7702 delegation pointer");

        console.log("EIP-7702 setup successful!");
    }

    function test_FailCallFromAnotherAccount() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSignature("NotFromEntryPoint(address,address,address)", stranger, user, address(entryPoint))
        );
        SimpleEIP7702Account(payable(user)).execute(makeAddr("recipient"), 1 ether, "");
    }

    function test_SucceedSendCallFromOwner() public {
        address recipient = makeAddr("recipient");
        uint256 initialBalance = recipient.balance;

        vm.prank(user);
        SimpleEIP7702Account(payable(user)).execute(recipient, 1 ether, "");
        assertEq(recipient.balance, initialBalance + 1 ether, "recipient should receive 1 ETH");
    }

    function test_SucceedSendCallFromEntryPoint() public {
        uint256 transferAmount = 1 ether;
        address recipient = makeAddr("recipient2");
        uint256 initialBalance = recipient.balance;
        SimpleEIP7702Account account = SimpleEIP7702Account(payable(user));

        // 充值 EntryPoint 以支付 gas 费用
        vm.prank(user);
        account.addDeposit{value: transferAmount}();

        // 构建一个简单的转账 UserOperation
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", recipient, transferAmount, "");
        userOp.nonce = nonce;
        userOp.callData = callData;

        userOp = _signUserOp(userOp);
        _simulateBundlerSubmission(userOp);

        assertEq(recipient.balance, initialBalance + transferAmount, "Transfer via EntryPoint should succeed");
    }

    function test_PaymasterSponsorship() public {
        uint256 transferAmount = 1 ether;
        address recipient = makeAddr("recipient2");
        uint256 initialBalance = recipient.balance;
        SimpleEIP7702Account account = SimpleEIP7702Account(payable(user));

        // 构建一个简单的转账 UserOperation
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", recipient, transferAmount, "");
        userOp.nonce = nonce;
        userOp.callData = callData;

        bytes memory paymasterData = _paymasterSignatureData(nonce);
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster), // 20 bytes: paymaster address
            paymasterData // paymasterData
        );
        userOp.paymasterAndData = paymasterAndData;

        userOp = _signUserOp(userOp);
        _simulateBundlerSubmission(userOp);

        assertEq(recipient.balance, initialBalance + transferAmount, "Transfer via EntryPoint should succeed");
    }

    function _buildUserOp() internal view returns (UserOperation memory) {
        return UserOperation({
            sender: user,
            nonce: 0,
            initCode: "",
            callData: "",
            callGasLimit: 100000,
            verificationGasLimit: 200000,
            preVerificationGas: 50000,
            maxFeePerGas: 2e9,
            maxPriorityFeePerGas: 1e9,
            paymasterAndData: "",
            signature: ""
        });
    }

    function _signUserOp(UserOperation memory userOp) internal view returns (UserOperation memory) {
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _simulateBundlerSubmission(UserOperation memory userOp) internal {
        // 模拟 Bundler 调用 EntryPoint
        UserOperation[] memory ops = new UserOperation[](1);
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
}
