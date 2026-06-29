# Praetor — Errors & Gotchas

## Foundry contracts won't compile
Failed: `forge build` / `forge test` before installing forge-std (no `lib/`, needs network).
Worked: `cd contracts && forge install foundry-rs/forge-std` first; test/script/invariant files import forge-std.
Note: `src/PraetorGuard.sol` is compilable standalone in Phase 0; only test/script/invariant need forge-std.
