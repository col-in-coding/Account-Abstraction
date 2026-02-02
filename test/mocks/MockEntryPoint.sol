// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISenderCreator} from "@account-abstraction/contracts/interfaces/ISenderCreator.sol";

/**
 * @title MockEntryPoint
 * @dev Minimal mock for testing purposes
 */
contract MockEntryPoint {
    mapping(address => uint256) private _balances;
    ISenderCreator private _senderCreator;

    constructor() {
        _senderCreator = new MockSenderCreator();
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function depositTo(address account) external payable {
        _balances[account] += msg.value;
    }

    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external {
        require(_balances[msg.sender] >= withdrawAmount, "insufficient balance");
        _balances[msg.sender] -= withdrawAmount;
        withdrawAddress.transfer(withdrawAmount);
    }

    function senderCreator() external view returns (ISenderCreator) {
        return _senderCreator;
    }
}

contract MockSenderCreator is ISenderCreator {
    function createSender(bytes calldata) external pure override returns (address) {
        return address(0);
    }

    function initEip7702Sender(address, bytes calldata) external pure override {
        // Mock implementation - do nothing
    }
}