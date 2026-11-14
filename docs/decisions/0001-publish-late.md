# 0001: Publish late, develop on a mock store

- Date: 2026-11-14
- Status: Accepted
- Decided by: the maintainer (with Claude)

## Context
A published place is harder to develop on: Studio drops Rojo connections on restart and the
published place adds constraints. But real DataStores need a published place and "Enable Studio
Access to API Services", so persistence work seemed to force publishing early. Roblox has no
built-in fake store (only feature requests); the community's `ProfileStore.Mock`, MockDataStoreService,
DataSafe and Lyra are memory-only mocks. ProfileStore (Apache-2.0) calls `DataStoreService`
directly with no injection hook and no schema version, so it can't run under Lune or meet the
Persistence rules as is.

## Decision
- Games develop unpublished. The GDD's `Publishing` field says until when (framework default:
  until G9 platform hardening, or the first external player). Publish earlier only when the game
  requires it.
- The framework ships `src/framework/MockDataStore.lua`, a memory-only mock that follows the real
  service's rules (key and value limits, serialization, `UpdateAsync` conflict re-runs) and injects
  faults, plus `src/framework/StoreContract.lua`, the behaviors every store must have. Games use
  it for Lune tests, the Tier 2 smoke test and the Studio fallback; they don't write their own.
- Checks that need a published place are tagged `[needs-published]`, deferred (never skipped),
  listed in `STATUS.md`, and closed in G9. Monetization (G12) waits for them.
- The mock is maintained in the framework as games find gaps: fix it and add a contract case.
  `tests/framework.lua` fails if a game file other than `DataService.lua`, `SmokeTest.lua` or
  `tests/` mentions it.

## Consequences
- Persistence code is verified against the mock and its contract, not the real service, until G9:
  the real round trip is the one thing left unproven.
- No file-backed store: Luau in Roblox can't write files, and a local HTTP store adds moving
  parts. Revisit if a game needs saves that survive Play sessions without publishing.
- Cross-server session locking is not in the mock beyond `interleave()`. Whether to wrap
  ProfileStore for it (L-030) is a separate decision.
- Revisit if Roblox adds DataStore support to unpublished places, or if the Rojo reconnect
  problem is fixed.
