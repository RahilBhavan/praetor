# Praetor: a Solidity policy guard and spec schema for fund-holding AI agents (early prototype)

Praetor is an early prototype of a policy firewall for AI agents that sign onchain transactions. It has two working parts. One is a JSON Schema for a declarative safety spec (`praetor.spec.yaml`). The other is a standalone Solidity guard that reverts any call outside its configured policy. The design also calls for an off-chain engine, an ERC-7579 hook and an adversarial scorecard. The engine and scorecard exist only as typed stubs that throw "not implemented", and the hook is not written, so no scorecard exists yet.

## What it does

The table shows what runs at commit `b67be44` and what is still a stub.

| Part | Status | Where |
| --- | --- | --- |
| Spec schema and validator | Works. Rejects unknown keys (`additionalProperties: false`). | `packages/spec/schema.json`, `packages/spec/src/validate.ts` |
| On-chain guard `check()` | Works. Reverts on kill switch, target and selector allowlist, recipient allowlist, per-transaction USD cap, slippage floor, hourly rate limit and rolling 24-hour USD cap. | `contracts/src/PraetorGuard.sol` |
| Chainlink USD pricing | Works in tests. Reverts on a stale, incomplete, future or non-positive round. The guard does not call it yet. | `contracts/src/ChainlinkPriceAdapter.sol` |
| Revert demo | Works. One in-spec call executes and one out-of-allowlist call reverts with `TargetNotAllowed`. | `contracts/script/RevertDemo.s.sol` |
| Spec compiler `compile()` | Stub. Throws. | `packages/spec/src/compile.ts` |
| Off-chain engine `evaluate()` (fork simulation, oracle deviation, drawdown, token safety) | Stub. Throws. | `packages/engine/src/index.ts` |
| SDK `fromSpec()` | Stub. Throws. | `packages/sdk/src/index.ts` |
| Adversarial harness and scorecard `buildScorecard()` | Stub. Throws. No scenarios. | `packages/harness/` |
| ERC-7579 hook wrapper | Not written. Deferred in ADR-0004. | none |
| Dashboard | Not written. A README describes the plan. | `apps/dashboard/README.md` |

The Foundry suite checks six invariants over fuzzed call sequences. No out-of-allowlist target, selector or recipient executes. No executed call exceeds the per-transaction cap. The sum over any trailing 24 hours stays within the rolling cap. No fixed hour bucket exceeds the rate limit. Every executed swap meets the slippage floor. Nothing executes while the guard is halted. The suite reported `runs: 256, calls: 8192, reverts: 0` on 2026-10-21.

## How it works

1. A spec file such as `praetor.spec.yaml` declares allowlists, USD caps, slippage, rate limits and off-chain invariants. `validateSpec()` in `packages/spec/src/validate.ts` checks it against `packages/spec/schema.json`.
2. The owner configures `PraetorGuard` with `setPolicy`, `setAllowed` and `setRecipient`. The guard starts halted and executes nothing until the owner calls `setHalted(false)`.
3. The one authorized `account` calls `check(target, selector, valueUsd, recipient, minOut, quotedOut)` before each call. Each failed check reverts with a typed error such as `PerTxCapExceeded`. A passing call emits `Executed(specHash, target, selector)`.
4. The rolling 24-hour cap uses a 512-entry ring buffer with a running sum, so the window slides and does not reset at fixed times.

The guard trusts its `account` to pass honest `valueUsd` and `quotedOut`. The invariants prove enforcement given those inputs. The planned ERC-7579 hook would decode real calldata and price it through `ChainlinkPriceAdapter` to close that gap. [`docs/threat-model.md`](docs/threat-model.md) states this boundary in full.

## Run it

Prerequisites: Node 20 or later (tested on 26.8.1), pnpm (tested with 10.34.7) and Foundry (tested with forge 1.8.6). No credentials are needed for the tests or the demo.

