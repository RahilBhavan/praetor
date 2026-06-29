import type { EvaluateResult, ProposedTx } from "@praetor/engine";

export interface PraetorGuardClient {
  /** Evaluate a proposed tx against the spec (off-chain). Call this INSTEAD of signing directly. */
  guard(tx: ProposedTx): Promise<EvaluateResult>;
  /** Sign with the scoped session key and route through the on-chain guard. */
  submit(tx: ProposedTx): Promise<`0x${string}`>;
}

export interface FromSpecOpts {
  rpc: string;
  signer: unknown;
}

/**
 * Build a guard client from a spec file (plan §6.6). Phase 2 deliverable.
 * Loads + validates the spec, then wires engine.evaluate + scoped session-key submit.
 */
export function fromSpec(_specPath: string, _opts: FromSpecOpts): PraetorGuardClient {
  throw new Error("fromSpec() not implemented — Phase 2");
}

export const praetor = { fromSpec };
