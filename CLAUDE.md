# CLAUDE.md

<!-- Last generated: 2026-06-29 -->
<!-- Global rules in ~/.claude/CLAUDE.md apply automatically. Do not restate the Four Rules, Communication, Hard Stops, or Memory Protocol here. -->

## Project

**Name:** Praetor — a spec-is-law policy firewall for onchain agents
**Stack:** TypeScript · Solidity (Foundry) · pnpm monorepo
**Architecture:** One declarative safety spec (`praetor.spec.yaml`) compiles to two enforcement layers — an **off-chain policy engine** (fork-simulation, oracle-deviation, drawdown, token-safety) and an **on-chain ERC-7579 guard module** that reverts anything out of spec. The headline deliverable is the **adversarial harness + reproducible scorecard**, not the firewall itself.
**Deployment:** Base Sepolia (guard) for the demo; engine/SDK run locally; dashboard is read-only.
**Status:** greenfield — Phase 0 complete, entering Phase 1.

> Read `praetor-project-plan (1).md` for the full design. It is the master plan; this file is the operating contract. Positioning rule (§2.4): **never** pitch this as "infrastructure nobody is building." Lead with the scorecard + the two differentiated checks (oracle-deviation, simulation-backed drawdown). Cite Coinbase AgentKit / Openfort / Blockaid as context, not competition. Spec-is-law is a16z's lens (Daejun Park), framed protocol-side; Praetor applies it agent-side — a positioning device, not a novelty claim (§2.1).

---

## Stack — never suggest alternatives unless asked

- **Language:** TypeScript 5.x (strict) · Solidity ^0.8.24
- **Runtime:** Node ≥20 (developed on 26)
- **Package manager:** pnpm workspace — never npm or yarn
- **Contracts:** Foundry (forge/anvil/cast) — fuzz + invariant tests
- **Account standard:** ERC-4337 + **ERC-7579 via ZeroDev Kernel** — exactly ONE (ADR-0001). Do not abstract over Safe/7702.
- **Simulation:** Anvil `--fork-url --fork-block-number` (pinned block); Tenderly optional
- **Reference prices:** Chainlink data feeds — freshness checks mandatory
- **Token safety:** fully local fork-sim, no external API (ADR-0003)
- **Engine / SDK:** TypeScript + viem
- **Schema:** JSON Schema draft 2020-12, `additionalProperties:false` (`packages/spec/schema.json` is the single source of truth)
- **Testing:** Foundry fuzz/invariant (contracts) + Vitest (TS)
- **Dashboard:** minimal read-only React/static HTML — no backend DB (chain logs + local JSONL)
- **CI:** GitHub Actions — `forge test` (incl. invariant) + `vitest`, cache pinned-fork fixtures

---

## Code Standards

- **Commits:** conventional commits (feat/fix/chore/docs/refactor/test). Never commit directly to `main` — branch first.
- **Types:** no `any` — use `unknown` and narrow. Schema types flow from `packages/spec`.
- **Errors:** structured `EvaluateResult` ({allowed, reason, code, offendingField, suggestedFix}); never swallow a failed check silently.
- **Solidity:** revert with reasons; emit `Blocked`/`Executed(specHash, …)` — events are the audit log.
- **Tests:** every non-trivial check ships a runnable test (engine: vitest against pinned fixtures; guard: Foundry invariant).

---

## File & Folder Conventions (plan §8)

```
contracts/                  # Foundry — on-chain ERC-7579 guard
  src/PraetorGuard.sol
  test/PraetorGuard.t.sol · test/invariant/Guard.invariant.t.sol
  script/Deploy.s.sol
packages/
  spec/      # schema.json (source of truth) + types + compiler
  engine/    # off-chain evaluator: evaluate/sim/oracle/drawdown/tokensafety
  sdk/       # middleware + adapters (raw loop, LangChain)
  harness/   # attacker + scenarios + scorecard  ← the centerpiece
apps/dashboard/             # read-only UI
docs/threat-model.md · docs/decisions/*.md (ADRs)
praetor.spec.yaml           # example spec
```

**Naming:** files kebab-case, types/contracts PascalCase, functions camelCase, constants SCREAMING_SNAKE_CASE.

---

## Permanent Rules — apply without exception (flag any conflict before proceeding)

