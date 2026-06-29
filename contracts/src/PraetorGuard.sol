// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPraetorGuard
/// @notice Minimal policy guard (plan §6.1), refined for the standalone Phase-1 build (ADR-0004).
/// @dev A block is a REVERT carried as a typed custom error: a reverting call discards its logs,
///      so the §6.1 `Blocked` event is unimplementable on-chain and is dropped. `Executed` is the
///      one durable on-chain audit event, emitted only on the success path. The deferred ERC-7579
///      hook re-surfaces blocks via a try/catch frame that does not roll back.
///
///      TRUST BOUNDARY (standalone): `check()` trusts its caller (the authorized `account`) to pass
///      honest `valueUsd`/`quotedOut`. The production ERC-7579 hook (deferred) decodes real calldata
///      and prices via ChainlinkPriceAdapter so the *account*, not the agent, supplies these. The
///      Foundry invariant suite proves enforcement GIVEN the inputs. See docs/threat-model.md.
interface IPraetorGuard {
    struct Policy {
        bytes32 specHash; // commits which spec is in force
        uint256 perTxUsd; // 1e8 fixed-point USD
        uint256 rolling24hUsd; // 1e8 fixed-point USD
        uint16 maxSlippageBps;
        uint16 maxTxPerHour;
        bool halted; // circuit breaker
    }

    /// @dev called by the account before executing a call. State-mutating (accrues the rolling-24h
    ///      ring buffer + rate bucket). Returns true on success; reverts with a typed error otherwise.
    /// @param recipient address(0) = non-transfer (recipient check skipped)
    /// @param quotedOut 0 = non-swap (slippage check skipped)
    function check(
        address target,
        bytes4 selector,
        uint256 valueUsd,
        address recipient,
        uint256 minOut,
        uint256 quotedOut
    ) external returns (bool);

    function setHalted(bool halted) external; // kill switch (owner only)
    function isAllowed(address target, bytes4 selector) external view returns (bool);
    function isRecipientAllowed(address recipient) external view returns (bool);

    event Executed(bytes32 indexed specHash, address target, bytes4 selector);
}

