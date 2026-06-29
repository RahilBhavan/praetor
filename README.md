# Praetor

> Agents propose. The spec disposes.

A spec-is-law policy firewall for onchain agents: one declarative safety spec
(`praetor.spec.yaml`) compiles to an off-chain policy engine and an
un-bypassable on-chain ERC-7579 guard. The headline deliverable is an
adversarial harness + reproducible scorecard proving it holds.

**The lens:** "spec-is-law" is a16z crypto's framing (Daejun Park), pitched
*protocol-side*. Praetor applies it one layer up, at the *agent/wallet*
boundary — a positioning lens and research north-star, not a novelty claim.

**Positioning (honest, per plan §2.4):** Praetor is a reproducible adversarial
evaluation of agent-wallet guardrails, plus two checks the shipping products
don't enforce — **oracle-deviation gating** and **simulation-backed drawdown**.
It sits alongside Coinbase AgentKit, Openfort, and Blockaid; it does not replace
them.

## Layout

- `contracts/` — Foundry on-chain guard (ERC-7579, ZeroDev Kernel). Built from
  scratch as a security-credibility artifact; ZeroDev Kernel / Safe+Zodiac /
  Rhinestone modules are the production path (ADR-0002).
- `packages/spec` — JSON Schema (single source of truth) + compiler
- `packages/engine` — off-chain evaluator (sim, oracle, drawdown, token-safety)
- `packages/sdk` — middleware + adapters
- `packages/harness` — attacker + scenarios + scorecard (the centerpiece)
- `apps/dashboard` — read-only UI
- `docs/threat-model.md` — attack class → check → layer → proof

## Quickstart

    pnpm install
    pnpm --filter @praetor/spec test      # example spec validates against schema
    cd contracts && forge install foundry-rs/forge-std && forge test

## Status

Phase 0 complete (scaffold + schema + threat model). Entering Phase 1 (on-chain guard).
