# Testing Guide

Three tiers of checks, from automatic → manual. See the **Testing** section of
`CLAUDE.md` and the `roblox-test` skill for Tier 1 (headless Lune unit tests) and
Tier 2 (in-engine smoke test) — how to run them and when. This doc covers Tier 3,
the manual playtest checklist, which lives only here.

---

## Tier 3 — Manual playtest checklist

Manual, inside Studio (`make serve` → Rojo connect → **Play**). For everything the
automated tests can't catch: UI/input, visuals, multiplayer isolation.

Add one section per milestone as it completes. Example structure:

### M1 — <milestone name> (single player)
- [ ] ...

### M1 — Multiplayer isolation (Play → 2 players)
- [ ] Each player gets their **own** isolated state.
- [ ] Player A **cannot** affect player B's state.
- [ ] Leaving cleans up that player's instances (no orphans in the workspace).

### General (every playtest)
- [ ] **Output panel: zero errors/warnings** during normal gameplay.
- [ ] No stalls/lag under load.

> Add new sections (M2, M3, ...) as milestones complete.
