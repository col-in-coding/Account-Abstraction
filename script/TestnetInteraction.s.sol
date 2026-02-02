// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IStakeManager} from "@account-abstraction/contracts/interfaces/IStakeManager.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SimpleAccountFactory} from "src/SimpleAccountFactory.sol";
import {SimpleAccount} from "src/SimpleAccount.sol";
import {Simple7702Account} from "src/Simple7702Account.sol";
import {Paymaster} from "src/Paymaster.sol";


/**
 * @title TestnetInteraction
 * @notice Sepolia 测试网交互脚本
 * @dev 使用方式:
 *      1. Query Info:
 *      2. Fund Paymaster: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "fundPaymaster()" --rpc-url sepolia --broadcast
 *      3. Configure Paymaster: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "configurePaymaster()" --rpc-url sepolia --broadcast
 */
contract TestnetInteraction is Script {
    // Sepolia 测试网已部署的合约地址
    address constant ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
    address constant FACTORY = 0xD03fc9CA948ED3c8eD74809660269dF44149ba3B;
    address constant PAYMASTER = 0x68d4b6784f1143b91D2907071ec2C5279b44b7f0;
    address constant EIP7702_DELEGATE = 0xCeEe3852dde1bB6FdF0bB2d1402A6f6B84Ab49d2;

    address ownerEOA;
    address simpleAccountAddress;
    uint256 salt = 0;

    IEntryPoint entryPoint;
    SimpleAccountFactory factory;
    Paymaster paymaster;
    Simple7702Account eip7702delegate;
    Simple7702Account simple7702account;

    function setUp() public {
        entryPoint = IEntryPoint(ENTRY_POINT);
        factory = SimpleAccountFactory(FACTORY);
        paymaster = Paymaster(PAYMASTER);
        eip7702delegate = Simple7702Account(payable(EIP7702_DELEGATE));

        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        ownerEOA = vm.addr(userPrivateKey);
        simpleAccountAddress = factory.getAddress(ownerEOA, salt);
        simple7702account = Simple7702Account(payable(ownerEOA));
    }

    /**
     * @notice 查询所有部署的合约信息
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "queryInfo()" --rpc-url sepolia
     */
    function queryInfo() public view {
        console.log("=== Sepolia Testnet Contract Information ===");
        console.log("");
        console.log("EntryPoint: ", address(entryPoint));
        console.log("Factory: ", address(factory));
        console.log("Factory AccountImplementation: ", address(factory.accountImplementation()));
        console.log("Eip7702 Delegate: ", address(eip7702delegate));
        console.log("Paymaster: ", address(paymaster));

        // 账户信息
        console.log("");
        console.log("=== SimpleAccount Information ===");
        console.log("ownerEOA: ", ownerEOA);
        console.log("SimpleAccount Address: ", simpleAccountAddress);
        if (simpleAccountAddress.code.length == 0) {
            console.log("SimpleAccount is not deployed yet.");
        } else {
            console.log("SimpleAccount Nonce: ", entryPoint.getNonce(simpleAccountAddress, 0));
        }
        console.log("EntryPoint Deposit for SimpleAccount: ", entryPoint.balanceOf(simpleAccountAddress));

        // EIP7702 delegate 信息
        if (address(simple7702account).code.length == 0) {
            console.log("EIP7702 Delegate is not attached yet.");
        } else {
            console.log("");
            console.log("=== EIP7702 Delegate Information ===");
            console.log("EIP7702 EOA code: ", vm.toString(address(simple7702account).code));
            console.log("EIP7702 Delegate Address: ", address(simple7702account));
            // console.log("EIP7702 Delegate Owner: ", simple7702account.owner());
            console.log("EIP7702 Delegate EntryPoint: ", address(simple7702account.entryPoint()));
        }

        // Paymaster 信息
        console.log("");
        console.log("=== Paymaster Information ===");
        console.log("Paymaster: ", address(paymaster));
        console.log("Paymaster Owner: ", paymaster.owner());
        console.log("Paymaster Deposit: ", entryPoint.balanceOf(address(paymaster)));
        console.log("Max Gas Cost Per Op: ", paymaster.maxGasCostPerOp());
        console.log("Max Sponsorship Per Day: ", paymaster.maxSponsorshipPerDay());
        console.log("Sponsorship Enabled: ", paymaster.sponsorshipEnabled());
        console.log("Signature Required: ", paymaster.signatureRequired());
        console.log("Verifying Signer: ", paymaster.verifyingSigner());
    }

    /**
     * @notice 添加存款到EntryPoint账户
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "addDepositeToEntryPoint()" --rpc-url sepolia --broadcast
     */
    function addDepositeToEntryPoint() public {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        if (simpleAccountAddress.code.length == 0) {
            console.log("Account does not exist!");
        }

        vm.startBroadcast(userPrivateKey);
        entryPoint.depositTo{value: 0.1 ether}(simpleAccountAddress);
        vm.stopBroadcast();
        uint256 currentDeposit = entryPoint.balanceOf(simpleAccountAddress);
        console.log("Current Deposit for Account:", currentDeposit);
    }

    /**
     * @notice 为 SimpleAccount 创建 UserOperation（仅展示 initCode 和 nonce）
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "createUserOpForSimpleAccount()" --rpc-url sepolia
     */
    function createUserOpForSimpleAccount() public view {
        console.log("=== Create UserOperation for SimpleAccount ===");
        console.log("Sender: ", simpleAccountAddress);
        bytes memory initCode = "";
        if (simpleAccountAddress.code.length == 0) {
            console.log("Account does not exist!");
            initCode = _createSimpleAccountInitCode(ownerEOA, 0);
            console.log("InitCode: %s", vm.toString(initCode));
        }
        uint256 nonce = entryPoint.getNonce(simpleAccountAddress, 0);
        console.log("Current Nonce:", nonce);
    }

    /**
     * @notice 资助 Paymaster（添加 stake 和 deposit）
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "fundPaymaster()" --rpc-url sepolia --broadcast
     */
    function fundPaymaster() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Funding Paymaster ===");

        uint256 currentDeposit = entryPoint.balanceOf(address(paymaster));
        console.log("Current Deposit:", currentDeposit);

        vm.startBroadcast(deployerPrivateKey);

        // 添加 deposit（0.1 ETH）
        paymaster.deposit{value: 0.1 ether}();
        console.log("Added 0.1 ETH deposit");

        // 如果还没有 stake，添加 stake
        IStakeManager.DepositInfo memory info = entryPoint.getDepositInfo(address(paymaster));
        if (info.stake == 0) {
            paymaster.addStake{value: 0.1 ether}(86400); // 1 day
            console.log("Added 0.1 ETH stake with 1 day unlock delay");
        }

        vm.stopBroadcast();

        console.log("New Deposit:", entryPoint.balanceOf(address(paymaster)));
        console.log("Success!");
    }

    /**
     * @notice 配置 Paymaster
     */
    function configurePaymaster() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Configuring Paymaster ===");

        vm.startBroadcast(deployerPrivateKey);

        paymaster.setSignatureRequired(true);
        console.log("Signature requirement enabled");

        // 设置每笔操作最大gas花费（0.002 ETH）
        paymaster.setMaxGasCostPerOp(0.002 ether);
        console.log("Max gas cost per op set to 0.002 ETH");

        // 设置每天最大赞助次数
        paymaster.setMaxSponsorshipPerDay(10);
        console.log("Max sponsorship per day set to 10");

        vm.stopBroadcast();

        console.log("Success!");
    }

    // /**
    //  * @notice 测试赞助交易（简单的自转账）
    //  */
    // function createUserOpFor7702Account() public {

    //     // 确保账户存在
    //     address accountAddr = factory.getAddress(owner, 0);
    //     if (accountAddr.code.length == 0) {
    //         console.log("Creating account first...");
    //         vm.broadcast(deployerPrivateKey);
    //         factory.createAccount(owner, salt);
    //     }

    //     SimpleAccount account = SimpleAccount(payable(accountAddr));
    //     console.log("Account:", address(account));

    //     // 检查 Paymaster 余额
    //     uint256 paymasterDeposit = entryPoint.balanceOf(address(paymaster));
    //     console.log("Paymaster Deposit:", paymasterDeposit);
    //     require(paymasterDeposit > 0.01 ether, "Paymaster needs more deposit!");

    //     // 准备 UserOperation
    //     uint256 nonce = entryPoint.getNonce(address(account), 0);
    //     console.log("Current Nonce:", nonce);

    //     // 简单的调用数据（转账 0 ETH 到自己）
    //     bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", address(account), 0, "");

    //     // 构建 paymasterAndData（不需要签名用于查询 gas）
    //     uint48 validUntil = uint48(block.timestamp + 1 hours);
    //     uint48 validAfter = uint48(block.timestamp);

    //     bytes memory paymasterAndData = abi.encodePacked(
    //         address(paymaster),
    //         validUntil,
    //         validAfter,
    //         uint8(0), // userType
    //         bytes32(0) // extraData
    //     );

    //     // 构建 UserOperation
    //     PackedUserOperation memory userOp = PackedUserOperation({
    //         sender: address(account),
    //         nonce: nonce,
    //         initCode: "",
    //         callData: callData,
    //         accountGasLimits: bytes32(uint256(200000) << 128 | uint256(100000)),
    //         preVerificationGas: 50000,
    //         gasFees: bytes32(uint256(2 gwei) << 128 | uint256(2 gwei)),
    //         paymasterAndData: paymasterAndData,
    //         signature: ""
    //     });

    //     // 为 UserOperation 签名
    //     bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, userOpHash);
    //     userOp.signature = abi.encodePacked(r, s, v);

    //     console.log("UserOp Hash:", vm.toString(userOpHash));
    //     console.log("Signature Length:", userOp.signature.length);

    //     // 发送 UserOperation
    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = userOp;

    //     console.log("Submitting UserOperation to EntryPoint...");

    //     vm.broadcast(deployerPrivateKey);
    //     entryPoint.handleOps(ops, payable(owner));

    //     console.log("Transaction executed successfully!");
    //     console.log("New Nonce:", entryPoint.getNonce(address(account), 0));
    // }

    // /**
    //  * @notice 提取 Paymaster 资金
    //  */
    // function withdrawPaymaster(uint256 amount) public {
    //     uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    //     address owner = vm.addr(deployerPrivateKey);

    //     console.log("=== Withdrawing from Paymaster ===");
    //     console.log("Amount:", amount);

    //     uint256 currentBalance = entryPoint.balanceOf(address(paymaster));
    //     console.log("Current Balance:", currentBalance);
    //     require(currentBalance >= amount, "Insufficient balance!");

    //     vm.startBroadcast(deployerPrivateKey);

    //     paymaster.withdrawTo(payable(owner), amount);

    //     vm.stopBroadcast();

    //     console.log("Withdrawn to:", owner);
    //     console.log("New Balance:", entryPoint.balanceOf(address(paymaster)));
    // }

    // /**
    //  * @notice 真实场景：首次创建账户 + 执行交易（一个 UserOperation 完成）
    //  * @dev 这是标准的 EIP-4337 流程：
    //  *      1. 构造包含 initCode 和 paymasterAndData 的 UserOperation
    //  *      2. 用户签名
    //  *      3. 发送到 Bundler Mempool（这里直接发送到 EntryPoint 模拟）
    //  *      4. EntryPoint 执行：创建账户 + 验证 + 执行交易
    //  */
    // function createAccountAndExecuteWithPaymaster() public {
    //     uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    //     address owner = vm.addr(deployerPrivateKey);

    //     console.log("=== Create Account + Execute (Single UserOperation) ===");
    //     console.log("Owner:", owner);

    //     // 预计算账户地址
    //     address accountAddr = factory.getAddress(owner, 0);
    //     console.log("Account Address:", accountAddr);

    //     // 确认账户还未创建
    //     if (accountAddr.code.length > 0) {
    //         console.log("Account already exists! Use testSponsorship() instead.");
    //         return;
    //     }

    //     // 检查 Paymaster 余额
    //     uint256 paymasterDeposit = entryPoint.balanceOf(address(paymaster));
    //     console.log("Paymaster Deposit:", paymasterDeposit);
    //     require(paymasterDeposit > 0.01 ether, "Paymaster needs more deposit!");

    //     // 1. 构造 initCode（用于创建账户）
    //     bytes memory initCode = abi.encodePacked(
    //         address(factory),
    //         abi.encodeWithSignature("createAccount(address,uint256)", owner, 0)
    //     );
    //     console.log("InitCode length:", initCode.length);

    //     // 2. 构造 callData（首次交易：转账 0 ETH 到自己）
    //     bytes memory callData = abi.encodeWithSignature(
    //         "execute(address,uint256,bytes)",
    //         accountAddr, // 转给自己
    //         0,          // 0 ETH
    //         ""          // 无额外数据
    //     );

    //     // 3. 构造 paymasterAndData
    //     uint48 validUntil = uint48(block.timestamp + 1 hours);
    //     uint48 validAfter = uint48(block.timestamp);

    //     bytes memory paymasterAndData = abi.encodePacked(
    //         address(paymaster),
    //         validUntil,
    //         validAfter,
    //         uint8(0),      // userType
    //         bytes32(0)     // extraData
    //     );

    //     // 4. 构造 UserOperation（nonce 为 0，因为是新账户）
    //     PackedUserOperation memory userOp = PackedUserOperation({
    //         sender: accountAddr,  // 即将创建的账户地址
    //         nonce: 0,             // 新账户的第一个 nonce
    //         initCode: initCode,   // 包含创建账户的代码
    //         callData: callData,
    //         accountGasLimits: bytes32(uint256(300000) << 128 | uint256(150000)), // 创建账户需要更多 gas
    //         preVerificationGas: 100000,
    //         gasFees: bytes32(uint256(2 gwei) << 128 | uint256(2 gwei)),
    //         paymasterAndData: paymasterAndData,
    //         signature: ""  // 待签名
    //     });

    //     // 5. 为 UserOperation 签名
    //     bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, userOpHash);
    //     userOp.signature = abi.encodePacked(r, s, v);

    //     console.log("");
    //     console.log("=== UserOperation Details ===");
    //     console.log("UserOp Hash:", vm.toString(userOpHash));
    //     console.log("Sender (will be created):", userOp.sender);
    //     console.log("Nonce:", userOp.nonce);
    //     console.log("InitCode length:", userOp.initCode.length);
    //     console.log("CallData length:", userOp.callData.length);
    //     console.log("PaymasterAndData length:", userOp.paymasterAndData.length);
    //     console.log("Signature length:", userOp.signature.length);

    //     // 6. 提交到 EntryPoint（模拟 Bundler 的工作）
    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = userOp;

    //     console.log("");
    //     console.log("=== Submitting to EntryPoint ===");
    //     console.log("This simulates what a Bundler would do:");
    //     console.log("1. Create account (via initCode)");
    //     console.log("2. Validate paymaster");
    //     console.log("3. Validate account signature");
    //     console.log("4. Execute callData");
    //     console.log("5. Handle gas payment");

    //     vm.broadcast(deployerPrivateKey);
    //     entryPoint.handleOps(ops, payable(owner));

    //     console.log("");
    //     console.log("=== Success! ===");
    //     console.log("Account created:", accountAddr);
    //     console.log("Account deployed:", accountAddr.code.length > 0);
    //     console.log("Account nonce:", entryPoint.getNonce(accountAddr, 0));

    //     console.log("");
    //     console.log("Next steps:");
    //     console.log("- Use testSponsorship() for subsequent transactions");
    //     console.log("- Or submit UserOperations to a real Bundler");
    // }

    // /**
    //  * @notice 展示如何构造完整的 UserOperation JSON（用于提交给 Bundler）
    //  */
    // function showUserOpJson() public view {
    //     console.log("=== UserOperation JSON Format (for Bundler submission) ===");
    //     console.log("");
    //     console.log("{");
    //     console.log('  "sender": "0x...",           // 账户地址');
    //     console.log('  "nonce": "0x0",              // 十六进制 nonce');
    //     console.log('  "initCode": "0x...",         // 如果需要创建账户');
    //     console.log('  "callData": "0x...",         // 要执行的调用');
    //     console.log('  "accountGasLimits": "0x...", // packed: verificationGas | callGas');
    //     console.log('  "preVerificationGas": "0x...",');
    //     console.log('  "gasFees": "0x...",          // packed: maxPriorityFee | maxFeePerGas');
    //     console.log('  "paymasterAndData": "0x...", // paymaster address + data');
    //     console.log('  "signature": "0x..."         // 账户签名');
    //     console.log("}");
    //     console.log("");
    //     console.log("Submit via:");
    //     console.log('cast rpc eth_sendUserOperation \'["<UserOp>", "<EntryPoint>"]\' \\');
    //     console.log("  --rpc-url <BUNDLER_RPC>");
    // }

    function _createSimpleAccountInitCode(address owner, uint256 salt) internal view returns (bytes memory) {
        return abi.encodePacked(
            address(factory),
            abi.encodeWithSignature("createAccount(address,uint256)", owner, salt)
        );
    }
}