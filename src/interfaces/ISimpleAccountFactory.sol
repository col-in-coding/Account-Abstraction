// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISimpleAccountFactory
 * @notice Interface for SimpleAccountFactory contract
 * @dev This interface defines all public functions and events for SimpleAccountFactory
 */
interface ISimpleAccountFactory {
    error NotSenderCreator(address msgSender, address entity, address senderCreator);

    // Core functionality - 保留重要的业务接口
    function accountImplementation() external view returns (address);

    // Account creation functions
    function createAccount(address owner, uint256 salt) external returns (address);

    // Address calculation
    function getAddress(address owner, uint256 salt) external view returns (address);
}