```bash
git clone --recurse-submodules https://github.com/RahilBhavan/praetor.git
cd praetor
pnpm install
pnpm -r build
pnpm -r test
```

`pnpm -r test` ran 5 Vitest cases in `packages/spec` on 2026-10-21, and all passed. The engine, SDK and harness packages have no tests.

```bash
cd contracts
forge test
forge script script/RevertDemo.s.sol -vv
```

`forge test` reported 48 passed, 0 failed on 2026-10-21: 32 guard tests, 14 adapter tests and 2 entries in the invariant suite. The invariant suite holds 6 invariants and 1 non-vacuity test, and forge 1.8.6 reports the 6 invariants as one entry. The source has 47 test functions and 6 invariant functions. `forge test --fuzz-runs 10000` also passed. If you cloned without submodules, run `git submodule update --init` first.

`contracts/script/Deploy.s.sol` deploys and configures the guard. It needs `BASE_SEPOLIA_RPC` and a Foundry keystore account, and it broadcasts only with `--broadcast`. It uses Base mainnet router and pool addresses, which differ on Base Sepolia. No deployment exists.

## Repository layout

- `contracts/`: Foundry project with the guard, the price adapter, tests and scripts.
- `packages/spec/`: JSON Schema, TypeScript types, validator and the `compile()` stub.
- `packages/engine/`: types and the `evaluate()` stub for the off-chain engine.
- `packages/sdk/`: types and the `fromSpec()` stub for agent middleware.
- `packages/harness/`: scorecard types and the `buildScorecard()` stub.
- `apps/dashboard/`: a README that describes the planned read-only dashboard.
- `docs/`: threat model and architecture decision records.
- `traces/`: empty placeholder for engine decision logs.
- `praetor.spec.yaml`: example spec. Addresses marked `PLACEHOLDER` are examples.

## Documentation

- [`docs/README.md`](docs/README.md): index of the documents below.
- [`docs/threat-model.md`](docs/threat-model.md): each attack class mapped to a check, a layer and the assertion that proves the block, plus the trust boundary of the standalone guard.
- [`docs/decisions/0001-account-standard.md`](docs/decisions/0001-account-standard.md): why ZeroDev Kernel (ERC-4337 and ERC-7579) is the only account standard.
- [`docs/decisions/0002-guard-build-from-scratch.md`](docs/decisions/0002-guard-build-from-scratch.md): why the guard is a small from-scratch Foundry build.
- [`docs/decisions/0003-token-safety-local.md`](docs/decisions/0003-token-safety-local.md): why the planned token-safety screen uses local fork simulation and no external API.
- [`docs/decisions/0004-standalone-guard-design.md`](docs/decisions/0004-standalone-guard-design.md): why blocks are reverts, why config is owner-mutable and why only one account can call `check()`.

## Scope and limits

- Independent solo work. Not affiliated with Coinbase, ZeroDev, Rhinestone, Chainlink, Openfort, Blockaid or a16z.
- Early prototype. The history has two commits, both from 2026-06-29.
- Unaudited. Do not use it to protect real funds.
- The scorecard does not exist. The harness, the engine, the compiler and the SDK are stubs, so the repository makes no attack-blocking or false-block claims.
- The guard is standalone, not an ERC-7579 module. Its callers supply `valueUsd`, `minOut` and `quotedOut`, and its guarantees hold only if those inputs are honest.
- The guard is not deployed on any network.
- No CI workflow exists. The test results above come from local runs.
- "Spec-is-law" is a framing from a16z crypto (Daejun Park), applied there on the protocol side. Praetor applies it at the agent wallet. It is a lens, not a novelty claim. Products such as Coinbase AgentKit, Openfort and Blockaid already ship agent-wallet guardrails. Praetor is meant to sit beside them.

## License

[MIT](LICENSE), matching the `SPDX-License-Identifier: MIT` headers in the Solidity sources.

Part of [Rahil Bhavan's projects](https://github.com/RahilBhavan).
