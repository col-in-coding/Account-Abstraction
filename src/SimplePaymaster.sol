// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BasePaymaster} from "@account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";
import {_packValidationData} from "@account-abstraction/contracts/core/Helpers.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SimplePaymaster is Ownable, BasePaymaster {
    using ECDSA for bytes32;

    // 赞助策略
    bool public sponsorshipEnabled = true;
    uint256 public maxGasCostPerOp = 0.001 ether; // 每笔最多赞助0.001 ETH的Gas

    // 签名验证相关
    address public verifyingSigner;
    bool public signatureRequired = true; // 是否需要签名验证

    // 用户赞助次数追踪
    mapping(address => uint256) public userSponsorshipCount;
    mapping(address => uint256) public userLastSponsorshipTime;

    // 每个用户每天最多赞助次数
    uint256 public maxSponsorshipPerDay = 5;
    uint256 public constant DAY_DURATION = 24 * 60 * 60; // 24 hours

    event UserOperationSponsored(address indexed user, uint256 gasCost);
    event UserOperationFailed(address indexed user, uint256 gasCost);
    event SignatureValidated(address indexed user, address signer, uint48 validUntil, uint48 validAfter);

    constructor(address _entryPoint) BasePaymaster(IEntryPoint(_entryPoint)) Ownable(msg.sender) {}

    function setVerifyingSigner(address _signer) external onlyOwner {
        verifyingSigner = _signer;
    }

    function setSignatureRequired(bool _required) external onlyOwner {
        signatureRequired = _required;
    }

    function enableSponsorship() external onlyOwner {
        sponsorshipEnabled = true;
    }

    function disableSponsorship() external onlyOwner {
        sponsorshipEnabled = false;
    }

    function setMaxGasCostPerOp(uint256 _maxCost) external onlyOwner {
        maxGasCostPerOp = _maxCost;
    }

    function setMaxSponsorshipPerDay(uint256 _maxPerDay) external onlyOwner {
        maxSponsorshipPerDay = _maxPerDay;
    }

    /**
     * @dev 验证 paymaster 是否愿意为此 UserOperation 付费
     * @notice 根据 EIP-4337，验证阶段禁止使用 TIMESTAMP 等操作码
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        /*userOpHash*/
        uint256 maxCost
    )
        internal
        view
        override
        returns (bytes memory context, uint256 sigTimeRange)
    {
        require(sponsorshipEnabled, "Sponsorship disabled");
        require(maxCost <= maxGasCostPerOp, "Gas cost exceeds limit");

        address user = userOp.sender;

        // 读取用户赞助次数（状态检查，不涉及时间）
        uint256 currentCount = userSponsorshipCount[user];
        uint256 lastTime = userLastSponsorshipTime[user];

        uint48 validUntil = 0;
        uint48 validAfter = 0;

        // 如果需要签名验证，解析并验证 paymasterData
        if (signatureRequired && verifyingSigner != address(0)) {
            (validUntil, validAfter) = _validateSignature(userOp);
        } else {
            // 不需要签名时，设置一个很大的有效期
            validAfter = 0;
            validUntil = type(uint48).max; // 最大有效期
        }

        // ✅ 关键修复：不在验证阶段使用 block.timestamp
        // 时间验证完全通过 validUntil/validAfter 在 EntryPoint 层面处理
        context = abi.encode(
            user, // 用户地址
            maxCost, // 最大成本
            lastTime, // 上次赞助时间（用于 _postOp）
            currentCount // 当前计数（用于 _postOp）
        );

        sigTimeRange = _packValidationData(false, validUntil, validAfter);

        return (context, sigTimeRange);
    }

    /**
     * @dev 验证paymasterData中的签名
     * paymasterData格式: validUntil(6) + validAfter(6) + userType(1) + extraData(32) + signature(65)
     * @notice ✅ 不使用 block.timestamp，时间验证由 EntryPoint 通过 sigTimeRange 处理
     */
    function _validateSignature(UserOperation calldata userOp)
        internal
        view
        returns (uint48 validUntil, uint48 validAfter)
    {
        bytes calldata paymasterAndData = userOp.paymasterAndData;

        // v0.7 paymasterAndData格式: paymaster(20) + paymasterData
        require(paymasterAndData.length >= 20, "Invalid paymasterAndData length");

        // 提取paymasterData（从第20个字节开始）
        bytes calldata paymasterData = paymasterAndData[20:];

        // paymasterData最小长度检查：6+6+1+32+65 = 110 bytes
        require(paymasterData.length >= 110, "Invalid paymasterData length");

        // 解析paymasterData
        validUntil = uint48(bytes6(paymasterData[0:6]));
        validAfter = uint48(bytes6(paymasterData[6:12]));
        // uint8 userType = uint8(paymasterData[12]);
        // bytes32 extraData = bytes32(paymasterData[13:45]);

        // 提取签名（最后65个字节）
        bytes memory signature = paymasterData[45:110];

        // ✅ 关键修复：移除时间验证，EntryPoint 会通过 sigTimeRange 自动验证
        // ❌ 删除: require(block.timestamp >= validAfter, "Signature not yet valid");
        // ❌ 删除: require(block.timestamp <= validUntil, "Signature expired");

        // 构造用于签名的消息哈希（与测试代码中的逻辑保持一致）
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                address(entryPoint), // EntryPoint 地址
                address(this), // Paymaster 地址
                userOp.sender, // 用户账户地址
                userOp.nonce, // nonce
                validUntil, // 有效期
                validAfter, // 生效时间
                paymasterData[0:45] // paymaster原始数据（不包含签名）
            )
        );

        // 使用内联汇编优化 EIP-191 签名哈希
        bytes32 ethSignedMessageHash;
        assembly {
            // 在内存中构造: "\x19Ethereum Signed Message:\n32" + dataHash
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 前缀 (28 bytes)
            mstore(0x1c, dataHash) // dataHash (32 bytes，从偏移28开始)
            ethSignedMessageHash := keccak256(0x00, 0x3c) // 总共60字节 (0x3c = 60)
        }

        // 验证签名
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(recoveredSigner == verifyingSigner, "Invalid signature");

        return (validUntil, validAfter);
    }

    /**
     * @dev 在 UserOperation 执行后调用，用于后续处理
     * @notice ✅ _postOp 阶段可以使用 block.timestamp
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        (address user,, uint256 lastTime, uint256 currentCount) =
            abi.decode(context, (address, uint256, uint256, uint256));

        if (mode == PostOpMode.opSucceeded) {
            // 操作成功，更新用户赞助记录
            // ✅ _postOp 中可以使用 block.timestamp
            if (block.timestamp > lastTime + DAY_DURATION) {
                // 新的一天，重置计数
                userSponsorshipCount[user] = 1;
            } else {
                // 同一天，增加计数
                userSponsorshipCount[user] = currentCount + 1;
            }
            userLastSponsorshipTime[user] = block.timestamp;

            emit UserOperationSponsored(user, actualGasCost);
        } else if (mode == PostOpMode.opReverted) {
            // 操作失败，但仍需支付 gas
            emit UserOperationFailed(user, actualGasCost);
        }

        // 可以在这里实现更复杂的计费逻辑
        // 比如给用户积分、记录使用统计等
    }
}
