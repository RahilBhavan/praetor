# ADR-0002 — On-chain guard: build minimal from scratch

- Status: Accepted
- Date: 2026-06-29
- Plan refs: §7

## Context
The on-chain guard (allowlist/caps/slippage/rate/kill-switch) is commoditized.
Build from scratch (Foundry) vs reuse an existing module stack.

## Decision
**Build a minimal guard from scratch in Foundry**, with a tight fuzz + invariant
suite, **timeboxed to ~1 week**.

## Consequences
- Keeps the security-credibility artifact (invariant suite = "spec-is-law holds" proof).
- Strong recruiting signal (Foundry depth).
- Cite ZeroDev Kernel / Safe+Zodiac / Rhinestone as the production path in the README.
- Marginal hours after the timebox go to the differentiated off-chain checks + harness.
