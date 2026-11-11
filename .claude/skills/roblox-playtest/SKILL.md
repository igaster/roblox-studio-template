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
2. **Start the session**: `start_stop_play` (start), then silence it:
   `require(game.ReplicatedStorage.Shared.TestHooks).muteAudio(true)` on the Server. Test runs
   stay muted unless the scenario is about sound.
   If the game credits only *active* players (crewing, scoring), a scenario driven by test
   commands may leave the player inactive, so rewards silently don't pay. Give the game a
   command that marks the player active, and use it in such runs.
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

## Fast-changing state: act and observe in one call

Any state that changes faster than an MCP round trip (an NPC state machine, a chase, a
timer, a vehicle) can't be checked with "do X in one call, then read state in the next": by
the second call several seconds may have passed (in one run the NPC caught the player between
the two calls). Do the action **and** the sampling in a single `execute_luau` call, in a
`task.wait()` loop, and return the samples (template below). Console lines and `TestHooks`
events read afterwards are a good second record.

`character_navigation` works for Roblox's stock Humanoid controller but can error inside
Studio's own tool (see `roblox-studio-mcp`, *Known failures*); then teleport
(`TestHooks.teleportNear`, `PivotTo`) and read attributes instead.

## Continuous/auto-driven gameplay (vehicles, lightcycle-style movement, anything server-remote-controlled)

**Which input tool?** `character_navigation`/`user_keyboard_input` drive the stock Roblox
`Humanoid` controller well. They do **not** drive entities moved by the game's own
RemoteEvents (an auto-moving vehicle steered by remotes): keypresses have no effect there.
Rule: stock character controller → try `character_navigation` first; custom movement → use
the technique below.

**Standard technique for this case**: skip character-input tools entirely and drive the
gameplay-facing RemoteEvents directly — the same ones the real client script fires — via a
single `execute_luau` call (Client datamodel, so you're firing as the actual player). Do the
action *and* the before/after state sampling inside that one call, in a tight `task.wait(0.05-0.1)`
loop with no MCP round-trip in between samples. This eliminates the latency race and gives
concrete position/state-over-time evidence instead of a bare assertion. Read the relevant
controller (`StarterPlayerScripts/Controllers/*.lua`) first to find the exact remote names/argument shapes it uses (don't guess) —
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
- **`Humanoid:MoveTo` gives up after 8 seconds** and stops short without an error. Split
  long walks into legs (≤ 30 studs at walking speed, less when the character is slowed) and
  wait for `MoveToFinished` on each, or teleport when the walk itself isn't under test.
- **Not verifying the setup, only the result**: if a test doesn't behave as expected, check
  first whether you actually reproduced the intended scenario (right position, right distance
  from the target, no unrelated obstacle in the path) before concluding it's a game bug — a
  wrong test setup and a real regression can look identical from the output alone.

## Generic scenario setup — use TestHooks first

TestHooks API (`src/shared/TestHooks.lua`, server side unless noted):

| Function | Purpose |
|---|---|
| `tagInteractable(instance, tag?)` | Tag an entity as interactable (default tag `"Interactable"`). |
| `log(category, message, data?)` | Record a structured, filterable event (also prints, unless the category is quiet). |
| `setQuiet(category, quiet?)` | Keep recording a high-volume category (one event per kill) without printing it. |
| `getEvents(sinceTime?, category?)` | Read back recorded events, filtered by time and/or category. Keeps the newest `MAX_EVENTS` (10,000). |
| `waitForEvent(since, category, message?, timeout?)` | Wait for an event logged after an action (take `since = os.clock()` before acting). Use it instead of waiting for a state, which may already hold. |
| `dumpState(tags?)` | Snapshot: every `Player`'s attributes, plus every tagged instance's position + attributes. |
| `teleportNear(player, tag?)` | Move a player's character next to the nearest tagged instance. |
| `registerCommand(name, fn)` / `runCommand(name, ...)` | Studio-only test commands that act on a live game's private state (set currency, force a save). Register in a service's or controller's `init()`. Also callable through attributes, on server and client (below). |
| `muteAudio(on?)` | Studio only: silence all game sound for a test run; `muteAudio(false)` restores it. Players are never affected. |

Events live in `ServerStorage.TestHooksEvents`, so any server-side `require()` copy sees
them, including `execute_luau`'s fresh copy.

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

-- Act on a live service's private state (currency, timers, saves) through a
-- Studio-only command the service registered with TestHooks.registerCommand:
TestHooks.runCommand("setCrumbs", player.Name, 5000)
```

`execute_luau` gets a fresh copy of every module, so it can't reach a service's
private tables directly. When a test needs to set state that only a service owns,
add a `TestHooks.registerCommand` in that service's `init()` rather than a
game-specific debug remote. Give handlers plain arguments (a player's `Name`, not the
`Player`), so the same command also works through attributes.

**When `execute_luau` is sandboxed** (no `require`, no Bindable invokes; see
`roblox-studio-mcp`), call a command through attributes instead. This also reaches
commands a client controller registered (Client datamodel, on the `LocalPlayer`):

```lua
local target = game:GetService("ServerStorage") -- client: game.Players.LocalPlayer
target:SetAttribute("Dev_setCrumbs_Done", false)
target:SetAttribute("Dev_setCrumbs", '["Player1", 5000]') -- JSON array of arguments
-- next call: poll until Dev_setCrumbs_Done is true, then read Dev_setCrumbs_Result
-- (the return value, non-strings as JSON, or "error: ...")
```

A game can register its smoke test as a command (`registerCommand("SmokeTest", ...)`), so
Tier 2 still runs while sandboxed.

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
  which is itself worth a `FRAMEWORK_FEEDBACK.md` entry if the framework
  didn't steer you to attributes (the fix is adopting `TestHooks`/attributes,
  not a cleverer inference).

## When not to use this

- Pure logic changes (math, formulas, config) → Tier 1 (`roblox-test`), no Studio
  needed.
- Fixed regression coverage after class/generator changes → Tier 2
  (`roblox-test`), not this — Tier 2 stays a stable, repeatable script; this skill
  is for one-off or exploratory scenarios.
- Static visual review of an asset with no interaction → `roblox-capture`.
