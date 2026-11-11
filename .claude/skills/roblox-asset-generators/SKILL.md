---
name: roblox-asset-generators
description: Use when adding, prototyping, or shipping a visual/3D Roblox asset, level or UI (model, tool, part, greybox room or level, HUD/ScreenGui) — e.g. "add a sword tool", "spawn a chest model", "build the greybox room", "add a HUD" — or when creating or editing any file under AssetGenerators/, including when a plan task calls for a generator.
---

# Roblox Asset Generators

## Overview

Roblox 3D assets (models, tools, parts, meshes) normally live only in Studio and
aren't version-controlled. The workaround: build the asset procedurally in a
Luau module (a "generator"), so its structure lives in git like any other code.
The generator returns a plain `Instance` — it never parents itself, and it
never carries gameplay state.

## Visual consistency across assets

If `docs/design/STYLE_GUIDE.md` exists in the project, it's the canonical
source for colors/materials — read it before choosing any `Color3`/`Material`
value in a new generator, rather than picking freely per-asset. A project
without one is free-form; don't require a style guide to exist, just defer to
it when it does.

## Prototyping (MCP generative tools) vs. shipping (this skill)

Two legitimate paths for getting a new asset, for different purposes:

- **Prototyping/iterating on a look**: use `roblox-studio-mcp`'s generative tools
  (`generate_mesh`, `generate_material`, `generate_procedural_model`) to quickly try
  shapes, materials, or concepts directly in Studio. Fast, good for exploring
  options with the user, but the result is **not version-controlled, not
  deterministic, and not reviewable** — it lives only in the DataModel (or an
  uploaded asset), not in git.
- **Shipping/final asset**: once a design is picked (from a generative prototype,
  a reference image, or a plain description), convert it into a hand-written
  generator module following this skill's pattern below. This is what actually
  gets committed — regenerable, diffable, testable, and consistent with the rest
  of the codebase's "behavior = code" rule.

**Rule of thumb: prototype in B, ship in A.** Never let a generative-tool result
become the permanent asset without converting it to a generator module first —
even a rough procedural approximation (primitives standing in for the generated
shape, config-driven dimensions) is preferable to an asset with no source of
truth in git. If a generated mesh/material is genuinely needed as-is (too complex
to reasonably approximate procedurally), that's a deliberate exception — flag it
to the user rather than silently treating it as shipped.

## Directory Convention

```
ServerStorage/AssetGenerators/
├── GUI/<Name>Generator.lua
├── Models/<Name>Generator.lua
├── Parts/<Name>Generator.lua
└── Tools/<Name>Generator.lua
```

One file per asset, grouped by type. Module name matches the asset: a
`TreasureChest` model → `Models/TreasureChestGenerator.lua`.

## Core Pattern

```lua
-- ServerStorage/AssetGenerators/Tools/SwordGenerator.lua
--
-- Usage (Studio command bar):
--   local gen = require(game.ServerStorage.AssetGenerators.Tools.SwordGenerator)
--   gen.createSword().Parent = workspace

-- GameConfig.Sword = { HandleSize = { X = 1, Y = 4, Z = 1 }, Color = { R = 200, G = 200, B = 210 } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)
local ConfigTypes = require(ReplicatedStorage.Shared.ConfigTypes)

local SwordGenerator = {}

function SwordGenerator.createSword()
	local cfg = GameConfig.Sword
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.Grip = CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-90), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = ConfigTypes.vector3(cfg.HandleSize)
	handle.Color = ConfigTypes.color3(cfg.Color)
	handle.Anchored = false -- deliberate: a held tool must move with the character (rule 6)
	handle.Parent = tool

	return tool
end

return SwordGenerator
```

Rules the pattern depends on:

1. **`create<Name>()` builds and returns the instance — it does not parent it.**
   The caller (command bar, or a service script) decides where it goes:
   directly into `workspace`, or into a `ServerStorage.Assets` template folder
   for later `:Clone()`ing.
2. **Sizes, colors, damage, cooldowns — anything tunable — come from
   `GameConfig`, not hardcoded in the generator.** Same rule as the rest of the
   codebase; generators aren't an exception. `GameConfig` stores them as plain
   tables/strings; convert with `Shared.ConfigTypes` (`vector3`, `color3`, `udim2`,
   `enum`) inside the generator.
3. **The instance stays state-free.** If the asset later needs runtime state
   (e.g. `IsOpen`, `Cooling`), that's an attribute set by the class that owns
   the entity's behavior, not a field baked into the generator.
4. **Gameplay logic never builds instances inline.** A service script
   (`ServerScriptService/Services/*Service.lua`) requires the generator (or clones a
   template it produced) — it doesn't call `Instance.new` to build game
   objects itself. This is what keeps the asset regenerable and the logic
   testable independent of the visual.
5. **Staging is destroy-and-regenerate, never "create if missing".** Workspace content can
   be saved into the place file; an existence check then keeps serving that stale copy
   forever after the generator is fixed (this cost a whole investigation once). Destroy any
   existing staged instance and rebuild, every time.
