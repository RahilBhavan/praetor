// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PraetorGuard} from "../src/PraetorGuard.sol";

/// @notice Unit tests for the guard.
/// @dev TODO(phase1): allowlist / recipient / caps / slippage / rate / kill-switch
///      revert paths (plan §11.1). Requires `forge install foundry-rs/forge-std`.
contract PraetorGuardTest is Test {
    PraetorGuard internal guard;

    function setUp() public {
        guard = new PraetorGuard();
    }

    function test_skeleton_recipientNotAllowedByDefault() public view {
        assertFalse(guard.isRecipientAllowed(address(0xBEEF)));
    }
}
