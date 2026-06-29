// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PraetorGuard} from "../src/PraetorGuard.sol";

/// @notice Unit tests for every revert path + happy path of the standalone guard (plan §11.1).
/// @dev The test contract is BOTH owner and account, so it configures the guard and calls check().
///      Errors that carry args use expectPartialRevert (selector-only match); parameterless errors
///      use expectRevert (exact 4-byte match).
contract PraetorGuardTest is Test {
    PraetorGuard internal guard;

    bytes32 internal constant SPEC_HASH = keccak256("praetor.spec.yaml@v1");
    address internal constant TARGET = address(0xA11CE);
    bytes4 internal constant SEL = bytes4(0x12345678); // allowlisted
    bytes4 internal constant SEL2 = bytes4(0xdeadbeef); // not allowlisted
    address internal constant RCPT = address(0xB0B); // allowlisted recipient
    address internal constant BADRCPT = address(0xBAD); // not allowlisted
    uint256 internal constant PER_TX = 5_000e8;
    uint256 internal constant ROLLING = 25_000e8;
    uint16 internal constant SLIP = 50; // 0.50%
    uint16 internal constant RATE = 20;

    event Executed(bytes32 indexed specHash, address target, bytes4 selector);

    function setUp() public {
        guard = new PraetorGuard(address(this), address(this));
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, SLIP, RATE);
        guard.setAllowed(TARGET, SEL, true);
        guard.setRecipient(RCPT, true);
        guard.setHalted(false);
        vm.warp(1_000_000); // a non-zero, mid-bucket start
    }

    // non-transfer (recipient 0), non-swap (quotedOut 0) call of `v` USD
    function _exec(uint256 v) internal returns (bool) {
        return guard.check(TARGET, SEL, v, address(0), 0, 0);
    }

    // ----------------------------- happy path -----------------------------
    function test_check_happy_executes_returnsTrue() public {
        vm.expectEmit(true, false, false, true, address(guard));
        emit Executed(SPEC_HASH, TARGET, SEL);
        assertTrue(_exec(PER_TX));
    }

    // ----------------------------- allowlist ------------------------------
    function test_check_revert_targetNotAllowlisted() public {
        vm.expectPartialRevert(PraetorGuard.TargetNotAllowed.selector);
        guard.check(address(0xBEEF), SEL, 1e8, address(0), 0, 0);
    }

    function test_check_revert_allowlistedTarget_wrongSelector() public {
        vm.expectPartialRevert(PraetorGuard.TargetNotAllowed.selector);
        guard.check(TARGET, SEL2, 1e8, address(0), 0, 0);
    }

    function test_check_revert_fallbackSelectorNotAllowed() public {
        vm.expectPartialRevert(PraetorGuard.TargetNotAllowed.selector);
        guard.check(TARGET, bytes4(0x00000000), 1e8, address(0), 0, 0);
    }

    // ----------------------------- recipient ------------------------------
    function test_check_revert_recipientNotAllowed() public {
        vm.expectPartialRevert(PraetorGuard.RecipientNotAllowed.selector);
        guard.check(TARGET, SEL, 1e8, BADRCPT, 0, 0);
    }

    function test_check_recipientZero_skipsRecipientCheck() public {
        assertTrue(guard.check(TARGET, SEL, 1e8, address(0), 0, 0));
    }

    function test_check_allowlistedRecipient_passes() public {
        assertTrue(guard.check(TARGET, SEL, 1e8, RCPT, 0, 0));
    }

    // ----------------------------- per-tx cap -----------------------------
    function test_check_revert_perTxCapExceeded() public {
        vm.expectPartialRevert(PraetorGuard.PerTxCapExceeded.selector);
        _exec(PER_TX + 1);
    }

    function test_check_boundary_perTxCapExact() public {
        assertTrue(_exec(PER_TX));
    }

    function testFuzz_perTxCap(uint256 v) public {
        v = bound(v, 0, 2 * PER_TX); // 2*PER_TX < ROLLING so only the per-tx cap gates
        if (v <= PER_TX) {
            assertTrue(_exec(v));
        } else {
            vm.expectPartialRevert(PraetorGuard.PerTxCapExceeded.selector);
            _exec(v);
        }
    }

    // --------------------------- rolling 24h ------------------------------
    function test_check_revert_rolling24hExceeded() public {
        for (uint256 i; i < 5; i++) {
            assertTrue(_exec(PER_TX)); // 5 * 5000 = 25000 == cap (projected == cap allowed)
        }
        vm.expectPartialRevert(PraetorGuard.RollingCapExceeded.selector);
        _exec(1); // projected 25000e8 + 1 > cap
    }

    function test_check_rolling24h_evictsAfterWindow() public {
        for (uint256 i; i < 5; i++) {
            assertTrue(_exec(PER_TX)); // fill to cap
        }
        vm.warp(block.timestamp + 24 hours + 1); // all 5 entries now strictly older than WINDOW
        assertTrue(_exec(PER_TX)); // evicted => succeeds
    }

    function test_check_rolling24h_doubleSpendBoundary() public {
        for (uint256 i; i < 5; i++) {
            assertTrue(_exec(PER_TX)); // spend full cap at t
        }
        vm.warp(block.timestamp + 24 hours - 1); // still inside the window
        vm.expectPartialRevert(PraetorGuard.RollingCapExceeded.selector);
        _exec(PER_TX); // sliding window blocks the within-window double-spend
    }

    // ------------------------------- rate ---------------------------------
    function test_check_revert_rateLimitExceeded() public {
        for (uint256 i; i < RATE; i++) {
            assertTrue(_exec(1e8));
        }
        vm.expectPartialRevert(PraetorGuard.RateLimited.selector);
        _exec(1e8); // (RATE+1)th in the same hour bucket
    }

    function test_check_rateLimit_resetsNextBucket() public {
        for (uint256 i; i < RATE; i++) {
            assertTrue(_exec(1e8));
        }
        vm.warp(block.timestamp + 1 hours);
        assertTrue(_exec(1e8)); // new bucket => counter reset
    }

    // ----------------------------- slippage -------------------------------
    function test_check_revert_slippageTooLoose() public {
        // quotedOut 1000, 0.50% => floor 995; minOut 994 < floor
        vm.expectPartialRevert(PraetorGuard.SlippageTooLoose.selector);
        guard.check(TARGET, SEL, 1e8, address(0), 994, 1000);
    }

    function test_check_boundary_slippageExact() public {
        assertTrue(guard.check(TARGET, SEL, 1e8, address(0), 995, 1000)); // minOut == floor
    }

    function test_check_slippage_skippedWhenQuotedZero() public {
        // KNOWN GAP (C4): quotedOut==0 disables slippage. A compromised agent could pass 0 on a real
        // swap. Closed by the deferred hook which decodes call-class and requires quotedOut>0.
        assertTrue(guard.check(TARGET, SEL, 1e8, address(0), 0, 0));
    }

    function testFuzz_slippage(uint256 quotedOut, uint256 minOut) public {
        quotedOut = bound(quotedOut, 1, 1e30);
        minOut = bound(minOut, 0, 1e30);
        uint256 floor = quotedOut - (quotedOut * SLIP) / 10000;
        if (minOut >= floor) {
            assertTrue(guard.check(TARGET, SEL, 1e8, address(0), minOut, quotedOut));
        } else {
            vm.expectPartialRevert(PraetorGuard.SlippageTooLoose.selector);
            guard.check(TARGET, SEL, 1e8, address(0), minOut, quotedOut);
        }
    }

    // ---------------------------- kill switch -----------------------------
    function test_check_revert_whenHalted() public {
        guard.setHalted(true);
        vm.expectRevert(PraetorGuard.Halted.selector);
        _exec(1e8);
    }

    function test_check_resumesAfterUnhalt() public {
        guard.setHalted(true);
        guard.setHalted(false);
        assertTrue(_exec(1e8));
    }

    // ------------------------------- auth ---------------------------------
    function test_check_revert_notAccount() public {
        vm.expectRevert(PraetorGuard.NotAccount.selector);
        vm.prank(address(0xE0A));
        _exec(1e8);
    }

    function test_setHalted_revert_notOwner() public {
        vm.expectRevert(PraetorGuard.NotOwner.selector);
        vm.prank(address(0xE0A));
        guard.setHalted(true);
    }

    function test_setPolicy_revert_notOwner() public {
        vm.expectRevert(PraetorGuard.NotOwner.selector);
        vm.prank(address(0xE0A));
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, SLIP, RATE);
    }

    function test_setAllowed_revert_notOwner() public {
        vm.expectRevert(PraetorGuard.NotOwner.selector);
        vm.prank(address(0xE0A));
        guard.setAllowed(TARGET, SEL, true);
    }

    // --------------------------- config guards ----------------------------
    function test_setPolicy_revert_slippageBpsGt10000() public {
        vm.expectPartialRevert(PraetorGuard.SlippageBpsTooHigh.selector);
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, 10001, RATE);
    }

    function test_setPolicy_revert_rateTimesBufferExceedsN() public {
        // N = 512; a sliding 24h window touches 25 hour buckets, so 21*25 = 525 > 512 (false-block risk)
        vm.expectPartialRevert(PraetorGuard.RateTooHighForBuffer.selector);
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, SLIP, 21);
    }

    function test_setPolicy_boundary_rateTimesBufferAtN() public {
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, SLIP, 20); // 20*25 = 500 <= 512
        (,,,, uint16 maxTph,) = guard.policy();
        assertEq(maxTph, 20);
    }

    function test_setPolicy_revert_perTxCapTooHigh() public {
        vm.expectPartialRevert(PraetorGuard.PerTxCapTooHigh.selector);
        guard.setPolicy(SPEC_HASH, uint256(type(uint192).max) + 1, ROLLING, SLIP, RATE);
    }

    // --------------------------- ownership --------------------------------
    function test_transferOwnership_revert_zeroAddress() public {
        vm.expectRevert(PraetorGuard.ZeroAddress.selector);
        guard.transferOwnership(address(0));
    }

    function test_transferOwnership_movesOwner() public {
        guard.transferOwnership(address(0xCAFE));
        assertEq(guard.owner(), address(0xCAFE));
    }

    function test_noRenounceFunctionExists() public {
        // a safety device must never be brick-able: there is no renounceOwnership selector to call
        (bool ok,) = address(guard).call(abi.encodeWithSignature("renounceOwnership()"));
        assertFalse(ok);
    }
}
