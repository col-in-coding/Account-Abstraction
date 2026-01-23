// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IEntryPoint as IEntryPointBase} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {INonceManager} from "./INonceManager.sol";

/**
 * @title IEntryPoint
 * @notice Extended EntryPoint interface with NonceManager support
 * @dev Combines standard IEntryPoint with NonceManager functionality (Alchemy-compatible)
 */
interface IEntryPoint is IEntryPointBase, INonceManager {}
