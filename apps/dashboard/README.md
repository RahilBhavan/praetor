# apps/dashboard

Read-only dashboard (plan §6.8, Phase 4). Three panels, no backend DB:
1. Live feed: proposed -> allowed/blocked, with the offending check.
2. Per-check pass/fail matrix for the last N transactions.
3. Drawdown gauge (current equity vs HWM vs limits).

Driven from the engine's `EvaluateResult` stream + on-chain `Blocked`/`Executed`
events + a local JSONL of engine decisions. Do not over-build.
