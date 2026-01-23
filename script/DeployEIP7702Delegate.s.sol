// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimpleEIP7702Account} from "../src/SimpleEIP7702Account.sol";
import {IEntryPoint} from "../src/interfaces/IEntryPoint.sol";

contract DeployEIP7702Delegate is Script {
    // Sepolia EntryPoint v0.6 地址
    address constant ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        address delegate = address(new SimpleEIP7702Account(IEntryPoint(ENTRY_POINT)));
        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia");
        console.log("SimpleEIP7702Account:", delegate);
    }
}