6. **Set `Anchored` explicitly on every generated `BasePart`** (`true` for static and
   trigger geometry, `false` only for deliberately physics-driven parts). An unanchored
   `CanCollide = false` part falls through the world and is silently removed by
   `FallenPartsDestroyHeight` cleanup, which fires `AncestryChanged` but not `Destroying`:
   it looks like a mysterious vanishing-instance bug.

## Level generators

A greybox/prototype **level** (a room, an arena, a course) is generated too, with two
differences from a reusable asset:

- `build()` **owns a fixed home** (e.g. `workspace.HeistRoom`): it destroys any existing copy
  there and builds a new one. Rule 1's "don't parent" applies to reusable assets, not to
  levels.
- A service calls `build()` **on every server start**, unconditionally (rule 5). Never "build
  if missing".
- When real art is hand-placed in Studio, retire the generator; the place file owns the level
  from then on (`CLAUDE.md`, *What Rojo Syncs vs. What Studio Owns*).
- New places from Studio's Baseplate template have a Baseplate with its top at Y = 0: put
  generated floors slightly above it (`Greybox.FLOOR_TOP`, or remove the Baseplate) to avoid
  z-fighting.
- Use `ReplicatedStorage.Shared.Greybox` for the repetitive parts: `part` (anchored, smooth,
  colour from a `GameConfig` table), `folder`, `marker` (invisible position marker), `spawn`
  (the level's SpawnLocation; disables any other, such as the place file's). Keep
  game-specific helpers (signs, materials, effects) in the game's own generators.
- Prototype **lighting** (`Lighting` properties, atmosphere, sky) is set the same way: a
  generator applies it at every server start, with its values in `GameConfig`, until lighting
  is tuned by hand in Studio.

## Third-party assets

Sounds, meshes and decals from the Creator Store are referenced by id, not generated:

- Ids live in `GameConfig` (e.g. `GameConfig.Sounds.Grab = "rbxassetid://..."`); an empty id
  means "none", and the game must work silently without it.
- Prefer licensed sources: Roblox's partner audio libraries (descriptions say "Courtesy of …",
  e.g. Pro Sound Effects, APM Music) and Roblox-made assets. `search_asset`'s
  verified-creators filter isn't enough on its own: check each result's description and
  creator, and that it suits the game's audience.
- Check every id loads in a Play session (`ContentProvider:PreloadAsync`) before relying on
  it, and list the ids with their source in the feature spec.

## GUI generators

`ServerStorage` (where generators live) is invisible to clients, so a client controller can't
require a GUI generator. Pattern:

1. A server service builds the UI from `GUI/<Name>Generator.lua` and parents a copy into each
   player's `PlayerGui` on join (and on respawn if `ResetOnSpawn` is true).
2. The client controller (`Controllers/<Name>Controller.lua`) does
   `player:WaitForChild("PlayerGui"):WaitForChild("<Name>")` and binds to attributes/remotes.
   It never builds the UI itself.

**Screen UI always draws over in-world UI.** Every `ScreenGui` draws over every
`BillboardGui` (health bars, prompts, labels), whatever `ZIndex` or `DisplayOrder` say. So:
- keep screen plates small and near the edges; a wide bar at the top hides whatever is
  behind it in the world;
- make large plates semi-transparent (`CanvasGroup` with `GroupTransparency`). Fade them
  while world UI projects behind them (`Camera:WorldToViewportPoint` on the billboards'
  adornees, a few times a second);
- a layout check of screen rects can't see this; check it in Play with world UI behind the
  plate.

## Quick Reference

| Asset need | Directory | Typical root Instance |
|---|---|---|
| Static decoration, terrain prop | `Models/` | `Model` |
| Equippable item | `Tools/` | `Tool` |
| Single part / projectile | `Parts/` | `Part` |
| UI element | `GUI/` | `ScreenGui` / `Frame` |

## Common Mistakes

- **Building the asset inline in a service script** instead of a generator —
  makes the asset non-regenerable and couples visuals to gameplay logic.
- **Parenting inside `create<Name>()`** — forces every caller into the same
  destination; return the instance and let the caller parent it.
- **Hardcoding a size/color/stat instead of reading it from `GameConfig`** —
  breaks the single-source-of-truth convention the rest of the codebase
  follows.
- **A staging routine that only creates the asset "if missing"** — silently
  keeps serving stale, previously-saved `Workspace` content forever after a
  generator fix, since the existence check skips regeneration. Destroy and
  regenerate unconditionally instead.
- **Forgetting `Anchored = true` on a generated `BasePart`** — it falls under
  gravity, and if `CanCollide = false` it can fall far enough to trigger
  Roblox's fallen-parts cleanup, silently vanishing with an `AncestryChanged`
  event but no `Destroying` — a genuinely confusing bug to debug from the
  symptom alone. Set `Anchored` explicitly on every generated part, don't
  rely on the engine default.
