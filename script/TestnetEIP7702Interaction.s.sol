// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.28;

// import {Script, console} from "forge-std/Script.sol";
// import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
// import {SimplePaymaster} from "../src/SimplePaymaster.sol";
// import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
// import {SimpleEIP7702Account} from "../src/SimpleEIP7702Account.sol";

// /**
//  * @title TestnetEIP7702Interaction
//  * @notice Sepolia 测试网交互脚本
//  * @dev 使用方式:
//  *      1. Query Info: forge script script/TestnetEIP7702Interaction.s.sol:TestnetEIP7702Interaction --sig "queryInfo()" --rpc-url sepolia
//  *      2. EIP-7702 Authorization: forge script script/TestnetEIP7702Interaction.s.sol:TestnetEIP7702Interaction --sig "authorization()" --rpc-url sepolia --broadcast
//  *      3.
//  *
//  * @dev 环境变量要求:
//  *      - USER_PRIVATE_KEY: 用户 EOA 私钥（用于 EIP-7702 授权）
//  *      - PAYMASTER_PRIVATE_KEY: Paymaster 管理员私钥
//  */
// contract TestnetEIP7702Interaction is Script {
//     // Sepolia 测试网已部署的合约地址
//     address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
//     address constant PAYMASTER = 0xc7C1d16D484f9719CaD5e677daA3c60790d5DCB5;
//     address constant EIP7702_DELEGATE = 0x3aC4d88C223501Fc5572fb89Cb81Ac81Ad8d3156;

//     IEntryPoint entryPoint;
//     SimplePaymaster paymaster;
//     SimpleEIP7702Account delegate;

//     uint256 private ownerPrivateKey = vm.envUint("USER_PRIVATE_KEY");
//     uint256 private paymasterPrivateKey = vm.envUint("PAYMASTER_PRIVATE_KEY");
//     uint256 private recipientPrivateKey = vm.envUint("PRIVATE_KEY");

//     function setUp() public {
//         entryPoint = IEntryPoint(ENTRY_POINT);
//         paymaster = SimplePaymaster(PAYMASTER);
//         delegate = SimpleEIP7702Account(payable(EIP7702_DELEGATE));
//     }

//     function queryInfo() public view {
//         console.log("=== Sepolia Testnet Contract Information ===");
//         console.log("");
//         console.log("EntryPoint address:", address(entryPoint));
//         console.log("Paymaster address:", address(paymaster));
//         console.log("EIP7702 Delegate address:", address(delegate));

//         // Paymaster 信息
//         console.log("");
//         console.log("=== Paymaster Information ===");
//         console.log("Paymaster:", address(paymaster));
//         console.log("Paymaster Owner:", paymaster.owner());
//         console.log("Paymaster Deposit:", entryPoint.balanceOf(address(paymaster)));
//         console.log("Max Gas Cost Per Op:", paymaster.maxGasCostPerOp());
//         console.log("Max Sponsorship Per Day:", paymaster.maxSponsorshipPerDay());
//         console.log("Sponsorship Enabled:", paymaster.sponsorshipEnabled());
//         console.log("Signature Required:", paymaster.signatureRequired());
//         console.log("Verifying Signer:", paymaster.verifyingSigner());

//         // Account 信息
//         console.log("");
//         console.log("=== EIP7702 Delegate Information ===");
//         address ownerAddr = vm.addr(ownerPrivateKey);
//         console.log("EOA address: ", ownerAddr);
//         console.log("EOA code length: ", ownerAddr.code.length);
//     }

//     /**
//      * @notice 发送 EIP-7702 授权交易
//      */
//     function authorization() public {
//         address ownerAddr = vm.addr(ownerPrivateKey);

//         console.log("=== EIP-7702 Authorization ===");
//         console.log("EOA Address:", ownerAddr);
//         console.log("Delegate Contract:", address(delegate));
//         console.log("Current EOA code length:", ownerAddr.code.length);

//         vm.startBroadcast(ownerPrivateKey);

//         // 构建 EIP-7702 授权列表
//         // authorizationList: [chainId, address, nonce, yParity, r, s]
//         uint256 chainId = block.chainid; // Sepolia chainId = 11155111
//         address delegateAddress = address(delegate);
//         uint256 authNonce = vm.getNonce(ownerAddr); // 获取当前 EOA 的 nonce

//         console.log("Chain ID:", chainId);
//         console.log("Auth Nonce:", authNonce);

//         vm.signAndAttachDelegation(delegateAddress, ownerPrivateKey);
//         address(ownerAddr).call(""); // 触发授权
//         vm.stopBroadcast();

//         // 验证授权是否成功
//         console.log("After authorization:");
//         console.log("EOA code length:", ownerAddr.code.length);
//         if (ownerAddr.code.length > 0) {
//             console.log("EIP-7702 authorization successful!");

