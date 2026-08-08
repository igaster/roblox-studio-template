---
name: roblox-playtest
description: Use when asked to verify actual gameplay behavior interactively — e.g. "does jumping still work", "check that the chest opens when I click it" — by driving a real Play session with simulated input, rather than the fixed Tier 2 smoke test or a static Tier 1 unit test.
---

# Roblox Scripted Playtest

Drives a real Play session (physics, character, full gameplay) via the
`roblox-studio-mcp` skill, for verifying specific interactive behavior on demand.
This is heavier than `roblox-test`'s Tier 1/2 and scenario-specific — it isn't run
automatically after every change, only when the user asks to verify gameplay
behavior or you need to confirm something Tier 1/2 can't reach (physics, input,
timing that depends on the real engine).

Requires MCP set up and Studio open — see `roblox-studio-mcp` for preconditions.

## Steps

1. **State the scenario before starting** — what input sequence, what you expect
   to observe (a console line, a visible state change, an attribute value). This
   makes the pass/fail call unambiguous afterward.
2. **Start the session**: `start_stop_play` (start).
3. **Drive it**: `character_navigation` to move, `user_keyboard_input` /
   `user_mouse_input` for actions, in the sequence the scenario needs. Add small
   waits between steps if the behavior is time-dependent (animations, cooldowns,
   tweens) — don't assume instantaneous state changes.
4. **Observe**: `get_console_output` for any prints/warns/errors the scenario
   should produce, and/or `screen_capture` if a visual check is part of the
   scenario, and/or `inspect_instance` to check attribute/state values directly.
5. **Stop the session**: `start_stop_play` (stop) — always, even if the scenario
   failed partway through. Don't leave a Play session running.
6. **Report pass/fail** against the expectation stated in step 1, with the
   evidence (console lines, attribute values, or screenshot) you collected.

## When not to use this

- Pure logic changes (math, formulas, config) → Tier 1 (`roblox-test`), no Studio
  needed.
- Fixed regression coverage after class/generator changes → Tier 2
  (`roblox-test`), not this — Tier 2 stays a stable, repeatable script; this skill
  is for one-off or exploratory scenarios.
- Static visual review of an asset with no interaction → `roblox-capture`.
