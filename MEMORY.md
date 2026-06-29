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