//             // 检查代码是否为预期的 EIP-7702 格式
//             bytes memory expectedCode = abi.encodePacked(hex"ef0100", delegateAddress);

//             if (keccak256(ownerAddr.code) == keccak256(expectedCode)) {
//                 console.log("Code format verified: EIP-7702 delegation pointer");
//             } else {
//                 console.log("Unexpected code format");
//                 console.logBytes(ownerAddr.code);
//             }
//         } else {
//             console.log("Authorization failed - no code found");
//         }
//     }

//     /**
//      * @notice 生成 EIP-7702 用户操作的 UserOperation JSON
//      * @dev 测试采用EIP7702用户签名转账，并用EIP4337的EntryPoint提交，自己支付Gas
//      */
//     function generateUserOpForEntryPoint() public {
//         address owner = vm.addr(ownerPrivateKey);
//         address recipient = vm.addr(recipientPrivateKey);

//         // 检查是否已完成 EIP-7702 授权
//         if (owner.code.length == 0) {
//             console.log("ERROR: EOA has not been authorized with EIP-7702 yet!");
//             console.log("Please run authorization() first or use a different tool to complete EIP-7702 authorization.");
//             return;
//         }

//         // 验证代码格式
//         bytes memory expectedCode = abi.encodePacked(hex"ef0100", address(delegate));
//         if (keccak256(owner.code) != keccak256(expectedCode)) {
//             console.log("WARNING: Code format doesn't match expected EIP-7702 pattern");
//             console.log("Expected:", vm.toString(expectedCode));
//             console.log("Actual:", vm.toString(owner.code));
//         } else {
//             console.log("EIP-7702 authorization verified successfully");
//         }

//         SimpleEIP7702Account account = SimpleEIP7702Account(payable(owner));
//         uint256 nonce = account.nonce();

//         console.log("=== Transaction Details ===");
//         console.log("From (EIP-7702 EOA):", owner);
//         console.log("To:", recipient);
//         console.log("Amount: 0.01 ETH");
//         console.log("");

//         console.log("=== Signature Verification Info ===");
//         console.log("Expected Owner Address:", account.owner());
//         console.log("account nonce:", nonce);
//         console.log("Expected Paymaster Signer:", vm.addr(paymasterPrivateKey));
//         console.log("Actual Paymaster Signer:", paymaster.verifyingSigner());

//         if (vm.addr(paymasterPrivateKey) != paymaster.verifyingSigner()) {
//             console.log("ERROR: Paymaster signer mismatch!", vm.addr(paymasterPrivateKey), paymaster.verifyingSigner());
//         }
//         console.log("Paymaster signer verification: OK");
//         console.log("");

//         // 构建一个简单的转账 UserOperation
//         uint256 transferAmount = 0.01 ether;
//         bytes memory callData = abi.encodeWithSignature("execute(address,uint256,bytes)", recipient, transferAmount, "");

//         // // 构造 paymasterAndData
//         // uint48 validAfter = uint48(block.timestamp);
//         // uint48 validUntil = uint48(block.timestamp + 30 minutes);

//         // console.log("=== Paymaster Signature Debug ===");
//         // console.log("Current block timestamp:", block.timestamp);
//         // console.log("Valid after:", validAfter);
//         // console.log("Valid until:", validUntil);

//         // bytes memory payload = abi.encodePacked(validUntil, validAfter, uint8(0), bytes32(0));
//         // bytes32 dataHash = keccak256(
//         //     abi.encodePacked(address(entryPoint), address(paymaster), owner, nonce, validUntil, validAfter, payload)
//         // );
//         // console.log("Paymaster data hash:", vm.toString(dataHash));

//         // bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
//         // (uint8 pv, bytes32 pr, bytes32 ps) = vm.sign(paymasterPrivateKey, ethSignedMessageHash);
//         // bytes memory paymasterSignature = abi.encodePacked(pr, ps, pv);
//         // bytes memory paymasterData = abi.encodePacked(payload, paymasterSignature);
//         // bytes memory paymasterAndData = abi.encodePacked(address(paymaster), paymasterData);
//         // return;

//         // 构造 UserOperation
//         UserOperation memory userOp = UserOperation({
//             sender: owner,
//             nonce: nonce,
//             initCode: "", // EIP-7702 账户不需要 initCode
//             callData: callData,
//             callGasLimit: 80000, // 提高 call gas
//             verificationGasLimit: 80000, // 提高验证 gas
//             preVerificationGas: 50000, // 提高到 50000 (超过要求的 45912)
//             maxFeePerGas: 2 gwei,
//             maxPriorityFeePerGas: 1 gwei,
//             paymasterAndData: "",
//             signature: ""
//         });

//         // 签名
//         bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

//         console.log("");
//         console.log("=== UserOperation Signature Debug ===");
//         console.log("UserOp hash:", vm.toString(userOpHash));
//         console.log("Signing with owner private key for address:", owner);

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, userOpHash);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         console.log("Signature r:", vm.toString(r));
//         console.log("Signature s:", vm.toString(s));
//         console.log("Signature v:", v);
//         console.log("");

