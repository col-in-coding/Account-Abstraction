// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ISimpleAccountFactory} from "./interfaces/ISimpleAccountFactory.sol";
import {SimpleAccount} from "./SimpleAccount.sol";

/**
 * A sample factory contract for SimpleAccount
 * A UserOperations "initCode" holds the address of the factory, and a method call (to createAccount, in this sample factory).
 * The factory's createAccount returns the target account address even if it is already installed.
 * This way, the entryPoint.getSenderAddress() can be called either before or after the account is created.
 */
contract SimpleAccountFactory is ISimpleAccountFactory {
    address private immutable ACCOUNT_IMPLEMENTATION;

    // Getter function to match interface
    function accountImplementation() external view override returns (address) {
        return ACCOUNT_IMPLEMENTATION;
    }

    constructor(address _entryPoint) {
        ACCOUNT_IMPLEMENTATION = address(new SimpleAccount(IEntryPoint(_entryPoint)));
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(address owner, uint256 salt) public returns (address) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return addr;
        }
        SimpleAccount ret = SimpleAccount(
            payable(new ERC1967Proxy{salt: bytes32(salt)}(
                    ACCOUNT_IMPLEMENTATION, abi.encodeCall(SimpleAccount.initialize, (owner))
                ))
        );
        return address(ret);
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(address owner, uint256 salt) public view virtual returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(ACCOUNT_IMPLEMENTATION, abi.encodeCall(SimpleAccount.initialize, (owner)))
                )
            )
        );
    }
}
