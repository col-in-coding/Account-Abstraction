// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {SimpleAccountFactory} from "../src/SimpleAccountFactory.sol";
import {SimplePaymaster} from "../src/SimplePaymaster.sol";

contract Deployment is Script {
    // Sepolia EntryPoint v0.7 地址
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署 SimpleAccountFactory
        SimpleAccountFactory factory = new SimpleAccountFactory(ENTRY_POINT);
        console.log("SimpleAccountFactory deployed at:", address(factory));

        // 部署 SimplePaymaster
        SimplePaymaster paymaster = new SimplePaymaster(ENTRY_POINT);
        console.log("SimplePaymaster deployed at:", address(paymaster));

        // // 给 paymaster 质押和充值
        // paymaster.addStake{value: 0.1 ether}(1 days);
        // paymaster.deposit{value: 0.5 ether}();
        // console.log("Paymaster staked and deposited");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia");
        console.log("EntryPoint:", ENTRY_POINT);
        console.log("Factory:", address(factory));
        console.log("Paymaster:", address(paymaster));
    }
}
