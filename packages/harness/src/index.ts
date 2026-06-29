// Scorecard schema (plan §10.3). The harness is the centerpiece (Phase 3).
export interface ScenarioResult {
  id: string;
  attempted: boolean;
  blocked: boolean;
  blocking_check?: string;
  layer?: "onchain" | "offchain";
  // Per-scenario metrics the §10.3 example attaches, e.g. { deviation_bps, limit_bps }.
  metrics?: Record<string, number>;
  trace_ref?: string;
  baselines?: Record<string, "passed" | "blocked">;
}

export interface Scorecard {
  spec_hash: string;
  fork_block: number;
  generated_at: string;
  summary: { attacks: number; blocked: number; false_blocks: number; benign_total: number };
  by_layer: { onchain: number; offchain: number };
  scenarios: ScenarioResult[];
}

/**
 * Build scorecard.json + praetor-scorecard.md from scenario runs (plan §10.3). Phase 3 deliverable.
 * Runs each scenario vs baselines on a pinned fork, then emits both artifacts.
 */
export function buildScorecard(_results: ScenarioResult[]): Scorecard {
  throw new Error("buildScorecard() not implemented — Phase 3");
}
