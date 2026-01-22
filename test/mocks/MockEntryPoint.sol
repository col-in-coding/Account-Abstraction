// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title MockEntryPoint
 * @dev Minimal mock for testing purposes (v0.7 compatible)
 */
contract MockEntryPoint {
    mapping(address => uint256) private _balances;

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
}
