// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC1155Holder, IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC721Holder, IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {BaseAccount, UserOperation, IAccount} from "@account-abstraction/contracts/core/BaseAccount.sol";
import {IEntryPoint, IEntryPointBase} from "./interfaces/IEntryPoint.sol";

// v0.7: SIG_VALIDATION constants are in BaseAccount
uint256 constant SIG_VALIDATION_FAILED = 1;
uint256 constant SIG_VALIDATION_SUCCESS = 0;

/**
 * @title SimpleEIP7702Account
 * @dev EIP-7702 委托合约，owner 始终是当前的 EOA 地址
 */
contract SimpleEIP7702Account is BaseAccount, ERC1155Holder, ERC721Holder, IERC1271 {
    IEntryPoint private immutable ENTRY_POINT;

    // EOA 地址 => 实际 owner 地址的映射（支持所有权转移）
    mapping(address => address) private _owners;

    error NotFromEntryPoint(address msgSender, address entity, address entryPoint);
    error NotAuthorized(address caller, address required);

    event OwnershipTransferred(address indexed eoa, address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    constructor(IEntryPoint anEntryPoint) {
        ENTRY_POINT = anEntryPoint;
    }

    // accept incoming calls (with or without value), to mimic an EOA.
    fallback() external payable {}
    // 使用EntryPoint退款时需要此函数
    receive() external payable {}

    /**
     * @notice 获取当前 EOA 的 owner
     * @dev 如果未设置，默认为 EOA 本身
     */
    function owner() public view returns (address) {
        address currentOwner = _owners[address(this)];
        return currentOwner == address(0) ? address(this) : currentOwner;
    }

    /**
     * @notice 转移当前 EOA 的所有权
     * @param newOwner 新的 owner 地址
     */
    function transferOwnership(address newOwner) public {
        require(msg.sender == owner(), "Only owner can transfer");
        require(newOwner != address(0), "New owner cannot be zero");

        address oldOwner = owner();
        _owners[address(this)] = newOwner;

        emit OwnershipTransferred(address(this), oldOwner, newOwner);
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) public virtual onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(address dest, uint256 value, bytes calldata func) external {
        _requireForExecute();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external {
        _requireForExecute();
        require(dest.length == func.length && dest.length == value.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    /**
     * Return the account nonce.
     * This method returns the next sequential nonce.
     * For a nonce of a specific key, use `entrypoint.getNonce(account, key)`
     */
    function nonce() public view virtual override returns (uint256) {
        return ENTRY_POINT.getNonce(address(this), 0);
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override(BaseAccount) returns (IEntryPointBase) {
        return IEntryPointBase(ENTRY_POINT);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view virtual returns (bytes4 magicValue) {
        return _checkSignature(hash, signature) ? this.isValidSignature.selector : bytes4(0xffffffff);
    }

    function supportsInterface(bytes4 id) public pure virtual override(ERC1155Holder) returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IAccount).interfaceId || id == type(IERC1271).interfaceId
            || id == type(IERC1155Receiver).interfaceId || id == type(IERC721Receiver).interfaceId;
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal virtual override {
        // Nonce is managed by EntryPointViaNonceManager
        // Alchemy 版的 EntryPoint 会调用 EntryPointViaNonceManager.validateAndUpdateNonce()
        // 因此这里不需要再验证和更新 nonce 了
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrOwner() internal view {
        require(msg.sender == address(entryPoint()) || msg.sender == address(this), "account: not Owner or EntryPoint");
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        return _checkSignature(userOpHash, userOp.signature) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    function _checkSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        return address(this) == ECDSA.recover(hash, signature);
    }

    function _requireForExecute() internal view virtual {
        require(
            msg.sender == owner() || msg.sender == address(entryPoint()),
            NotFromEntryPoint(msg.sender, address(this), address(entryPoint()))
        );
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _onlyOwner() internal view {
        require(msg.sender == owner() || msg.sender == address(this), NotAuthorized(msg.sender, owner()));
    }
}

