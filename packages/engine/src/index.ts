import type { Spec } from "@praetor/spec";

export type BlockCode =
  | "ALLOWLIST"
  | "RECIPIENT"
  | "PER_TX_CAP"
  | "ROLLING_CAP"
  | "RATE_LIMIT"
  | "ORACLE_DEVIATION"
  | "ORACLE_STALE"
  | "DRAWDOWN"
  | "EXPOSURE"
  | "TOKEN_HONEYPOT"
  | "TOKEN_TAX"
  | "CIRCUIT_BREAKER";

export interface CheckOutcome {
  code: BlockCode | string;
  passed: boolean;
  detail?: string;
}

export interface SimulationResult {
  success: boolean;
  realizedOut?: bigint;
  gas?: bigint;
}

export interface ProposedTx {
  to: `0x${string}`;
  data: `0x${string}`;
  value?: bigint;
}

// Structured feedback (plan §6.2): every block returns code + offendingField + suggestedFix.
export interface EvaluateResult {
  allowed: boolean;
  reason?: string;
  code?: BlockCode;
  offendingField?: string;
  suggestedFix?: string;
  simulation?: SimulationResult;
  checks: CheckOutcome[];
}

/**
 * Off-chain pre-flight evaluation (plan §6.2). Phase 2 deliverable.
 * Pipeline: static pre-checks -> fork sim -> oracle-deviation -> token-safety -> portfolio invariants.
 */
export async function evaluate(_tx: ProposedTx, _spec: Spec): Promise<EvaluateResult> {
  throw new Error("evaluate() not implemented — Phase 2");
}
