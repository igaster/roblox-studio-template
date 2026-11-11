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
lune run tests/run.lua   # from the project root (or `make test`); exits non-zero on failure
```

- **Run this yourself** after any change to pure logic — no Studio needed.
- When adding logic, extract the pure part into a `*Math`/helper module and add
  assertions to `tests/game.lua` (the game's tests) with the shared helpers:
  `local H = require("./harness")`, then `H.section`, `H.check`, `H.eq`, `H.near`.
- `tests/run.lua`, `tests/harness.lua` and `tests/framework.lua` (the framework's own
  checks: GameConfig is plain Lua, ServiceLoader discovery) belong to the framework;
  don't edit them for a game.

## Tier 2 — In-engine integration smoke test

A ModuleScript at `ServerScriptService/SmokeTest.lua` (no `.server`, so it never
auto-runs) drives the **real** classes with real Instances, fast-forwards
time-based state, and asserts the full gameplay loop. Requires the Roblox runtime.

**Preferred: run it yourself via the `roblox-studio-mcp` skill, in a fresh Play
session.** Start Play (`start_stop_play`), then `execute_luau` on the **Server**
datamodel:

```lua
return require(game.ServerScriptService.SmokeTest).run()
```

Stop Play afterwards. The return value is the verdict; on failure, read the
per-step `PASS`/`FAIL` lines with `get_console_output` (same contract as Tier 1's
exit code). The framework's own checks run the same way:
`require(game.ServerScriptService.FrameworkSmokeTest).run()`.

Why Play and not edit mode: in edit mode `require()` caches every module for the
whole Studio session, so after a Rojo sync the smoke test can run against an old
`GameConfig` or class (cloning the test module doesn't help: its `require`s still
hit the cache). A Play session loads everything fresh. If the smoke test changes
the live world (rebuilds a level, spawns entities), give it its own Play session
rather than reusing one you playtest in.

**Fallback: ask the user to run it manually** (Play, then the Server command bar)
if MCP isn't set up or isn't connected this session — don't silently skip Tier 2,
say why you're falling back.

MCP being "connected" isn't binary — see `roblox-studio-mcp`'s sync-verification
note. `execute_luau`/`get_console_output` can both work fine while Rojo's file
sync into the DataModel is actually dead, which looks like "nothing's here yet,"
not like a failure. Confirm sync (not just the MCP channel) before trusting a
Tier 2 run — a real one silently didn't run at all despite every individual
call succeeding.

Request/run this after changes to classes or asset generators, and extend the
script as new systems land.

**Writing checks that don't race:**
- Start the run with `TestHooks.muteAudio(true)`, so test runs are silent.
- After an action, wait for the action's own event:
  `local t = os.clock(); doAction(); TestHooks.waitForEvent(t, "Wave", "started")`. Never wait
  for a state ("phase is Wave, wave is 1") that may already have held before the action.
- The smoke test's `require`s are fresh module copies with their own local state. A game-clock
  or timer module's time there is not the live game's (it may never advance). Measure
  durations with `os.clock()` at a forced 1× speed, or read times from attributes.

## Balance simulator (optional)

When tuning needs many matches, a headless Lune script (`tests/balance_sim.lua`, run with
`make sim`) plays the game's rules quickly. Keep it honest:
- **It calls the game's real rule modules** (`*Math`, `GameConfig`): no copied formulas. List
  the rules it models in its header. **A rule change is a sim change:** when placement,
  waves, economy or win rules change, update the sim in the same task, or its results tune
  the old game.
- **Step size must not matter.** Countdowns carry the leftover (`cooldown += interval`, not
  `= 0`), and a Tier 1 check runs the same match at two step sizes and expects the same result.
  Otherwise the sim and the live game drift with the frame rate.
- **Results sit on cliffs.** Small changes can flip a win to a loss. Report margins (health
  left, waves survived), not only win or loss. Save the results table, and diff a new run
  against it (`make sim ARGS=--check`), so a refactor meant to keep the balance reproduces it
  exactly and a real change shows up as a diff.

## Tier 3 — Manual playtest checklist

`docs/TESTING.md` holds step-by-step checks that don't fit a fixed Tier 2 script.
Not all of them are equally automatable — split by what MCP can actually reach:

- **Single-player UI/input scenarios** ("does this button work", "does the chest
  open on click") — delegate to the `roblox-playtest` skill instead of asking the
  user. It drives a real Play session via MCP (input simulation +
  `get_console_output`/`inspect_instance`) and reports pass/fail with evidence.
  Note the checklist item as "run via `roblox-playtest`" once delegated.
- **Visual review** ("does this look right") — `roblox-capture`/`roblox-playtest`
  can pull a `screen_capture` for the agent to judge, but there's no baseline-diff
  tooling in this repo, so it's a judgment call each time, not a real pass/fail
  assertion. Still requires human sign-off for subjective calls.
- **Multiplayer** (player-vs-player rules, co-op, state not leaking between
  players) — **the in-engine half stays manual.** MCP drives one client; it cannot
  spin up a second one. Never claim this class of check is covered by MCP. Instead:
  - put every rule between two players in a pure `*Rules` module (who can tag whom,
    who gets the reward, cooldowns) with Tier 1 boundary tests, so the logic is
    covered headlessly;
  - playtest each side's lifecycle solo via `roblox-playtest`;
  - list the two-player checks in `docs/TESTING.md` for a human to run with Studio's
    **Test → Clients and Servers** (2 players) or a published test place.

Add a section per milestone as it completes, and mark which items are
`roblox-playtest`-delegable vs. genuinely manual so future sessions don't have to
re-derive it.

## Workflow rule

Run Tier 1 after every logic change. Request Tier 2 when classes or generators
change. Keep Tier 3 updated per milestone. Never start a new milestone (unless the GDD's *Owner involvement* pre-approves it) without
explicit user confirmation.
