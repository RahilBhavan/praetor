// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PraetorGuard} from "../src/PraetorGuard.sol";

/// @notice Deploy the guard to Base Sepolia.
/// @dev TODO(phase1): wire policy config from the compiled spec + commit specHash.
contract Deploy is Script {
    function run() external returns (PraetorGuard guard) {
        vm.startBroadcast();
        guard = new PraetorGuard();
        vm.stopBroadcast();
    }
}
