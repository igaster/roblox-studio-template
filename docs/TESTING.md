# Testing Guide

Three tiers of checks, from automatic → manual. See the **Testing** section of
`CLAUDE.md` for the workflow rules that tie them together.

---

## Tier 1 — Headless unit tests (Lune)

Covers **pure logic** (math, economy, grid, formulas) with no Roblox Studio.

```sh
lune run tests/run.lua
```

- Lives in dependency-free modules under `ReplicatedStorage/Modules/`.
- Exits with code 1 on failure → suitable for pre-commit / CI.
- Run it after every change to a formula or other pure logic.

---

## Tier 2 — In-engine integration smoke test

Drives the **real classes** with real Instances inside Studio, fast-forwarding any
time-based state and asserting the full gameplay loop.

**How to run** (Studio command bar, with Rojo connected):

```lua
require(game.ServerScriptService.SmokeTest).run()
```

Check the Output window for per-step PASS/FAIL and `SMOKE TEST OK` at the end.
It is a ModuleScript — it never auto-runs in a normal play session.

Run it whenever the logic in your classes or asset generators changes.

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
