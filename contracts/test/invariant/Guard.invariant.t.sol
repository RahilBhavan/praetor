// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @notice Handler-based invariant suite (plan §11.1). The "spec-is-law holds" proof.
/// @dev TODO(phase1): bounded actors + handler; assert:
///   - no out-of-allowlist call ever succeeds
///   - per-tx cap holds; rolling 24h cap holds
///   - rate limit holds; slippage holds (actualOut >= minOut)
///   - kill switch is absolute (while halted, every check() reverts)
contract GuardInvariant is Test {
// invariant_* assertions added in Phase 1.
}