1. **Fail-closed.** Anything not explicitly permitted by the spec is denied. No implicit allowlisting.
2. **Schema is law.** `packages/spec/schema.json` is the single source of truth; `additionalProperties:false` — unknown keys must fail loudly, never silently disable a check. Both the on-chain compiler and the engine import it.
3. **Pin the fork block** for every test and the harness — the scorecard must be reproducible.
4. **Stale oracle = BLOCK.** A Chainlink round with `block.timestamp − updatedAt > max_staleness_sec` or `answeredInRound < roundId` is a block, not a pass.
5. **Trust the simulation, not the agent.** Realized prices / deltas come from the fork sim, never the agent's claimed quote (the agent may be compromised).
6. **Decimals are explicit.** Every price math handles token-decimals vs feed-decimals (Chainlink USD feeds are 8-dp). Reach for `ecc:evm-token-decimals`.
7. **Zero false-blocks is a release gate.** One false-block on the benign control set is worse than a missed attack.
8. **Don't gold-plate the guard.** Timebox the on-chain layer (~1 week); cite ZeroDev/Safe/Rhinestone as the production path. Marginal hours go to the off-chain checks (§6.3–6.4) and the harness (§10).

---

## Agents & Skills — reach for these (the project's curated toolbelt)

ECC agents/skills are globally installed; this maps them to Praetor's work. Delegate review and research; keep filesystem writes in the main session.

**Skills — invoke by task:**
- `ecc:llm-trading-agent-security` — agent/wallet attack & defense patterns; harness scenario design.
- `ecc:defi-amm-security` — AMM/swap/oracle-manipulation security → the oracle-deviation wedge & sandwich scenario.
- `ecc:evm-token-decimals` — **mandatory** for oracle-deviation + USD pricing math (§6.3 decimals hazard).
- `ecc:nodejs-keccak256` — canonicalize + keccak256 the spec for `spec_hash`.
- `ecc:eval-harness` — the adversarial harness + scorecard (Phase 3 centerpiece).
- `ecc:security-review` / `ecc:security-scan` — pre-outreach security pass over guard + engine.
- `ecc:tdd-workflow` — engine checks against pinned fixtures.
- `ecc:architecture-decision-records` — keep `docs/decisions/*` current as design shifts.
- `ecc:dashboard-builder` / `ecc:frontend-patterns` — Phase 4 read-only dashboard.
- `ecc:git-workflow` / `ecc:github-ops` / `ecc:pr` — branch/PR hygiene; CI badge.
- `ecc:blueprint` / `ecc:plan` — multi-session phase planning before big changes.
- `ecc:deep-research` / `ecc:exa-search` — verify competitive/positioning claims (§2, §18) before the writeup.
- `ecc:mcp-server-patterns` / `ecc:agent-payment-x402` — Phase 5 (expose SDK as MCP; AgentCore/x402 context).

**Agents — delegate to these:**
- `ecc:security-reviewer` — **MUST** for the Solidity guard and any engine code touching funds/auth.
- `ecc:typescript-reviewer` — engine / SDK / harness TS.
- `ecc:code-reviewer` — general post-change pass.
- `ecc:architect` / `ecc:code-architect` — component & interface design.
- `ecc:performance-optimizer` — `guard()` latency metric (§12).
- `ecc:tdd-guide` — fixture-based engine tests.
- `ecc:pr-test-analyzer` — harness / scorecard coverage quality.
- `Explore` / `Plan` — codebase search and implementation planning.
- **Gap:** no Solidity-specific reviewer is installed → use `ecc:security-reviewer` + `ecc:code-reviewer` for Foundry/Solidity, and treat the Foundry fuzz/invariant suite as the primary correctness proof.

---

## Deployment & Environments

- **Local dev:** `pnpm install` · `pnpm -r build` · `pnpm -r test`
- **Spec check:** `pnpm --filter @praetor/spec test` (validates `praetor.spec.yaml` against the schema; an unknown key must fail)
- **Contracts:** `cd contracts && forge install foundry-rs/forge-std && forge test --fuzz-runs 10000`
- **Fork node (pin the block!):** `anvil --fork-url $BASE_RPC --fork-block-number $PINNED_BLOCK`
- Env vars in `.env` (see `.env.example`): `BASE_RPC`, `BASE_SEPOLIA_RPC`, `PINNED_BLOCK`, `PRIVATE_KEY` (deploy only).

---

## Current Sprint

**Sprint goal:** Phase 1 — minimal on-chain guard (ZeroDev Kernel ERC-7579 hook/validator) with a green Foundry fuzz+invariant suite, deployed to Base Sepolia.
**Done (Phase 0):** monorepo + Foundry skeleton · JSON Schema + example spec (validates) · threat-model doc · ADRs · this file.
**Next:** allowlist/recipient/caps/slippage/rate/kill-switch + Chainlink pricing adapter; invariant suite proving out-of-spec ⇒ revert; revert demo script.
**Blocked on:** `forge install foundry-rs/forge-std` (network) before contracts compile.

---

## What I Am and What I Know

**Role:** [manual: founder / engineer / researcher — building this as a research/recruiting portfolio artifact]
**Strong in:** [manual: Foundry / Solidity per Guardian-Pipeline background]
**Still learning:** [manual]
