# Praetor — Memory

## 2026-06-29 — Account standard: ZeroDev Kernel (ERC-7579)
What: ERC-4337 + ERC-7579 via ZeroDev Kernel as the sole account standard.
Why: Cleanest session-key + modular-account ergonomics; aligns with Phase 5 Rhinestone distribution.
Rejected: Safe + Transaction Guard (simpler, but weaker session-key/module story for the demo).

## 2026-06-29 — On-chain guard: build minimal from scratch
What: Build the guard in Foundry from scratch with a tight fuzz/invariant suite; timebox ~1 week.
Why: Security-credibility artifact + recruiting signal (Foundry depth).
Rejected: Reuse ZeroDev/Safe+Zodiac/Rhinestone modules (faster, but less to show on the systems side). Cite them as the production path in the README.

## 2026-06-29 — Token-safety: fully local fork-sim
What: Honeypot/tax screen via in-fork buy->sell simulation; no third-party API.
Why: The only honest selling point (plan §6.5) is "fully local / self-hosted / auditable / no external trust."
Rejected: Integrate GoPlus/Honeypot.is/Blockaid (saves time, drops the no-dependency story).

## 2026-06-29 — Phase 0 scaffold complete
What: pnpm monorepo + Foundry skeleton, JSON Schema (additionalProperties:false) + validating example spec, threat-model doc, project CLAUDE.md with curated agents/skills, 3 ADRs.
Next: Phase 1 — on-chain ERC-7579 guard + Foundry invariant suite, deploy to Base Sepolia.

## 2026-06-29 — Phase 1 standalone guard implemented (green; deploy pending)
What: `PraetorGuard.sol` (allowlist+selector · recipient · per-tx + sliding-window rolling-24h caps · slippage min-out · rate · kill-switch · owner/account auth) + `ChainlinkPriceAdapter.sol` (decimals-explicit USD pricing, stale round = BLOCK). 53 Foundry tests green: unit+fuzz + 6 stateful invariants (256×8192 calls, 0 reverts) + adapter suite. `Deploy.s.sol` (dry-run OK) + `RevertDemo.s.sol` (in-spec executes / out-of-allowlist reverts). Gas: check() ~29k median, priceToUsd ~13k.
Decisions (ADR-0004): blocks are typed-error REVERTS, not a Blocked event (a revert discards its logs) — only `Executed` is a durable on-chain audit event; owner-mutable config + specHash honesty via CI cross-check (not immutable-per-deploy, §5.5); `onlyAccount` on check() (stops rolling/rate accumulator-poisoning false-blocks); true sliding-window ring buffer N=512; no renounceOwnership.
Review caught (real bug): setPolicy buffer guard was `*24`, corrected to `*25` — a sliding 24h window touches 25 fixed hour buckets, so maxTxPerHour=21 could overflow the ring and false-block a benign in-spec call (release gate #7). The invariant suite missed it (only tested maxTxPerHour=20). Fixed + boundary tests updated + non-vacuity test added.
Deferred / next session: Base Sepolia broadcast (needs BASE_SEPOLIA_RPC + funded key + explicit auth — hard stop); real ERC-7579 IHook wrapper (decodes calldata, closes the quotedOut==0/valueUsd trust-boundary sentinels); the `security-guard` + `code-quality` review lenses did NOT finish (session limit, resets 4:30pm Madrid) — re-run before declaring Phase 1 fully reviewed.
Next: Phase 2 off-chain engine (fork sim · oracle-deviation · drawdown · token-safety) + spec compiler + SDK — OR finish the two unfinished review lenses first.
