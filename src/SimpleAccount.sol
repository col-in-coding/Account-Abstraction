// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {BaseAccount, IEntryPoint, PackedUserOperation, SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/BaseAccount.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "@account-abstraction/contracts/core/Helpers.sol";
import {TokenCallbackHandler} from "@account-abstraction/contracts/accounts/callback/TokenCallbackHandler.sol";
import {ISimpleAccount} from "./interfaces/ISimpleAccount.sol";

/**
 * @title SimpleAccount
 * @dev 简单的智能合约账户实现
 */
contract SimpleAccount is BaseAccount, TokenCallbackHandler, UUPSUpgradeable, Initializable, ISimpleAccount {

    address public owner;
    IEntryPoint private immutable ENTRY_POINT;

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    constructor(IEntryPoint anEntryPoint) {
        ENTRY_POINT = anEntryPoint;
        _disableInitializers();
    }

    receive() external payable {}

    /**
     * @dev The ENTRY_POINT member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
      * the implementation by calling `upgradeTo()`
      * @param anOwner the owner (signer) of this account
     */
    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override(BaseAccount, ISimpleAccount) returns (IEntryPoint) {
        return ENTRY_POINT;
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
     * check current account deposit in the entryPoint
     */
    function getDeposit() public virtual view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    function _onlyOwner() internal view {
        // Directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            msg.sender == owner || msg.sender == address(this),
            NotOwner(
                msg.sender,
                address(this),
                owner
            )
        );
    }

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit SimpleAccountInitialized(entryPoint(), owner);
    }

    // Require the function call went through EntryPoint or owner
    function _requireForExecute() internal view override virtual {
        require(msg.sender == address(entryPoint()) || msg.sender == owner,
            NotOwnerOrEntryPoint(
                msg.sender,
                address(this),
                address(entryPoint()),
                owner
            )
        );
    }

    /// implement template method of BaseAccount
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
    internal override virtual returns (uint256 validationData) {

        // UserOpHash can be generated using eth_signTypedData_v4
        if (owner != ECDSA.recover(userOpHash, userOp.signature))
            return SIG_VALIDATION_FAILED;
        return SIG_VALIDATION_SUCCESS;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _onlyOwner();
    }
}

