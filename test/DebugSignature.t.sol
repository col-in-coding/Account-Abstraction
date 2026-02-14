// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract DebugSignature is Test {
    using ECDSA for bytes32;

    function setUp() public {
        // 创建 Sepolia fork
        vm.createSelectFork("sepolia");
    }

    /**
     * 调试：测试签名恢复
     * 使用已知的私钥、消息和签名来验证恢复逻辑
     */
    function test_SignatureRecovery() public {
        // 已知的账户私钥和地址
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address expectedSigner = vm.addr(privateKey);

        console.log("Expected signer address:", expectedSigner);

        // 一个任意的消息哈希
        bytes32 messageHash = keccak256(abi.encodePacked("Test message"));
        console.log("Message hash:", vm.toString(messageHash));

        // 使用 vm.sign 对消息进行签名（这是标准的 ECDSA 签名）
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console.log("Signature:", vm.toString(signature));
        console.log("Signature length:", signature.length);

        // 直接恢复
        address recovered = messageHash.recover(signature);
        console.log("Recovered address (direct):", recovered);
        console.log("Match (direct):", recovered == expectedSigner);

        // 使用 Ethereum 前缀恢复
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address recoveredWithPrefix = ethSignedHash.recover(signature);
        console.log("Recovered address (with prefix):", recoveredWithPrefix);
        console.log("Match (with prefix):", recoveredWithPrefix == expectedSigner);
    }

    /**
     * 测试：手动生成正确的签名
     * 这测试使用 Foundry 的 vm.sign 来生成一个已知应该正确的签名
     */
    function test_ManualSignatureGeneration() public {
        // 已知的私钥和地址
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address expectedSigner = vm.addr(privateKey);

        console.log("Expected signer:", expectedSigner);
        console.log("Private key provided:", privateKey != 0);

        // 构造 UserOperation
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: expectedSigner,
            nonce: 1,
            initCode: hex"",
            callData: hex"b61d27f60000000000000000000000004ba3f297f8c7213025c15678e0a39a0be7e6174a000000000000000000000000000000000000000000000000000000174876e80000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000",
            accountGasLimits: _packGasLimits(150000, 21500),
            preVerificationGas: 51824,
            gasFees: _packGasFees(2436128452, 2878378),
            paymasterAndData: hex"68d4b6784f1143b91d2907071ec2c5279b44b7f00000000000000000000000000000c3500000000000000000000000000000c3500000698573a80000698565980000000000000000000000000000000000000000000000000000000000000000009735561c17754a1365206120523e4682f57f1c754b4356c7e34408c249104d8352c60c5f7a04167ae579cd1f168d244cacbb1664dcdc30e936037fdc67cef9b51b",
            signature: hex""
        });

        // 从 EntryPoint 获取 UserOp Hash
        EntryPoint entryPoint = EntryPoint(payable(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108));
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        console.log("\nUserOp Hash from EntryPoint:", vm.toString(userOpHash));

        // 使用私钥手动签署这个哈希
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, userOpHash);
        bytes memory manualSignature = abi.encodePacked(r, s, v);

        console.log("\nManually generated signature:", vm.toString(manualSignature));
        console.log("Signature length:", manualSignature.length);

        // 恢复地址
        address recovered = userOpHash.recover(manualSignature);
        console.log("\nRecovered signer:", recovered);
        console.log("Match:", recovered == expectedSigner);
    }

    function _packGasLimits(uint128 verificationGasLimit, uint128 callGasLimit) internal pure returns (bytes32) {
        return bytes32(uint256(verificationGasLimit) << 128 | uint256(callGasLimit));
    }

    function _packGasFees(uint128 maxFeePerGas, uint128 maxPriorityFeePerGas) internal pure returns (bytes32) {
        return bytes32(uint256(maxFeePerGas) << 128 | uint256(maxPriorityFeePerGas));
    }

    function _splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
