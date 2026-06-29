// TypeScript mirror of packages/spec/schema.json. The schema is the source of
// truth; keep these in sync (a generator is a Phase 2 nicety, not now).
export type Address = `0x${string}`;
export type Chain = "base" | "base-sepolia";

export interface AllowlistEntry {
  protocol?: string;
  address: Address;
  functions: string[];
}

export interface TokenSafety {
  block_honeypot?: boolean;
  require_mint_renounced?: boolean;
  max_transfer_tax_bps?: number;
  block_blacklistable?: boolean;
}

export interface Invariants {
  oracle_deviation_bps: number;
  reference: { source: "chainlink"; max_staleness_sec: number };
  max_drawdown_pct?: number;
  max_exposure_pct?: Record<string, number>;
  token_safety?: TokenSafety;
}

export interface Spec {
  version: number;
  account: Address;
  chain: Chain;
  spec_hash?: string;
  allowlist?: AllowlistEntry[];
  recipients?: { allow: Address[] };
  limits?: { per_tx_usd?: number; rolling_24h_usd?: number; max_slippage_bps: number };
  rate?: { max_tx_per_hour: number };
  circuit_breaker?: { halt_on_drawdown_pct: number };
  invariants?: Invariants;
  on_block?: {
    action?: "feedback" | "halt";
    log?: boolean;
    feedback_verbosity?: "minimal" | "structured";
  };
}
