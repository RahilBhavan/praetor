import type { Spec } from "./types.js";

/**
 * On-chain guard configuration emitted from a spec (plan §5.4).
 * Note: the circuit breaker is a runtime `halted` bool set via setHalted() by the
 * engine (§6.1 Policy struct) — it is NOT compiled in here; the on-chain layer has
 * no slot for a drawdown percentage. The threshold lives in EngineChecks.
 */
export interface OnchainConfig {
  specHash: string;
  allowlist: { target: string; selectors: string[] }[];
  recipients: string[];
  perTxUsd?: number;
  rolling24hUsd?: number;
  maxSlippageBps: number;
  maxTxPerHour?: number;
}

/** Off-chain engine check set emitted from a spec (plan §5.4). */
export interface EngineChecks {
  oracleDeviationBps: number;
  referenceMaxStalenessSec: number;
  maxDrawdownPct?: number;
  maxExposurePct?: Record<string, number>;
  // Engine evaluates post-trade drawdown and trips the on-chain kill switch
  // (setHalted(true)) when it exceeds this (§6.4). Off-chain input, on-chain enforced.
  haltOnDrawdownPct?: number;
  tokenSafety?: {
    blockHoneypot?: boolean;
    requireMintRenounced?: boolean;
    maxTransferTaxBps?: number;
    blockBlacklistable?: boolean;
  };
}

/**
 * Compile one spec into its two targets (plan §5.4, §9). Phase 2 deliverable.
 * Documents the contract only for now.
 */
export function compile(_spec: Spec): { onchainConfig: OnchainConfig; engineChecks: EngineChecks } {
  throw new Error("compile() not implemented — Phase 2");
}
