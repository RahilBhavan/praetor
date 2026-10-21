# apps/dashboard

Read-only dashboard (plan §6.8, Phase 4). Three panels, no backend DB:
1. Live feed: proposed -> allowed/blocked, with the offending check.
2. Per-check pass/fail matrix for the last N transactions.
3. Drawdown gauge (current equity vs HWM vs limits).

Driven from the engine's `EvaluateResult` stream + on-chain `Executed`
events (the guard reverts on a block and emits no `Blocked` event; see
docs/decisions/0004-standalone-guard-design.md) + a local JSONL of engine decisions. Do not over-build.
