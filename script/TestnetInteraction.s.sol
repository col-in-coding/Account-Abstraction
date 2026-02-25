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
 */
contract TestnetInteraction is Script {
    // Sepolia 测试网已部署的合约地址
    address constant ENTRY_POINT = 0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108;
    address constant FACTORY = 0xD03fc9CA948ED3c8eD74809660269dF44149ba3B;
    address constant PAYMASTER = 0x9B7CD9ad5D5B314199dD17d0854d0f8002c46314;
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
            console.log("EntryPoint Deposit for EOA: ", entryPoint.balanceOf(ownerEOA));
            console.log("EIP7702 Delegate Nonce: ", entryPoint.getNonce(ownerEOA, 0));
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
        console.log("Paymaster Staked: ", entryPoint.getDepositInfo(address(paymaster)).staked);
        console.log("Paymaster Stake: ", entryPoint.getDepositInfo(address(paymaster)).stake);
        console.log("Paymaster Deposit: ", entryPoint.getDepositInfo(address(paymaster)).deposit);
    }

    /**
     * @notice 添加存款到EntryPoint账户
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "simpleAccountAddDepositToEntryPoint()" --rpc-url sepolia --broadcast
     */
    function simpleAccountAddDepositToEntryPoint() public {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        if (simpleAccountAddress.code.length == 0) {
            console.log("Account does not exist!");
        }

        vm.startBroadcast(userPrivateKey);
        entryPoint.depositTo{value: 1 ether}(simpleAccountAddress);
        vm.stopBroadcast();
        uint256 currentDeposit = entryPoint.balanceOf(simpleAccountAddress);
        console.log("Current Deposit for Account:", currentDeposit);
    }

    /**
     * @notice 添加存款到EntryPoint账户（EIP-7702 Delegate）
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "simple7702AddDepositToEntryPoint()" --rpc-url sepolia --broadcast
     */
    function simple7702AddDepositToEntryPoint() public {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        if (address(simple7702account).code.length == 0) {
            console.log("EIP-7702 Delegate is not attached yet.");
        }
        vm.startBroadcast(userPrivateKey);
        entryPoint.depositTo{value: 1 ether}(address(simple7702account));
        vm.stopBroadcast();
        uint256 currentDeposit = entryPoint.balanceOf(address(simple7702account));
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
            initCode = _createSimpleAccountInitCode(ownerEOA);
            console.log("InitCode: %s", vm.toString(initCode));
        }
        uint256 nonce = entryPoint.getNonce(simpleAccountAddress, 0);
        console.log("Current Nonce:", nonce);
    }

    function createUserOpFor7702AcountBatchExecution() public view {
        console.log("=== Create UserOperation for EIP-7702 Account Batch Execution ===");
        console.log("Delegate EOA: ", ownerEOA);
        console.log("EIP7702 Delegate Address: ", address(eip7702delegate));

        bytes memory expectedCode = abi.encodePacked(hex"ef0100", eip7702delegate);
        console.log("EOA code: ", vm.toString(ownerEOA.code));
        console.log("Expected EOA code: ", vm.toString(expectedCode));

        if (keccak256(ownerEOA.code) == keccak256(expectedCode)) {
            console.log("=== Authorization needed, signing... ===");

            // 构造 EIP-7702 Authorization 签名
            (bytes memory authSignature, bytes memory authorizationData) = _createEIP7702Authorization();

            console.log("Authorization Signature: ", vm.toString(authSignature));
            console.log("Authorization Data: ", vm.toString(authorizationData));
        } else {
            console.log("Authorization already attached to EOA code");
        }
    }

    /**
     * @notice 构造 EIP-7702 Authorization 签名
     * @dev EIP-7702 授权签名遵循以下格式（参考：https://github.com/ethereum/EIPs/blob/master/EIPS/eip-7702.md）:
     *      message = keccak256(0x05 || rlp([chainId, address, nonce]))
     *      其中：
     *      - 0x05 是 EIP-7702 魔数 (Magic)
     *      - chainId: 链ID
     *      - address: delegate 合约地址
     *      - nonce: EOA 的授权 nonce
     *
     * @return authSignature packed 格式的签名 (r || s || v)
     * @return authorizationData encoded 格式的完整授权数据 (address, chainId, nonce, v, r, s)
     */
    function _createEIP7702Authorization() internal view returns (bytes memory, bytes memory) {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 chainId = block.chainid;
        uint256 nonce = vm.getNonce(ownerEOA);

        // 1. 构造 Authorization Hash
        // 按照 EIP-7702 规范：keccak256(0x05 || rlp([chainId, address, nonce]))
        //
        // RLP 编码规则：对每个元素进行 hex 编码，移除前导零
        // - chainId: uint256 -> hex (去前导零) -> RLP encode
        // - address: address -> 0x + 40 hex chars (20 bytes)
        // - nonce: uint256 -> hex (去前导零) -> RLP encode
        //
        // 示例：chainId=0xaa36a7, address=0xCeEe..., nonce=0x66
        // RLP([0xaa36a7, 0xCeEe..., 0x66])

        bytes memory rlpData = _encodeEIP7702RLP(chainId, address(eip7702delegate), nonce);

        bytes32 authorizationHash = keccak256(
            abi.encodePacked(
                hex"05", // EIP-7702 魔数（必须是字节，不是字符串）
                rlpData // RLP 编码的 [chainId, address, nonce]
            )
        );

        // console.log("Authorization Hash: ", vm.toString(authorizationHash));
        // console.log("Chain ID: ", chainId);
        // console.log("Chain ID to rlp: ", vm.toString(_toMinimalBytes(chainId)));
        // console.log("Delegate Address: ", vm.toString(abi.encodePacked(address(eip7702delegate))));
        // console.log("Address to rlp: ", vm.toString(abi.encodePacked(address(eip7702delegate))));
        // console.log("Nonce: ", nonce);
        // console.log("Nonce to rlp: ", vm.toString(_toMinimalBytes(nonce)));

        // 2. 签署 Authorization Hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, authorizationHash);

        // console.log("Signature v: ", v);
        // console.log("Signature r: ", vm.toString(r));
        // console.log("Signature s: ", vm.toString(s));

        // 3. 组装签名数据 (packed 格式)
        // 格式: r || s || v (共 65 bytes)
        bytes memory authSignature = abi.encodePacked(r, s, v);
        console.log("Auth Signature (packed): ", vm.toString(authSignature));

        // 4. 组装完整的 Authorization 数据（用于 authorizationList）
        // 结构: [chainId, address, nonce, yParity, r, s]
        bytes memory authorizationData = abi.encode(
            address(eip7702delegate),
            chainId,
            nonce,
            v - 27, // yParity: 0 或 1
            r,
            s
        );
        // console.log("Auth Data (encoded): ", vm.toString(authorizationData));

        return (authSignature, authorizationData);
    }

    /**
     * @notice 编码 EIP-7702 RLP 数据
     * @dev RLP 编码格式：RLP([chainId, address, nonce])
     *      每个元素需要转换为最少长度的 hex 格式（去前导零）
     *
     * 示例对于 Sepolia:
     *   chainId=11155111 (0xaa36a7)
     *   address=0xCeEe3852dde1bB6FdF0bB2d1402A6f6B84Ab49d2
     *   nonce=102 (0x66)
     *
     * RLP 编码步骤：
     * 1. 转换每个值为最少长度的 hex
     * 2. 对短字符串（<56 bytes），前缀为 0xc0 + 长度
     * 3. 对每个元素，前缀为 0x80 + 长度（如果长度 <= 55）
     *
     * @return 编码后的 RLP 数据
     */
    function _encodeEIP7702RLP(uint256 chainId, address addr, uint256 nonce) internal pure returns (bytes memory) {
        // 只需要原始值，不进行单独编码
        bytes memory chainIdBytes = _toMinimalBytes(chainId);
        bytes memory addrBytes = abi.encodePacked(addr);
        bytes memory nonceBytes = _toMinimalBytes(nonce);

        // 组合所有元素（不编码）
        bytes memory elements = abi.encodePacked(
            _encodeRLPElement(chainIdBytes), _encodeRLPElement(addrBytes), _encodeRLPElement(nonceBytes)
        );

        // RLP 编码：列表前缀 + 内容
        // 对于短列表（<56 bytes），前缀为 0xc0 + 总长度
        uint256 totalLength = elements.length;
        if (totalLength < 56) {
            return abi.encodePacked(uint8(0xc0 + totalLength), elements);
        } else {
            revert("RLP list too long");
        }
    }

    /**
     * @notice 将字节转换为最小长度（去前导零）
     */
    function _toMinimalBytes(uint256 value) internal pure returns (bytes memory) {
        if (value == 0) {
            return new bytes(0);
        }

        bytes memory valueBytes = abi.encodePacked(value);
        uint256 start = 0;
        for (uint256 i = 0; i < valueBytes.length; i++) {
            if (valueBytes[i] != 0) {
                start = i;
                break;
            }
        }

        bytes memory trimmed = new bytes(valueBytes.length - start);
        for (uint256 i = 0; i < trimmed.length; i++) {
            trimmed[i] = valueBytes[start + i];
        }
        return trimmed;
    }

    /**
     * @notice RLP 编码单个元素
     */
    function _encodeRLPElement(bytes memory data) internal pure returns (bytes memory) {
        if (data.length == 1 && data[0] < 0x80) {
            // 单字节且 < 0x80，直接返回
            return data;
        } else if (data.length < 56) {
            // 短字符串：前缀为 0x80 + 长度
            return abi.encodePacked(uint8(0x80 + data.length), data);
        } else {
            revert("String too long");
        }
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

        // // 添加 deposit（0.1 ETH）
        // paymaster.deposit{value: 0.1 ether}();
        // console.log("Added 0.1 ETH deposit");

        // 如果还没有 stake，添加 stake
        IStakeManager.DepositInfo memory info = entryPoint.getDepositInfo(address(paymaster));
        if (info.stake == 0) {
            paymaster.addStake{value: 1 ether}(86400); // 1 day
            console.log("Added 1 ETH stake with 1 day unlock delay");
        }
        vm.stopBroadcast();

        console.log("New Deposit:", entryPoint.balanceOf(address(paymaster)));
        console.log("Success!");
    }

    /**
     * @notice 配置 Paymaster
     * @dev forge script script/TestnetInteraction.s.sol:TestnetInteraction --sig "configurePaymaster()" --rpc-url sepolia --broadcast
     */
    function configurePaymaster() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 paymasterPrivateKey = vm.envUint("PAYMASTER_PRIVATE_KEY");

        console.log("=== Configuring Paymaster ===");

        vm.startBroadcast(deployerPrivateKey);

        paymaster.setVerifyingSigner(vm.addr(paymasterPrivateKey));

        // paymaster.setSignatureRequired(true);

        // // 设置每笔操作最大gas花费（0.02 ETH）
        // paymaster.setMaxGasCostPerOp(0.02 ether);
        // console.log("Max gas cost per op set to 0.02 ETH");

        // 设置每天最大赞助次数
        // paymaster.setMaxSponsorshipPerDay(10);
        // console.log("Max sponsorship per day set to 10");

        vm.stopBroadcast();

        console.log("Success!");
    }

    function _createSimpleAccountInitCode(address owner) internal view returns (bytes memory) {
        return
            abi.encodePacked(address(factory), abi.encodeWithSignature("createAccount(address,uint256)", owner, salt));
    }
}
