# Praetor documentation

This index lists the design documents for Praetor. The [project README](../README.md) lists what is built and what is still a stub.

- [`threat-model.md`](threat-model.md): each attack class mapped to a check, an enforcement layer and the assertion that proves the block. It also states the trust boundary of the standalone guard.
- [`decisions/0001-account-standard.md`](decisions/0001-account-standard.md): ADR-0001, ZeroDev Kernel (ERC-4337 and ERC-7579) as the only account standard.
- [`decisions/0002-guard-build-from-scratch.md`](decisions/0002-guard-build-from-scratch.md): ADR-0002, a small from-scratch Foundry guard with a one-week timebox.
- [`decisions/0003-token-safety-local.md`](decisions/0003-token-safety-local.md): ADR-0003, a token-safety screen that uses local fork simulation and no external API. Not built yet.
- [`decisions/0004-standalone-guard-design.md`](decisions/0004-standalone-guard-design.md): ADR-0004, blocks as typed-error reverts, owner-mutable config and a single authorized `account`.
