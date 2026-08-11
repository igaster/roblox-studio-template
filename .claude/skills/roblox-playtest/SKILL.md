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

## Continuous/auto-driven gameplay (vehicles, lightcycle-style movement, anything server-remote-controlled)

`character_navigation` and `user_keyboard_input` move the Roblox `Character`/`Humanoid` —
they do **not** reliably drive gameplay entities that are controlled by firing RemoteEvents
server-side (a vehicle that moves forward automatically and steers via heading-delta remotes,
for example). Confirmed independently across two separate games/rounds: literal keypresses
(including a plain forward key) produced zero observed effect on such entities, and the
"press key, then separately check state" pattern loses its own race against real gameplay speed —
by the time a second MCP round-trip reads state back, several real seconds may have passed and an
unattended entity can have already crashed, respawned, or moved past the thing you meant to
observe.

**Standard technique for this case**: skip character-input tools entirely and drive the
gameplay-facing RemoteEvents directly — the same ones the real client script fires — via a
single `execute_luau` call (Client datamodel, so you're firing as the actual player). Do the
action *and* the before/after state sampling inside that one call, in a tight `task.wait(0.05-0.1)`
loop with no MCP round-trip in between samples. This eliminates the latency race and gives
concrete position/state-over-time evidence instead of a bare assertion. Read the relevant
`*.client.lua` first to find the exact remote names/argument shapes it uses (don't guess) —
in particular, check whether each remote expects a `string` or a raw number (`tostring(x)` vs
`x`); firing the wrong type fails silently (the server-side handler's `typeof()` guard just
drops it) and looks exactly like "nothing happened," easy to misdiagnose as a game bug.

**Template** (adapt names/positions to the current game — read the client script first):

```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Remotes = game:GetService("ReplicatedStorage").Remotes

local out = {}
local function getEntity()
	-- e.g. workspace.Arena_X:FindFirstChild("Vehicle_Standard_1")
end

Remotes.SomeAction:FireServer() -- e.g. entry/interact remote, no args
task.wait(0.15) -- let the server round-trip once before sampling

local start = os.clock()
while os.clock() - start < 2.0 do -- pick a duration that covers the scenario
	Remotes.SomeInput:FireServer(tostring(1)) -- match the real client's argument type
	local e = getEntity()
	table.insert(out, string.format("t=%.2f state=%s", os.clock() - start, e and tostring(e.Position) or "GONE"))
	task.wait() -- fastest available tick; do NOT use RunService.RenderStepped:Connect
	            -- here — it does not reliably fire inside an injected execute_luau script
	            -- and the loop will hang until the MCP call itself times out (~120s)
end

return table.concat(out, "\n")
```

Key pitfalls this template avoids, each hit at least once in practice:
- **Wrong argument type** (see above) — silently no-ops, looks like a dead remote.
- **`RunService.RenderStepped:Connect`** inside an injected script doesn't reliably fire —
  use a plain `task.wait()` loop instead, firing the remote directly in the loop body.
- **Firing too slowly**: if the real client fires a remote every frame while a key is held
  (check for a per-frame `RenderStepped`/`Heartbeat` connection in the client script) and your
  test fires at a much lower rate (e.g. one `task.wait(0.08)` per fire ≈ 12Hz vs. the real ~60Hz),
  server-side logic that resets its input state every frame (e.g. `pendingInput = 0` after
  consuming it) will see mostly-idle frames between your fires and the effect will look far
  weaker than real gameplay — match the real firing rate, don't guess a "good enough" one.
- **Not verifying the setup, only the result**: if a test doesn't behave as expected, check
  first whether you actually reproduced the intended scenario (right position, right distance
  from the target, no unrelated obstacle in the path) before concluding it's a game bug — a
  wrong test setup and a real regression can look identical from the output alone.

## Generic scenario setup — use TestHooks first

Reaching the state worth testing is usually the actual bottleneck, not the
testing itself. `ReplicatedStorage.Shared.TestHooks` ships with every game
(see `CLAUDE.md`'s "Observability (TestHooks)") for exactly this — **check
for it and use it before hand-rolling anything below.** Via `execute_luau`
on the **Server** datamodel:

```lua
local TestHooks = require(game.ReplicatedStorage.Shared.TestHooks)
local player = game.Players:GetPlayers()[1]

-- Get next to the nearest interactable without knowing its name/position:
local ok, entity = TestHooks.teleportNear(player) -- default tag "Interactable"

-- Full state snapshot (every Player's attributes + every tagged entity's
-- position/attributes) instead of walking the DataModel tree by hand:
local snapshot = TestHooks.dumpState()

-- Structured events instead of grepping noisy console output:
local recent = TestHooks.getEvents(os.clock() - 10) -- last 10 seconds, any category
```

If a game predates `TestHooks` or a builder hasn't adopted the tagging/
logging conventions yet, fall back to the manual techniques:

- **Reposition the character directly**: `player.Character.HumanoidRootPart.CFrame
  = CFrame.new(x, y, z)` via `execute_luau` (Server datamodel) is plain Roblox
  API — use it to get next to whatever you need to test instead of fighting
  `character_navigation`/pathing. This is test-harness setup, not a game-file
  edit; it's fine to do this freely.
- **Reading state without `TestHooks.dumpState()`**: `GetAttribute`/
  `GetAttributes()` directly on the `Player` or the entity still works even
  without the module. Avoid inferring state from visual proxies (e.g. "is the
  vehicle alive" from whether a `Head` part exists) if you can avoid it — that
  usually means the real state lives in a private Lua table you can't reach,
  which is itself worth flagging as a gap in `REPORT.md`/`FEEDBACK_LOG.md`
  (the fix is adopting `TestHooks`/attributes, not a cleverer inference).

## When not to use this

- Pure logic changes (math, formulas, config) → Tier 1 (`roblox-test`), no Studio
  needed.
- Fixed regression coverage after class/generator changes → Tier 2
  (`roblox-test`), not this — Tier 2 stays a stable, repeatable script; this skill
  is for one-off or exploratory scenarios.
- Static visual review of an asset with no interaction → `roblox-capture`.
