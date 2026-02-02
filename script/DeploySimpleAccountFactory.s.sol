// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {SimpleAccountFactory} from "src/SimpleAccountFactory.sol";

contract DeploySimpleAccountFactory is Script {
    // EntryPoint v0.8 地址 - Sepolia
    IEntryPoint constant entryPoint = IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署 SimpleAccountFactory
        SimpleAccountFactory factory = new SimpleAccountFactory(entryPoint);
        console.log("SimpleAccountFactory deployed at:", address(factory));
        vm.stopBroadcast();

        console.log("Simple Account Factory Deployed At:", address(factory));
    }
}