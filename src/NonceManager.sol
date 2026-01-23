// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {INonceManager} from "./interfaces/INonceManager.sol";

/**
 * @title NonceManager
 * @notice Nonce management functionality for account abstraction
 * @dev Provides multi-sequence nonce support for accounts
 *
 * Nonce Structure:
 * - High 192 bits: key (allows multiple independent nonce sequences)
 * - Low 64 bits: sequence number
 *
 * This allows accounts to have parallel transaction streams without blocking.
 */
contract NonceManager is INonceManager {
    /**
     * @notice The next valid sequence number for a given nonce key
     * @dev mapping: account address => nonce key => sequence number
     */
    mapping(address => mapping(uint192 => uint256)) public nonceSequenceNumber;

    /**
     * @notice Get the next valid nonce for an account
     * @dev Returns the full nonce (key in high bits, sequence in low bits)
     * @param sender The account address
     * @param key The nonce key (for multi-sequence nonces)
     * @return nonce The full nonce value
     */
    function getNonce(address sender, uint192 key) public view virtual returns (uint256 nonce) {
        return nonceSequenceNumber[sender][key] | (uint256(key) << 64);
    }

    /**
     * @notice Manually increment an account's nonce
     * @dev Allows accounts to skip nonces (e.g., for batch initialization)
     *      This is useful during account construction to make the first nonce non-zero,
     *      absorbing the gas cost of the first increment into the construction tx
     * @param key The nonce key to increment
     */
    function incrementNonce(uint192 key) public virtual {
        nonceSequenceNumber[msg.sender][key]++;
    }

    /**
     * @notice Validate nonce uniqueness for an account
     * @dev Called just after validateUserOp() to ensure nonce hasn't been used
     * @param sender The account address
     * @param nonce The full nonce value to validate
     * @return valid True if the nonce is valid and has been incremented
     */
    function _validateAndUpdateNonce(address sender, uint256 nonce) internal virtual returns (bool valid) {
        // forge-lint: disable-next-line(unsafe-typecast)
        uint192 key = uint192(nonce >> 64);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 seq = uint64(nonce);
        return nonceSequenceNumber[sender][key]++ == seq;
    }
}
