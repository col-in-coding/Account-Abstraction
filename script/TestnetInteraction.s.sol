// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IStakeManager} from "@account-abstraction/contracts/interfaces/IStakeManager.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {SimpleAccountFactory} from "../src/SimpleAccountFactory.sol";
import {SimpleAccount} from "../src/SimpleAccount.sol";
import {SimplePaymaster} from "../src/SimplePaymaster.sol";

/**
 * @title TestnetInteraction
 * @notice Sepolia 测试网交互脚本
 * @dev 使用方式:
 *      1. Query Info: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "queryInfo()" --rpc-url sepolia
 *      2. Fund Paymaster: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "fundPaymaster()" --rpc-url sepolia --broadcast
 *      3. Configure Paymaster: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "configurePaymaster()" --rpc-url sepolia --broadcast
 *      4. Generate UserOp for Bundler: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "generateUserOpForBundler()" --rpc-url sepolia
 *      5. Check Account Exists: forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "checkAccountExists(address)" --rpc-url sepolia
 */
contract TestnetInteraction is Script {
    // Sepolia 测试网已部署的合约地址
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address constant FACTORY = 0xa8603c9e89E7DD136aad213A5f68C180B175903E;
    address constant PAYMASTER = 0xc7C1d16D484f9719CaD5e677daA3c60790d5DCB5;

    uint256 constant SALT = uint256(keccak256(abi.encodePacked("unique_salt_for_account")));

    // 用于测试 initCode 的新 salt（确保账户不存在）
    uint256 constant TEST_SALT = uint256(keccak256(abi.encodePacked("test_initcode_salt_v2")));

    IEntryPoint entryPoint;
    SimpleAccountFactory factory;
    SimplePaymaster paymaster;

    function setUp() public {
        entryPoint = IEntryPoint(ENTRY_POINT);
        factory = SimpleAccountFactory(FACTORY);
        paymaster = SimplePaymaster(PAYMASTER);
    }

    /**
     * @notice 查询所有部署的合约信息
     */
    function queryInfo() public view {
        console.log("=== Sepolia Testnet Contract Information ===");
        console.log("");

        // EntryPoint 信息
        console.log("EntryPoint:", address(entryPoint));

        // Factory 信息
        console.log("Factory:", address(factory));
        console.log("Factory AccountImplementation:", factory.accountImplementation());

        // Paymaster 信息
        console.log("");
        console.log("=== Paymaster Information ===");
        console.log("Paymaster:", address(paymaster));
        console.log("Paymaster Owner:", paymaster.owner());
        console.log("Paymaster Deposit:", entryPoint.balanceOf(address(paymaster)));
        console.log("Max Gas Cost Per Op:", paymaster.maxGasCostPerOp());
        console.log("Max Sponsorship Per Day:", paymaster.maxSponsorshipPerDay());
        console.log("Sponsorship Enabled:", paymaster.sponsorshipEnabled());
        console.log("Signature Required:", paymaster.signatureRequired());
        console.log("Verifying Signer:", paymaster.verifyingSigner());
    }

    /**
     * @notice 资助 Paymaster（添加 stake 和 deposit）
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
        uint256 paymasterPrivateKey = vm.envUint("PAYMASTER_PRIVATE_KEY");
        address paymasterSigner = vm.addr(paymasterPrivateKey);

        console.log("=== Configuring Paymaster ===");
        vm.startBroadcast(deployerPrivateKey);

        paymaster.enableSponsorship();
        console.log("Sponsorship enabled");

        paymaster.setVerifyingSigner(paymasterSigner);
        console.log("Verifying signer set");

        paymaster.setSignatureRequired(true);
        console.log("Signature requirement enabled");

        // 设置每笔操作最大gas花费
        paymaster.setMaxGasCostPerOp(0.01 ether);
        console.log("Max gas cost per op set to 0.01 ETH");

        // 设置每天最大赞助次数
        paymaster.setMaxSponsorshipPerDay(2);
        console.log("Max sponsorship per day set to 2");

        vm.stopBroadcast();

        console.log("Success!");
    }

    /**
     * @notice 生成带 initCode 的 UserOperation（用于测试首次创建账户）
     * @dev 使用 TEST_SALT 确保账户不存在
     */
    function generateUserOpWithInitCode() public view {
        uint256 ownerPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        uint256 paymasterPrivateKey = vm.envUint("PAYMASTER_PRIVATE_KEY");
        address owner = vm.addr(ownerPrivateKey);

        console.log("=== Generating UserOperation WITH InitCode (New Account) ===");
        console.log("");
        console.log("Owner Address:", owner);
        console.log("Factory:", address(factory));
        console.log("Test Salt:", TEST_SALT);
        console.log("");

        // 使用 TEST_SALT 预计算账户地址
        address accountAddr = factory.getAddress(owner, TEST_SALT);
        console.log("New Account Address:", accountAddr);

        bool accountExists = accountAddr.code.length > 0;
        console.log("Account Exists:", accountExists);

        if (accountExists) {
            console.log("");
            console.log("WARNING: Account already exists!");
            console.log("Cannot test initCode with existing account.");
            console.log("Consider changing TEST_SALT value.");
            return;
        }
        console.log("");

        // 1. 构造 initCode（必须有，因为账户不存在）
        bytes memory initCode = abi.encodePacked(
            address(factory), abi.encodeWithSignature("createAccount(address,uint256)", owner, TEST_SALT)
        );
        console.log("=== InitCode Details ===");
        console.log("InitCode:", vm.toString(initCode));
        console.log("InitCode Length:", initCode.length);
        console.log("");

        // 2. 构造 callData（首次创建可以为空）
        bytes memory callData = "";

        // 3. nonce = 0（新账户）
        uint256 nonce = 0;

        // 4. 构造 paymasterAndData
        uint48 validAfter = uint48(block.timestamp);
        uint48 validUntil = uint48(block.timestamp + 30 minutes);

        bytes memory payload = abi.encodePacked(validUntil, validAfter, uint8(0), bytes32(0));

        bytes32 dataHash = keccak256(
            abi.encodePacked(
                address(entryPoint), address(paymaster), accountAddr, nonce, validUntil, validAfter, payload
            )
        );
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(paymasterPrivateKey, ethSignedMessageHash);
        bytes memory paymasterSignature = abi.encodePacked(pr, ps, pv);
        bytes memory paymasterData = abi.encodePacked(payload, paymasterSignature);
        bytes memory paymasterAndData = abi.encodePacked(address(paymaster), paymasterData);

        // 5. 构造 UserOperation
        UserOperation memory userOp = UserOperation({
            sender: accountAddr,
            nonce: nonce,
            initCode: initCode, // ✅ 必须有 initCode
            callData: callData,
            callGasLimit: 200000, // 创建账户需要更多 gas
            verificationGasLimit: 300000,
            preVerificationGas: 100000,
            maxFeePerGas: 2 gwei,
            maxPriorityFeePerGas: 1 gwei,
            paymasterAndData: paymasterAndData,
            signature: ""
        });

        console.log("=== UserOperation Summary ===");
        console.log("Sender (will be created):", userOp.sender);
        console.log("Nonce:", userOp.nonce);
        console.log("InitCode length:", userOp.initCode.length);
        console.log("CallGasLimit:", userOp.callGasLimit);
        console.log("VerificationGasLimit:", userOp.verificationGasLimit);
        console.log("");

        // 6. 签名
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, userOpHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 7. 输出 JSON
        console.log("=== Copy the following JSON for InitCode Test ===");
        console.log("");
        console.log("{");
        console.log('  "id": 1,');
        console.log('  "jsonrpc": "2.0",');
        console.log('  "method": "eth_sendUserOperation",');
        console.log('  "params": [');
        console.log("    {");
        console.log('      "sender": "%s",', vm.toString(accountAddr));
        console.log('      "nonce": "0x0",');
        console.log('      "initCode": "%s",', vm.toString(initCode));
        console.log('      "callData": "0x",');
        console.log('      "callGasLimit": "%x",', userOp.callGasLimit);
        console.log('      "verificationGasLimit": "%x",', userOp.verificationGasLimit);
        console.log('      "preVerificationGas": "%x",', userOp.preVerificationGas);
        console.log('      "maxFeePerGas": "%x",', userOp.maxFeePerGas);
        console.log('      "maxPriorityFeePerGas": "%x",', userOp.maxPriorityFeePerGas);
        console.log('      "paymasterAndData": "%s",', vm.toString(paymasterAndData));
        console.log('      "signature": "%s"', vm.toString(signature));
        console.log("    },");
        console.log('    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"');
        console.log("  ]");
        console.log("}");
        console.log("");
        console.log("=== This will CREATE a new account at ===");
        console.log(accountAddr);
        console.log("");
        console.log("After successful execution:");
        console.log("- Account will exist at the sender address");
        console.log("- Future UserOps for this account should NOT include initCode");
    }

    /**
     * @notice 检查账户是否存在
     */
    function checkAccountExists() public view {
        address owner = vm.addr(vm.envUint("USER_PRIVATE_KEY"));
        address accountAddr = factory.getAddress(owner, SALT);
        console.log("=== Check Account Status ===");
        console.log("");
        console.log("Account Address:", accountAddr);

        uint256 codeSize = accountAddr.code.length;
        console.log("Code Size:", codeSize);
        console.log("Account Exists:", codeSize > 0);

        if (codeSize > 0) {
            console.log("");
            console.log("SUCCESS! Account has been created!");

            SimpleAccount account = SimpleAccount(payable(accountAddr));
            console.log("");
            console.log("=== Account Info ===");
            console.log("Owner:", account.owner());
            console.log("Nonce:", account.nonce());
            console.log("EntryPoint:", address(account.entryPoint()));
            console.log("Balance:", accountAddr.balance);
        } else {
            console.log("");
            console.log("Account does NOT exist yet.");
            console.log("Possible reasons:");
            console.log("1. UserOperation is still pending in mempool");
            console.log("2. UserOperation failed validation");
            console.log("3. Bundler hasn't processed it yet");
            console.log("");
            console.log("Wait a few seconds and try again.");
        }
    }

    // withdraw stake from paymaster to deployer address
    function withdrawStake() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("=== Withdrawing Stake from Paymaster ===");

        vm.startBroadcast(deployerPrivateKey);

        // 取消质押
        // paymaster.unlockStake();
        // console.log("Stake unlock initiated");

        // 提取质押
        // paymaster.withdrawStake(payable(vm.addr(deployerPrivateKey)));
        // console.log("Stake withdrawn to deployer address");

        uint256 amount = entryPoint.balanceOf(address(paymaster));
        paymaster.withdrawTo(payable(deployerAddress), amount);
        vm.stopBroadcast();

        console.log("Success!");
    }
}
