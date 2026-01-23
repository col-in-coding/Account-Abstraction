// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {NonceManager} from "./NonceManager.sol";

/**
 * @title EntryPointViaNonceManager
 * @notice EntryPoint contract for Alchemy
 * @dev deployed on Sepolia at: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
 */
contract EntryPointViaNonceManager is EntryPoint, NonceManager {}
