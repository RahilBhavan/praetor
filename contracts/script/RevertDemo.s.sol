// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PraetorGuard} from "../src/PraetorGuard.sol";

/// @notice Self-contained revert demo (plan §9 Phase-1 deliverable). Runs entirely in the script
///         EVM (no broadcast, no RPC): pranks a fixed DEPLOYER as owner+account, configures a guard,
///         then shows an in-spec call EXECUTING and an out-of-allowlist call REVERTING with
///         TargetNotAllowed. Run: forge script script/RevertDemo.s.sol -vv
contract RevertDemo is Script {
    address internal constant DEPLOYER = address(0xD0D0); // owner + authorized account
    address internal constant TARGET = address(0xA11CE);
    bytes4 internal constant SEL = bytes4(0x12345678);
    bytes32 internal constant SPEC_HASH = keccak256("demo.spec@v1");

    function run() external {
        vm.startPrank(DEPLOYER);
        PraetorGuard guard = new PraetorGuard(DEPLOYER, DEPLOYER);
        guard.setPolicy(SPEC_HASH, 5_000e8, 25_000e8, 50, 20);
        guard.setAllowed(TARGET, SEL, true);
        guard.setHalted(false);

        // 1. in-spec call -> executes
        bool ok = guard.check(TARGET, SEL, 1_000e8, address(0), 0, 0);
        console2.log("in-spec check executed:", ok);

        // 2. out-of-allowlist call -> reverts (un-bypassable backstop)
        try guard.check(address(0xBADBAD), SEL, 1_000e8, address(0), 0, 0) returns (bool) {
            revert("DEMO FAILED: out-of-allowlist call did NOT revert");
        } catch (bytes memory data) {
            require(bytes4(data) == PraetorGuard.TargetNotAllowed.selector, "unexpected revert reason");
            console2.log("out-of-allowlist call reverted with TargetNotAllowed (spec-is-law holds)");
        }
        vm.stopPrank();
    }
}