//         bytes4 magicValue = account.isValidSignature(userOpHash, signature);
//         console.log("isValidSignature returned:", vm.toString(magicValue));
//         userOp.signature = signature;

//         bytes32 userOpHash2 = entryPoint.getUserOpHash(userOp);
//         console.log("UserOp hash:", vm.toString(userOpHash2));
//         // _simulateBundlerSubmission(userOp);
//         // return;

//         // 输出 JSON
//         console.log("=== Copy the following JSON for EIP-7702 UserOperation ===");
//         console.log("");
//         console.log("{");
//         console.log('  "id": 1,');
//         console.log('  "jsonrpc": "2.0",');
//         console.log('  "method": "eth_sendUserOperation",');
//         console.log('  "params": [');
//         console.log("    {");
//         console.log('      "sender": "%s",', vm.toString(owner));
//         if (nonce == 0) {
//             console.log('      "nonce": "0x0",');
//         } else {
//             console.log('      "nonce": "0x%x",', nonce);
//         }
//         console.log('      "initCode": "0x",'); // EIP-7702 账户不需要 initCode
//         console.log('      "callData": "%s",', vm.toString(callData));
//         console.log("      \"callGasLimit\": \"0x186a0\",");  // 100000
//         console.log("      \"verificationGasLimit\": \"0x30d40\",");  // 200000
//         console.log("      \"preVerificationGas\": \"0xc350\",");  // 50000
//         console.log("      \"maxFeePerGas\": \"0x37e11d600\",");  // 15 gwei
//         console.log("      \"maxPriorityFeePerGas\": \"0x3b9aca00\",");  // 1 gwei
//         // console.log('      "paymasterAndData": "%s",', vm.toString(paymasterAndData));
//         console.log('      "signature": "%s"', vm.toString(signature));
//         console.log("    },");
//         console.log('    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789"');
//         console.log("  ]");
//         console.log("}");
//         console.log("");
//         console.log("=== UserOperation Details ===");
//         console.log("Sender (EIP-7702 EOA):", owner);
//         console.log("Recipient:", recipient);
//         console.log("Transfer Amount (wei):", transferAmount);
//         console.log("Nonce:", nonce);
//         console.log("Gas Limits:");
//         console.log("  - Call Gas:", userOp.callGasLimit);
//         console.log("  - Verification Gas:", userOp.verificationGasLimit);
//         console.log("  - Pre-verification Gas:", userOp.preVerificationGas);
//         console.log("Gas Prices:");
//         console.log("  - Max Fee (wei):", userOp.maxFeePerGas);
//         console.log("  - Max Priority Fee (wei):", userOp.maxPriorityFeePerGas);
//         console.log("");
//         // console.log("Paymaster:", address(paymaster));
//         // console.log("Paymaster Data Length (bytes):", paymasterAndData.length);
//     }

//     /**
//      * @notice 增加 Paymaster 的 gas 限制
//      * @dev 使用方式: forge script script/TestnetEIP7702Interaction.s.sol:TestnetEIP7702Interaction --sig "increasePaymasterGasLimit()" --rpc-url sepolia --broadcast
//      */
//     function increasePaymasterGasLimit() public {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

//         console.log("=== Increasing Paymaster Gas Limit ===");
//         console.log("Current Max Gas Cost Per Op:", paymaster.maxGasCostPerOp());

//         vm.startBroadcast(deployerPrivateKey);

//         // 增加到 0.05 ETH (5倍)
//         paymaster.setMaxGasCostPerOp(0.05 ether);
//         console.log("Updated Max Gas Cost Per Op to 0.05 ETH");

//         vm.stopBroadcast();

//         console.log("New Max Gas Cost Per Op:", paymaster.maxGasCostPerOp());
//         console.log("Success!");
//     }

//     function addDepositToEntryPoint() public {
//         address owner = vm.addr(ownerPrivateKey);
//         SimpleEIP7702Account account = SimpleEIP7702Account(payable(owner));
//         vm.startBroadcast(ownerPrivateKey);
//         account.addDeposit{value: 0.1 ether}();
//         vm.stopBroadcast();
//         uint256 balance = entryPoint.balanceOf(address(account));
//         console.log("New deposit balance of account in EntryPoint:", balance);
//     }

//     function _simulateBundlerSubmission(UserOperation memory userOp) internal {
//         // 模拟 Bundler 调用 EntryPoint
//         UserOperation[] memory ops = new UserOperation[](1);
//         ops[0] = userOp;
//         address recipient = vm.addr(recipientPrivateKey);
//         address owner = vm.addr(ownerPrivateKey);

//         vm.startBroadcast(ownerPrivateKey);
//         entryPoint.handleOps(ops, payable(recipient));
//         vm.stopBroadcast();
//     }
// }
