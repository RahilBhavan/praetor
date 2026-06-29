# Praetor Threat Model

> Phase 0 deliverable (plan §3.2, §19.1). One page mapping each attack class an
> autonomous funds-controlling agent faces → the Praetor check that stops it,
> the enforcement layer, and the assertion that proves the block.
>
> Taxonomy derived from *SoK: Security and Privacy of AI Agents for Blockchain*
> (Romandini et al., BCCA 2025 — [R10]) and the ASB finance scenario ([R8]);
> indirect-prompt-injection framing from AgentDojo ([R7]). The harness scenarios
> in §10.1 of the plan are the executable form of this table.

## Trust anchor

- **On-chain guard = un-bypassable backstop.** Even a fully hijacked agent
  cannot exceed allowlist / caps / slippage / rate, because the contract
  reverts. This is the trust anchor.
- **Off-chain engine = rich but best-effort.** It runs simulation,
  oracle-deviation, drawdown, and token-safety — checks impractical on-chain —
  but a compromised agent could try to skip it. That is *why* the on-chain
  layer exists beneath it. Defense-in-depth: neither alone is sufficient.
- **Fail-closed.** Anything not explicitly permitted by the spec is denied.

## Attack class → check → layer → proof

| # | Attack class | Mechanic / injection vector | Praetor check | Layer | Assertion that proves the block |
|---|---|---|---|---|---|
| 1 | **Manipulated data / bad oracle** | Corrupted/laggy feed or thin-liquidity pool induces an off-market fill that still passes caps + allowlist. | Oracle-deviation gate | Off-chain | `\|realized_price − ref_price\| / ref_price × 10_000 > oracle_deviation_bps` ⇒ BLOCK. Realized price is read from **simulation**, not the agent's quote. Stale reference round (`block.timestamp − updatedAt > max_staleness_sec` or `answeredInRound < roundId`, evaluated against the fork's chain time — never wall-clock) ⇒ BLOCK. |
| 2 | **Indirect prompt injection → drain** | Malicious instruction embedded in tool output (token metadata, webpage, email) redirects funds to an attacker address. | Allowlist (target+selector) + recipient allowlist | On-chain (+ off-chain pre-check) | Recipient ∉ `recipients.allow`, or `(target, selector) ∉ allowlist` ⇒ revert, regardless of LLM intent. |
| 3 | **Malicious token (honeypot / taxed)** | Agent induced to buy a token that cannot be sold, or carries a confiscatory transfer tax / blacklist / mint authority. | Token-safety screen (simulated buy→sell), **fully local fork-sim** (ADR-0003) | Off-chain | In-fork buy then sell: sell reverts (honeypot) ⇒ BLOCK; effective tax bps `> max_transfer_tax_bps` ⇒ BLOCK; blacklist/mint heuristics per spec flags. |
| 4 | **Loop / runaway drain** | Hallucinated or hijacked control loop issues rapid repeated withdrawals. | Rate limit + rolling 24h cap + circuit breaker | On-chain | `(max_tx_per_hour + 1)`-th tx in the hour bucket reverts; cumulative notional `> rolling_24h_usd` reverts; while `halted`, every `check()` reverts. |
| 5 | **Excess slippage / sandwich bait** | Order placed with tolerance wide enough to be profitably sandwiched. | Slippage bound (min-out) | On-chain | `minOut = quotedOut × (10000 − max_slippage_bps) / 10000`; executed swap with `actualOut < minOut` reverts. |
| 6 | **Portfolio blowup** (in-spec trades, bad aggregate) | A sequence of individually-in-spec trades walks portfolio equity past the drawdown limit. | Drawdown / exposure invariant | Off-chain | Post-trade equity simulated against high-water mark: `post_equity < hwm × (1 − max_drawdown_pct/100)` ⇒ BLOCK; per-asset `position_value_i / post_equity > max_exposure_pct_i / 100` ⇒ BLOCK. Breach of `halt_on_drawdown_pct` trips the on-chain kill switch. |
| 7 | **Recipient / contract spoofing** | Funds routed to a look-alike contract or attacker address. | Recipient allowlist for transfer-class calls | On-chain | Transfer target ∉ `recipients.allow` ⇒ revert. |

## Boundary of the guarantee (do not oversell)

Praetor does **not**:
- prove the agent's *strategy* is good;
- catch novel protocol-logic exploits in third-party contracts (EVMbench / FORAY territory);
- exceed the fidelity of its reference feed (oracle-deviation is only as good as Chainlink) or its fork freshness (simulation reflects state at the pinned fork block, not the exact execution block — the on-chain guard backstops this window).

## Determinism notes (plan §4.4)

- Pin the fork to a block for all tests and the harness: `anvil --fork-url <RPC> --fork-block-number <N>`.
- Evaluate oracle freshness against the fork's chain time (`block.timestamp`), not wall-clock, or a fork pinned in the past makes every round read as stale and false-blocks the benign control set (§10.4).
- Treat a stale reference round as a **block**, not a pass — a stale oracle is itself an attack surface.

## References

- [R7] AgentDojo (NeurIPS 2024), arXiv:2406.13352
- [R8] Agent Security Bench / ASB (ICLR 2025), arXiv:2410.02644 — prompt/LLM-level defenses avg ASR >84%, motivating structural enforcement at the signing boundary.
- [R10] SoK: Security and Privacy of AI Agents for Blockchain (BCCA 2025), arXiv:2509.07131
