// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {PraetorGuard} from "../../src/PraetorGuard.sol";

/// @notice Bounded actor that drives the guard. Holds owner + account roles so it can both call
///         check() and toggle the kill switch. NO assertions live here: fail_on_revert=false would
///         silently swallow them — every assert lives in GuardInvariant. Ghosts are independent
///         ground truth (the invariants never trust the guard's own internal accounting).
contract GuardHandler is Test {
    PraetorGuard public guard;
    uint256 internal constant WINDOW = 24 hours;

    // small fixed sets; index 0 = the allowlisted value, the rest are decoys
    address[3] internal targets;
    bytes4[3] internal selectors;
    address[3] internal recipients;

    // ---- ghosts ----
    bool public gIllegalExec; // an out-of-allowlist (target,selector,recipient) call ever executed
    uint256 public gMaxExecValue; // max executed valueUsd
    bool public gSlippageViolation; // an executed swap fell below the slippage floor
    bool public gHaltedExec; // a call executed while halted (kill switch broken)
    uint256 public gExecCount; // total executions (anti-vacuity)

    // rolling-24h ground truth: append-only, with a head cursor that drops permanently-dead entries
    uint256[] internal gTs;
    uint256[] internal gVal;
    uint256 internal gHead;

    // rate ground truth: per fixed-hour bucket count + running max
    mapping(uint256 bucket => uint256 count) public gBucketCount;
    uint256 public gMaxBucketCount;

    constructor(PraetorGuard guard_, address allowedTarget, bytes4 allowedSel, address allowedRcpt) {
        guard = guard_;
        targets = [allowedTarget, address(0xDEAD), address(0xBEEF)];
        selectors = [allowedSel, bytes4(0xdeadbeef), bytes4(0x00000000)];
        recipients = [address(0), allowedRcpt, address(0xBAD)];
    }

    function doCheck(uint256 tSeed, uint256 sSeed, uint256 valueUsd, uint256 rSeed, uint256 minOut, uint256 quotedOut)
        external
    {
        address t = targets[tSeed % 3];
        bytes4 s = selectors[sSeed % 3];
        address r = recipients[rSeed % 3];
        valueUsd = bound(valueUsd, 0, 8_000e8); // straddles perTxUsd; accumulation exercises the rolling cap
        quotedOut = bound(quotedOut, 0, 1e30); // bounded so quotedOut*10000 can't overflow & pollute results
        minOut = bound(minOut, 0, 1e30);

        _prune();
        (,,,,, bool halted) = guard.policy();

        try guard.check(t, s, valueUsd, r, minOut, quotedOut) {
            gExecCount++;
            if (halted) gHaltedExec = true;
            if (!guard.isAllowed(t, s) || (r != address(0) && !guard.isRecipientAllowed(r))) gIllegalExec = true;
            if (valueUsd > gMaxExecValue) gMaxExecValue = valueUsd;
            if (quotedOut > 0) {
                (,,, uint16 bps,,) = guard.policy();
                uint256 floor = quotedOut - (quotedOut * bps) / 10000;
                if (minOut < floor) gSlippageViolation = true;
            }
            // rolling ghost
            gTs.push(block.timestamp);
            gVal.push(valueUsd);
            // rate ghost (identical bucketing to the guard: block.timestamp / 3600)
            uint256 b = block.timestamp / 3600;
            uint256 c = ++gBucketCount[b];
            if (c > gMaxBucketCount) gMaxBucketCount = c;
        } catch {
            // blocked — expected for out-of-spec inputs
        }
    }

    function advanceTime(uint256 dt) external {
        dt = bound(dt, 1, 6 hours);
        vm.warp(block.timestamp + dt);
        _prune();
    }

    function toggleHalt(bool h) external {
        guard.setHalted(h); // handler holds the owner role
    }

    // drop permanently-dead leading entries (now-ts > WINDOW; time only advances => never re-enter)
    function _prune() internal {
        while (gHead < gTs.length && block.timestamp - gTs[gHead] > WINDOW) {
            gHead++;
        }
    }

    /// @notice independent trailing-24h sum (keep entry when now-ts <= WINDOW, mirroring the guard)
    function liveSum() external view returns (uint256 sum) {
        for (uint256 i = gHead; i < gTs.length; i++) {
            if (block.timestamp - gTs[i] <= WINDOW) sum += gVal[i];
        }
    }
}

