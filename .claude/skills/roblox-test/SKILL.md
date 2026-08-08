---
name: roblox-test
description: Use after changing pure gameplay logic, a Class, or an asset generator — or whenever the user asks to run tests, verify the build, or check that changes work. Runs (or requests) the project's three-tier testing pipeline: headless Lune unit tests, in-engine smoke test, manual playtest checklist.
---

# Roblox Testing Pipeline

Three complementary tiers. Prefer the cheapest tier that can catch a given class of
bug; keep game logic testable by isolating it from the engine. This skill is invoked
automatically after logic changes and can also be run manually with `/roblox-test`.

## Tier 1 — Headless unit tests (Lune)

Pure gameplay logic (math, economy, grid, formulas) lives in **dependency-free
modules** under `ReplicatedStorage/Modules/` — no `game:GetService`, no
`Instance.new`, no Roblox datatypes (`Vector3`/`Color3`). Classes/generators delegate
to these modules so the formula has one source of truth. Test them headlessly with
[Lune](https://github.com/lune-org/lune):

```sh
lune run tests/run.lua   # from the project root; exits non-zero on failure
```

- **Run this yourself** after any change to pure logic — no Studio needed.
- When adding logic, extract the pure part into a `*Math`/helper module and add
  assertions to `tests/run.lua`.
- `Modules/ExampleMath.lua` + its assertions in `tests/run.lua` are a starting
  template — replace them with the game's real modules as they're built.

## Tier 2 — In-engine integration smoke test

A ModuleScript at `ServerScriptService/SmokeTest.lua` (no `.server`, so it never
auto-runs) drives the **real** classes with real Instances, fast-forwards
time-based state, and asserts the full gameplay loop. Requires the Roblox runtime,
so **ask the user to run it** in the Studio command bar (edit mode, no Play):

```lua
require(game.ServerScriptService.SmokeTest).run()
```

Expected: per-step `PASS` lines and `SMOKE TEST OK` in Output. Request this after
changes to classes or asset generators, and extend the script as new systems land.

## Tier 3 — Manual playtest checklist

`docs/TESTING.md` holds step-by-step manual checks (UI/input, visuals, multiplayer
isolation) that automation can't cover. Add a section per milestone as it completes.

## Workflow rule

Run Tier 1 after every logic change. Request Tier 2 when classes or generators
change. Keep Tier 3 updated per milestone. Never start a new milestone without
explicit user confirmation.
