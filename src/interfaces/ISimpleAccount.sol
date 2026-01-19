// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title ISimpleAccount
 * @notice Interface for SimpleAccount contract
 * @dev This interface defines all public functions and events for SimpleAccount
 */
interface ISimpleAccount {
    // Events
    event SimpleAccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);

    // Custom Errors
    error NotOwner(address msgSender, address entity, address owner);
    error NotOwnerOrEntryPoint(address msgSender, address entity, address entryPoint, address owner);

    // State variables (view functions)
    function owner() external view returns (address);

    // From BaseAccount
    function entryPoint() external view returns (IEntryPoint);

    // Initialization
    function initialize(address anOwner) external;

    // Deposit management
    function getDeposit() external view returns (uint256);
    function addDeposit() external payable;
    function withdrawDepositTo(address payable withdrawAddress, uint256 amount) external;

    // Receive Ether
    receive() external payable;
}