/// @notice Standalone policy guard. Reverts any out-of-spec call.
contract PraetorGuard is IPraetorGuard {
    // ---- blocks are reverts (typed errors line up with engine BlockCodes) ----
    error NotOwner();
    error NotAccount();
    error ZeroAddress();
    error Halted();
    error TargetNotAllowed(address target, bytes4 selector);
    error RecipientNotAllowed(address recipient);
    error PerTxCapExceeded(uint256 valueUsd, uint256 cap);
    error SlippageTooLoose(uint256 minOut, uint256 floor);
    error RateLimited(uint256 attempted, uint256 cap);
    error RollingCapExceeded(uint256 projected, uint256 cap);
    error RollingBufferFull(); // fail-closed backstop; provably unreachable given setPolicy invariant
    error SlippageBpsTooHigh(uint16 bps);
    error RateTooHighForBuffer(uint16 maxTxPerHour);
    error PerTxCapTooHigh(uint256 cap);

    // ---- config audit trail ----
    event PolicyUpdated(bytes32 indexed specHash);
    event AllowSet(address indexed target, bytes4 indexed selector, bool allowed);
    event RecipientSet(address indexed recipient, bool allowed);
    event OwnershipTransferred(address indexed from, address indexed to);
    event AccountSet(address indexed account);
    event HaltSet(bool halted);

    // ---- ownership / auth ----
    address public owner; // configures the guard (and trips the kill switch)
    address public account; // the sole authorized caller of check() — closes a state-poisoning DoS

    // ---- policy + allowlists ----
    Policy public policy;
    mapping(address target => mapping(bytes4 selector => bool)) private _allowed;
    mapping(address recipient => bool) private _recipientAllowed;

    // ---- rolling-24h notional: fixed ring buffer, O(1) running sum ----
    uint256 private constant WINDOW = 24 hours;
    uint256 private constant N = 512; // >= 25*maxTxPerHour (a sliding 24h window touches 25 hour buckets); enforced in setPolicy

    struct Entry {
        uint64 ts;
        uint192 usd; // 1e8 USD; <= perTxUsd <= type(uint192).max (enforced in setPolicy) => cast is lossless
    }

    Entry[N] private _ring;
    uint256 private _head; // next write slot
    uint256 private _count; // live entries
    uint256 private _runningSum; // Σ live entries (1e8 USD)

    // ---- rate limiter: coarse fixed wall-clock hour buckets (block.timestamp/3600) ----
    uint256 private _hourBucket;
    uint256 private _txInBucket;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAccount() {
        if (msg.sender != account) revert NotAccount();
        _;
    }

    /// @param owner_ configures the guard; cannot be zero. There is deliberately NO renounceOwnership:
    ///        a safety device must never be brick-able.
    /// @param account_ the authorized check() caller (may be set later via setAccount).
    constructor(address owner_, address account_) {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        account = account_;
        policy.halted = true; // fail-closed until the owner commits config and unhalts
        emit OwnershipTransferred(address(0), owner_);
        emit AccountSet(account_);
    }

    // =========================================================================
    // check() — the centerpiece. Cheapest/most-fundamental rejects first; ALL
    // pure validations before ANY state mutation. Every failure reverts.
    // =========================================================================
    function check(
        address target,
        bytes4 selector,
        uint256 valueUsd,
        address recipient,
        uint256 minOut,
        uint256 quotedOut
    ) external onlyAccount returns (bool) {
        // 1. kill switch — first statement, before any accrual or mutable-state SLOAD
        if (policy.halted) revert Halted();
        // 2. allowlist (fail-closed; also catches un-allowlisted approve / fallback 0x00000000)
        if (!_allowed[target][selector]) revert TargetNotAllowed(target, selector);
        // 3. recipient (transfer-class only; address(0) = non-transfer sentinel)
        if (recipient != address(0) && !_recipientAllowed[recipient]) revert RecipientNotAllowed(recipient);
        // 4. per-tx cap (strict >, so valueUsd == cap is allowed)
        if (valueUsd > policy.perTxUsd) revert PerTxCapExceeded(valueUsd, policy.perTxUsd);
        // 5. slippage floor (swap-class only; quotedOut == 0 = non-swap sentinel).
        //    bps <= 10000 enforced at config time => 10000 - bps never underflows here.
        if (quotedOut > 0) {
            uint256 floor = quotedOut - (quotedOut * policy.maxSlippageBps) / 10000;
            if (minOut < floor) revert SlippageTooLoose(minOut, floor);
        }
        // 6. rate limit (coarse fixed hour bucket)
        uint256 b = block.timestamp / 3600;
        uint256 n = (b == _hourBucket) ? _txInBucket + 1 : 1;
        if (n > policy.maxTxPerHour) revert RateLimited(n, policy.maxTxPerHour);
        // 7. rolling 24h (true sliding window via ring eviction)
        _expire();
        uint256 projected = _runningSum + valueUsd;
        if (projected > policy.rolling24hUsd) revert RollingCapExceeded(projected, policy.rolling24hUsd);

        // ---- commit (only reached if every check passed) ----
        if (b != _hourBucket) {
            _hourBucket = b;
            _txInBucket = 1;
        } else {
            _txInBucket = n;
        }
        _push(uint192(valueUsd));
        emit Executed(policy.specHash, target, selector);
        return true; // vestigial (every failure reverts) — kept for `require(guard.check(...))`
    }

    /// @dev Evict entries strictly older than WINDOW (an entry exactly 24h old still counts =>
    ///      stricter => fail-closed). block.timestamp >= ts always, so no underflow.
    function _expire() private {
        uint256 nowTs = block.timestamp;
        uint256 oldest = (_head + N - _count) % N;
        while (_count > 0 && nowTs - _ring[oldest].ts > WINDOW) {
            _runningSum -= _ring[oldest].usd;
            oldest = (oldest + 1) % N;
            unchecked {
                --_count;
            }
        }
    }

    function _push(uint192 usd) private {
        if (_count == N) revert RollingBufferFull();
        _ring[_head] = Entry(uint64(block.timestamp), usd);
        _head = (_head + 1) % N;
        unchecked {
            ++_count;
        }
        _runningSum += usd;
    }

    // ============================== config (owner) ==============================
    function setHalted(bool h) external onlyOwner {
        policy.halted = h;
        emit HaltSet(h);
    }

    /// @dev Validates the two structural invariants the hot path relies on:
    ///      maxSlippageBps <= 10000 (else 10000-bps underflows and bricks every swap) and
    ///      25*maxTxPerHour <= N (else the ring can fill and RollingBufferFull becomes reachable).
    ///      Does NOT touch `halted`.
    function setPolicy(
        bytes32 specHash_,
        uint256 perTxUsd_,
        uint256 rolling24hUsd_,
        uint16 maxSlippageBps_,
        uint16 maxTxPerHour_
    ) external onlyOwner {
        if (maxSlippageBps_ > 10000) revert SlippageBpsTooHigh(maxSlippageBps_);
        // A trailing 24h SLIDING window straddles hour-bucket boundaries and touches up to 25 fixed
        // buckets (k-24..k), each admitting maxTxPerHour entries => up to 25*maxTxPerHour live
        // entries. Bounding by 25 (not 24) keeps the ring from ever filling — RollingBufferFull
        // stays unreachable even under a sustained max-rate burst across a bucket boundary.
        if (uint256(maxTxPerHour_) * 25 > N) revert RateTooHighForBuffer(maxTxPerHour_);
        if (perTxUsd_ > type(uint192).max) revert PerTxCapTooHigh(perTxUsd_);
        policy.specHash = specHash_;
        policy.perTxUsd = perTxUsd_;
        policy.rolling24hUsd = rolling24hUsd_;
        policy.maxSlippageBps = maxSlippageBps_;
        policy.maxTxPerHour = maxTxPerHour_;
        emit PolicyUpdated(specHash_);
    }

    function setAllowed(address target, bytes4 selector, bool allowed) external onlyOwner {
        _allowed[target][selector] = allowed;
        emit AllowSet(target, selector, allowed);
    }

    function setRecipient(address recipient, bool allowed) external onlyOwner {
        _recipientAllowed[recipient] = allowed;
        emit RecipientSet(recipient, allowed);
    }

    function setAccount(address account_) external onlyOwner {
        account = account_;
        emit AccountSet(account_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    // NB: intentionally no renounceOwnership — the kill switch must never become unreachable.

    // ============================== views ==============================
    function isAllowed(address target, bytes4 selector) external view returns (bool) {
        return _allowed[target][selector];
    }

    function isRecipientAllowed(address recipient) external view returns (bool) {
        return _recipientAllowed[recipient];
    }
}
