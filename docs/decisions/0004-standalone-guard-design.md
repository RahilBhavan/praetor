# ADR-0004 — Phase-1 standalone guard: blocks-as-reverts, owner-mutable config, onlyAccount

- Status: Accepted
- Date: 2026-06-29
- Plan refs: §6.1 (interface — explicitly "illustrative"), §5.5 (versioning), §11.1 (invariants)
- Supersedes nothing; refines the §6.1 interface sketch for the from-scratch build (ADR-0002).

## Context

Phase 1 builds the guard standalone (ADR-0001 chose ZeroDev Kernel ERC-7579; the real
`IHook` wrapper with calldata decoding is deferred to a later phase where it can be
integration-tested against a live Kernel — the standalone guard is the credibility artifact
and the invariant suite is its proof). Implementing the `check()` interface surfaced three
decisions the plan's "illustrative" sketch did not resolve. Each was forced, not stylistic.

## Decisions

### 1. Blocks are typed custom-error REVERTS; drop the `Blocked` event

The §6.1 interface declares `event Blocked(specHash, target, selector, reason)` emitted on a
block. This is unimplementable on-chain: **a reverting call discards all its logs**, so a
`Blocked` event emitted immediately before a revert never gets mined, and a non-reverting
call is by definition not a block.

- Blocks revert with **typed custom errors** (`TargetNotAllowed`, `PerTxCapExceeded`,
  `RateLimited`, …) — cheaper than a `string reason`, carry typed offending values, and the
  revert data is decodable offline from the failed-tx trace.
- `event Executed(specHash, target, selector)` is **kept**, emitted only on the success path
  — the one durable on-chain audit event this phase.
- The on-chain audit log of **blocks** moves to the deferred ERC-7579 hook, which calls
  `guard.check()` inside a `try/catch` and emits `Blocked` from a frame that does not roll back.

Deviation from CLAUDE.md "emit Blocked/Executed — events are the audit log": only `Executed`
is a reliable on-chain event this phase; the block audit log = revert data + engine JSONL now,
+ the hook's `Blocked` later.

### 2. Config is owner-mutable (not immutable-per-deployment)

Plan §5.5 (MVP) leans "spec immutable per deployment; change = redeploy + commit new
spec_hash." But §6.1 already exposes owner-only `setHalted`, and the invariant suite cannot
configure a guard with no setters. The guard therefore has owner-only `setPolicy`,
`setAllowed`, `setRecipient`, `setAccount`, `setHalted` + single-step `transferOwnership`
(rejects `address(0)`; **no `renounceOwnership`** — the kill switch must never be brick-able).

`specHash` honesty is kept off-chain: CI cross-checks the on-chain `specHash` against
`keccak256(canonicalized praetor.spec.yaml)`. **Upgrade path (deferred):** gate config setters
behind `halted` (halt → reconfigure → commit → unhalt) for a hard on-chain spec commitment.

### 3. `check()` is restricted to one owner-set `account` (`onlyAccount`)

`check()` mutates the rolling-24h ring buffer and the rate bucket. An open caller could spam
`check()` with large `valueUsd` and **poison those accumulators**, forcing false-blocks on the
real account — a violation of the zero-false-block release gate (CLAUDE.md rule #7). So
`check()` is callable only by a single owner-set `account` (`setAccount`). The deploy script
sets it to the agent smart account; tests set it to the handler.

### Supporting

- `check()` is **state-mutating** (the §6.1 stub was `pure` — wrong); the engine's preview path
  is the TS mirror, not an on-chain `staticcall`.
- Rolling-24h is a **true sliding window** (fixed ring buffer `N=512`, O(1) running sum, evict
  when `now−ts > WINDOW`), not a fixed 24h bucket (which would allow 2× the cap across a
  boundary). `setPolicy` enforces `maxTxPerHour*24 <= N`, making `RollingBufferFull` unreachable.

## Consequences / trust boundary

The standalone guard trusts its (authorized) `account` to pass honest `valueUsd`/`quotedOut`,
and uses sentinels: `recipient==address(0)` = non-transfer (skip recipient check),
`quotedOut==0` = non-swap (skip slippage). These are **known gaps in the standalone layer**,
closed by the deferred ERC-7579 hook which decodes real calldata and prices via
`ChainlinkPriceAdapter` so the *account*, not the agent, supplies the inputs. The Foundry
invariant suite proves enforcement **given honest inputs** (plan §11.1). See `docs/threat-model.md`.
