# ADR-0003 — Token-safety screen: fully local fork-sim

- Status: Accepted
- Date: 2026-06-29
- Plan refs: §6.5

## Context
The honeypot/tax screen can be done via local fork-simulation or an external API
(GoPlus / Honeypot.is / Blockaid). Blockaid ships this for agents already.

## Decision
**Fully local fork-sim** (in-fork buy -> sell), **no third-party API dependency**.

## Consequences
- The honest selling point is "fully local / self-hosted / auditable / no external trust."
- More engine work than calling an API; bounded by fork fidelity.
- Keep the screen behind an interface so an API could drop in later if priorities change.
