// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {SimpleAccount} from "../../src/SimpleAccount.sol";
import {SimpleAccountFactory} from "../../src/SimpleAccountFactory.sol";
import {SimplePaymaster} from "../../src/SimplePaymaster.sol";

contract SimpleAccountIntegrationTest is Test {
    EntryPoint public entryPoint;

    SimpleAccountFactory public factory;
    SimpleAccount public account;
    SimplePaymaster public paymaster;

    address public senderCreatorAddr;

    address public officialAdmin = makeAddr("official_admin");
    address public projectAdmin = makeAddr("project_admin");
    address public paymasterSigner;
    uint256 public paymasterSignerSK;

    address public bundler = makeAddr("bundler");
    address public user;
    uint256 public userSK;
    uint256 public salt = 0;

    address public stranger = makeAddr("stranger");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        vm.prank(officialAdmin);
        entryPoint = new EntryPoint();
        // senderCreatorAddr = address(entryPoint.senderCreator()); // v0.7: not available

        (user, userSK) = makeAddrAndKey("user");
        (paymasterSigner, paymasterSignerSK) = makeAddrAndKey("paymaster_signer");

        vm.deal(projectAdmin, 20 ether); // 给 projectAdmin 充值，用于调用 addStake 和 deposit
        vm.deal(bundler, 100 ether); // 给 bundler 一些 ETH 用于支付交易费用

        vm.startPrank(projectAdmin);
        factory = new SimpleAccountFactory(address(entryPoint));
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
    }

    function testInitCode() public {
        // 1. 预测账户地址
        address predictedAccountAddr = factory.getAddress(user, salt);

        // 2. 这里因为合约账户还不存在，所以需要第三方充值
        vm.deal(user, 100 ether);
        vm.prank(user);
        entryPoint.depositTo{value: 5 ether}(predictedAccountAddr);

        // 3. 构建 UserOperation
        UserOperation memory userOp = _buildUserOp();
        bytes memory initCode =
            abi.encodePacked(address(factory), abi.encodeCall(SimpleAccountFactory.createAccount, (user, salt)));
        userOp.initCode = initCode;
        userOp.sender = predictedAccountAddr;
        userOp.nonce = 0;

        // 4. 签名 UserOperation
        userOp = _signUserOp(userOp);

        // 5. 模拟 Bundler 提交 UserOperation
        _simulateBundlerSubmission(userOp);

        // 6. 验证执行结果
        assertTrue(predictedAccountAddr.code.length > 0, "Account should be created");
    }

    function testTransferETHFullFlow() public {
        // 1. 创建用户账户(假设已经存在)
        _createUserAccount();

        // 2. 给账户充值（用于支付 gas）
        account.addDeposit{value: 5 ether}();
        uint256 initBalance = address(account).balance;

        // 3. 构建一个简单的转账 UserOperation
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        userOp.nonce = nonce;
        uint256 transferAmount = 1 ether;
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", alice, transferAmount, "");
        userOp.callData = callData;

        // 4. 签名 UserOperation
        userOp = _signUserOp(userOp);

        // 5. 模拟 Bundler 提交 UserOperation
        _simulateBundlerSubmission(userOp);

        // 6. 验证执行结果
        assertEq(alice.balance, transferAmount, "Alice should have received 1 ether");
        assertTrue(address(account).balance < initBalance, "Account balance should decrease");
        assertTrue(bundler.balance > 100 ether, "Bundler should earn fees");
    }

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    function testBatchTransferETH() public {
        // 1. 创建用户账户(假设已经存在)
        _createUserAccount();

        // 2. 给账户充值（用于支付 gas）
        account.addDeposit{value: 5 ether}();
        uint256 initBalance = address(account).balance;

        // 3. 构建一个批量转账 UserOperation
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        userOp.nonce = nonce;

        // 构建批量调用数据
        address[] memory targets = new address[](2);
        targets[0] = alice;
        targets[1] = bob;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        bytes[] memory datas = new bytes[](2);
        datas[0] = "";
        datas[1] = "";

        userOp.callData = abi.encodeWithSignature("executeBatch(address[],uint256[],bytes[])", targets, values, datas);

        // 4. 签名 UserOperation
        userOp = _signUserOp(userOp);

        // 5. 模拟 Bundler 提交 UserOperation
        _simulateBundlerSubmission(userOp);

        // 6. 验证执行结果
        assertEq(alice.balance, 1 ether, "Alice should have received 1 ether");
        assertEq(bob.balance, 2 ether, "Bob should have received 2 ether");
        assertTrue(address(account).balance < initBalance, "Account balance should decrease");
        assertTrue(bundler.balance > 100 ether, "Bundler should earn fees");
    }

    function testUnauthorizedUserOpRevert() public {
        // 1. 创建用户账户(假设已经存在)
        _createUserAccount();

        // 2. 构建一个 UserOperation，但使用陌生人的签名
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        userOp.nonce = nonce;
        uint256 transferAmount = 1 ether;
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", bob, transferAmount, "");
        userOp.callData = callData;

        // 使用陌生人的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(stranger)), entryPoint.getUserOpHash(userOp));
        userOp.signature = abi.encodePacked(r, s, v);

        // 3. 模拟 Bundler 提交 UserOperation，预期应当 revert
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        vm.startPrank(bundler, bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));
        vm.stopPrank();
    }

    function testPaymasterSponsorshipFlow() public {
        // 1. 创建用户账户(假设已经存在)
        _createUserAccount();

        // 2. 构造UserOperation，使用 SimplePaymaster 作为 paymaster
        UserOperation memory userOp = _buildUserOp();
        uint256 nonce = account.nonce();
        userOp.nonce = nonce;
        uint256 transferAmount = 1 ether;
        bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", alice, transferAmount, "");
        userOp.callData = callData;

        // v0.7 Format: paymaster(20) || paymasterData (no gas limits)
        bytes memory paymasterData = _paymasterSignatureData(nonce);
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster), // 20 bytes: paymaster address
            paymasterData // paymasterData (no gas limits in v0.7)
        );
        userOp.paymasterAndData = paymasterAndData;

        // 3. 签名 UserOperation
        userOp = _signUserOp(userOp);
        // 4. 模拟 Bundler 提交 UserOperation
        _simulateBundlerSubmission(userOp);
        // 5. 验证执行结果
        assertEq(alice.balance, transferAmount, "Alice should have received 1 ether");
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
                address(account), // 用户账户地址
                nonce,
                validUntil,
                validAfter,
                payload
            )
        );

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(paymasterSignerSK, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        paymasterData = abi.encodePacked(payload, signature);
    }

    function _createUserAccount() internal returns (address accountAddr) {
        // 通过 senderCreator 创建账户
        vm.prank(senderCreatorAddr);
        accountAddr = factory.createAccount(user, salt);
        account = SimpleAccount(payable(accountAddr));
        vm.deal(address(account), 10 ether);
    }

    function _buildUserOp() internal view returns (UserOperation memory) {
        return UserOperation({
            sender: address(account),
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userSK, userOpHash);
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _simulateBundlerSubmission(UserOperation memory userOp) internal {
        // 模拟 Bundler 调用 EntryPoint
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        // uint256 bundlerBalanceBefore = bundler.balance;
        // uint256 accountDepositBefore = account.getDeposit();
        // uint256 accountBalanceBefore = address(account).balance;

        // console.log("=== Before Execution ===");
        // console.log("Bundler balance:", bundlerBalanceBefore);
        // console.log("Account deposit in EntryPoint:", accountDepositBefore);
        // console.log("Account ETH balance:", accountBalanceBefore);

        // 使用 startPrank 来确保 tx.origin 和 msg.sender 都是 bundler (EOA)
        vm.startPrank(bundler, bundler);
        entryPoint.handleOps(ops, payable(bundler));
        vm.stopPrank();

        // uint256 bundlerBalanceAfter = bundler.balance;
        // uint256 accountDepositAfter = account.getDeposit();
        // uint256 accountBalanceAfter = address(account).balance;

        // console.log("=== After Execution ===");
        // console.log("Bundler balance:", bundlerBalanceAfter);
        // console.log("Account deposit in EntryPoint:", accountDepositAfter);
        // console.log("Account ETH balance:", accountBalanceAfter);

        // console.log("=== Changes ===");
        // console.log("Bundler earned:", bundlerBalanceAfter - bundlerBalanceBefore);
        // console.log("Account deposit used:", accountDepositBefore - accountDepositAfter);
        // console.log("Account ETH used:", accountBalanceBefore - accountBalanceAfter);
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
