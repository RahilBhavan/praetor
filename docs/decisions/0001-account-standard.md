# ADR-0001 — Account standard: ZeroDev Kernel (ERC-7579)

- Status: Accepted
- Date: 2026-06-29
- Plan refs: §7, §8

## Context
The plan requires committing to exactly ONE account-abstraction standard and not
abstracting over multiple (AA tooling churn is a named risk, §14). Candidates:
Safe + Transaction Guard vs ZeroDev Kernel (ERC-4337 + ERC-7579).

## Decision
Use **ZeroDev Kernel (ERC-4337 + ERC-7579)** as the sole account standard.

## Consequences
- Cleanest session-key + modular validator/hook ergonomics for the guard.
- Direct path to Phase 5 distribution via the Rhinestone ERC-7579 module registry.
- The guard is implemented as an ERC-7579 hook/validator module.
- Do NOT generalize across Safe / EIP-7702 for the MVP.
