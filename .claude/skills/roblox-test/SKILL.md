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
lune run tests/suite.lua   # from the project root; exits non-zero on failure
```

- **Run this yourself** after any change to pure logic — no Studio needed.
- When adding logic, extract the pure part into a `*Math`/helper module and add
  assertions to `tests/suite.lua`.
- `Modules/ExampleMath.lua` + its assertions in `tests/suite.lua` are a starting
  template — replace them with the game's real modules as they're built.

## Tier 2 — In-engine integration smoke test

A ModuleScript at `ServerScriptService/SmokeTest.lua` (no `.server`, so it never
auto-runs) drives the **real** classes with real Instances, fast-forwards
time-based state, and asserts the full gameplay loop. Requires the Roblox runtime.

**Preferred: run it yourself via the `roblox-studio-mcp` skill.** If the MCP server
is set up and connected, call `execute_luau` (Server context) with:

```lua
require(game.ServerScriptService.SmokeTest).run()
```

then `get_console_output` to retrieve the result — no need to involve the user.
Parse for per-step `PASS`/`FAIL` lines and the final `SMOKE TEST OK` /
`SMOKE TEST FAILED` line, same contract as Tier 1's exit code.

**Fallback: ask the user to run it manually** in the Studio command bar (edit mode,
no Play) if MCP isn't set up or isn't connected this session — don't silently skip
Tier 2, say why you're falling back.

MCP being "connected" isn't binary — see `roblox-studio-mcp`'s sync-verification
note. `execute_luau`/`get_console_output` can both work fine while Rojo's file
sync into the DataModel is actually dead, which looks like "nothing's here yet,"
not like a failure. Confirm sync (not just the MCP channel) before trusting a
Tier 2 run — a real one silently didn't run at all despite every individual
call succeeding.

Request/run this after changes to classes or asset generators, and extend the
script as new systems land.

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
- **Multiplayer isolation** (state not leaking between players) — **stays fully
  manual.** MCP drives one Studio session with one input stream; it cannot spin up
  a second real client. Never claim this class of check is covered by MCP.

Add a section per milestone as it completes, and mark which items are
`roblox-playtest`-delegable vs. genuinely manual so future sessions don't have to
re-derive it.

## Workflow rule

Run Tier 1 after every logic change. Request Tier 2 when classes or generators
change. Keep Tier 3 updated per milestone. Never start a new milestone without
explicit user confirmation.
