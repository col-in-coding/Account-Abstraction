// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BasePaymaster} from "@account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {_packValidationData} from "@account-abstraction/contracts/core/Helpers.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Paymaster is BasePaymaster {
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

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {}

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
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
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

        // 检查用户今日赞助次数（只读检查，不修改状态）
        uint256 currentCount = userSponsorshipCount[user];
        uint256 lastTime = userLastSponsorshipTime[user];

        // 如果是新的一天，有效计数为0，否则使用当前计数
        uint256 effectiveCount = (block.timestamp > lastTime + DAY_DURATION) ? 0 : currentCount;
        require(effectiveCount < maxSponsorshipPerDay, "Daily sponsorship limit exceeded");

        uint48 validUntil = 0;
        uint48 validAfter = 0;

        // 如果需要签名验证，解析并验证 paymasterData
        if (signatureRequired && verifyingSigner != address(0)) {
            (validUntil, validAfter) = _validateSignature(userOp);
        } else {
            validAfter = 0; // 立即生效
            validUntil = uint48(block.timestamp + 1 hours); // 1小时有效期
        }

        context = abi.encode(
            user, // 用户地址
            maxCost, // 最大成本
            block.timestamp, // 赞助时间
            effectiveCount // 当前有效计数
        );

        sigTimeRange = _packValidationData(false, validUntil, validAfter);

        return (context, sigTimeRange);
    }

    /**
     * @dev 验证paymasterData中的签名
     * paymasterData格式: validUntil(6) + validAfter(6) + userType(1) + extraData(32) + signature(65)
     */
    function _validateSignature(PackedUserOperation calldata userOp)
        internal
        view
        returns (uint48 validUntil, uint48 validAfter)
    {
        bytes calldata paymasterAndData = userOp.paymasterAndData;

        // paymasterAndData格式: paymaster(20) + verificationGasLimit(16) + postOpGasLimit(16) + paymasterData
        require(paymasterAndData.length >= 52, "Invalid paymasterAndData length"); // 至少20+16+16

        // 提取paymasterData（从第52个字节开始）
        bytes calldata paymasterData = paymasterAndData[52:];

        // paymasterData最小长度检查：6+6+1+32+65 = 110 bytes
        require(paymasterData.length >= 110, "Invalid paymasterData length");

        // 解析paymasterData
        validUntil = uint48(bytes6(paymasterData[0:6]));
        validAfter = uint48(bytes6(paymasterData[6:12]));
        // uint8 userType = uint8(paymasterData[12]);
        // bytes32 extraData = bytes32(paymasterData[13:45]);

        // 提取签名（最后65个字节）
        bytes memory signature = paymasterData[45:110];

        // 验证时间窗口
        require(block.timestamp >= validAfter, "Signature not yet valid");
        require(block.timestamp <= validUntil, "Signature expired");

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

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        // 验证签名
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(recoveredSigner == verifyingSigner, "Invalid signature");

        return (validUntil, validAfter);
    }

    /**
     * @dev 在 UserOperation 执行后调用，用于后续处理
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    )
        internal
        override
    {
        (address user,, uint256 sponsorshipTime, uint256 effectiveCount) =
            abi.decode(context, (address, uint256, uint256, uint256));

        // 1. 即使操作失败，Paymaster仍然支付了gas费用，必须计入限额
        if (block.timestamp > userLastSponsorshipTime[user] + DAY_DURATION) {
            userSponsorshipCount[user] = 1;
        } else {
            userSponsorshipCount[user] = effectiveCount + 1;
        }
        userLastSponsorshipTime[user] = sponsorshipTime;

        if (mode == PostOpMode.opSucceeded) {
            emit UserOperationSponsored(user, actualGasCost);
        } else if (mode == PostOpMode.opReverted) {
            emit UserOperationFailed(user, actualGasCost);
        }
    }
}