/// @notice Handler-based stateful invariant suite — the "spec-is-law holds" proof (plan §11.1).
contract GuardInvariant is StdInvariant, Test {
    PraetorGuard internal guard;
    GuardHandler internal handler;

    bytes32 internal constant SPEC_HASH = keccak256("invariant.spec@v1");
    address internal constant TARGET = address(0xA11CE);
    bytes4 internal constant SEL = bytes4(0x12345678);
    address internal constant RCPT = address(0xB0B);
    uint256 internal constant PER_TX = 5_000e8;
    uint256 internal constant ROLLING = 25_000e8;
    uint16 internal constant SLIP = 50;
    uint16 internal constant RATE = 20;

    function setUp() public {
        vm.warp(1_000_000);
        guard = new PraetorGuard(address(this), address(this)); // test contract = initial owner
        guard.setPolicy(SPEC_HASH, PER_TX, ROLLING, SLIP, RATE);
        guard.setAllowed(TARGET, SEL, true);
        guard.setRecipient(RCPT, true);
        guard.setHalted(false);

        handler = new GuardHandler(guard, TARGET, SEL, RCPT);
        guard.setAccount(address(handler)); // only the handler may call check()
        guard.transferOwnership(address(handler)); // handler can toggle the kill switch

        bytes4[] memory sel = new bytes4[](3);
        sel[0] = GuardHandler.doCheck.selector;
        sel[1] = GuardHandler.advanceTime.selector;
        sel[2] = GuardHandler.toggleHalt.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sel}));
        targetContract(address(handler));
    }

    /// 1. no out-of-allowlist (target,selector,recipient) call ever executes
    function invariant_allowlist() public view {
        assertFalse(handler.gIllegalExec());
    }

    /// 2. every executed call had valueUsd <= perTxUsd
    function invariant_perTxCap() public view {
        (, uint256 perTx,,,,) = guard.policy();
        assertLe(handler.gMaxExecValue(), perTx);
    }

    /// 3. over the trailing 24h window, Σ executed valueUsd <= rolling24hUsd
    function invariant_rolling24h() public view {
        (,, uint256 cap,,,) = guard.policy();
        assertLe(handler.liveSum(), cap);
    }

    /// 4. no fixed hour bucket exceeds maxTxPerHour
    function invariant_rateLimit() public view {
        (,,,, uint16 maxTph,) = guard.policy();
        assertLe(handler.gMaxBucketCount(), maxTph);
    }

    /// 5. every executed swap respected the slippage floor
    function invariant_slippage() public view {
        assertFalse(handler.gSlippageViolation());
    }

    /// 6. while halted, nothing executes (the kill switch is absolute)
    function invariant_killSwitch() public view {
        assertFalse(handler.gHaltedExec());
    }

    /// Non-vacuity guard: proves the handler CAN drive executions, so the 6 invariants above are not
    /// vacuously true. A per-run afterInvariant(gExecCount>0) false-fails on unlucky sequences (e.g.
    /// one that only toggles the kill switch); this deterministic test is the robust form. Liveness is
    /// also covered by the happy-path asserts in PraetorGuard.t.sol.
    function test_handler_drivesExecutions() public {
        handler.doCheck(0, 0, 1_000e8, 0, 0, 0); // allowed (target,selector), non-transfer, under caps
        handler.doCheck(0, 0, 2_000e8, 1, 0, 0); // allowed recipient
        assertGt(handler.gExecCount(), 0);
    }
}
