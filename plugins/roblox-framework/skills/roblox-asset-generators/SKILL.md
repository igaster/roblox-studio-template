---
name: roblox-asset-generators
description: Use when adding, prototyping, or shipping a visual/3D Roblox asset or level (model, tool, part, greybox room or level, world palette, lighting) — e.g. "add a sword tool", "spawn a chest model", "build the greybox room" — or when creating or editing any file under AssetGenerators/ except GUI/, including when a plan task calls for a generator. UI (HUD, ScreenGui, menus) is the roblox-ui skill.
---

# Roblox Asset Generators

## Overview

Roblox 3D assets (models, tools, parts, meshes) normally live only in Studio and
aren't version-controlled. The workaround: build the asset procedurally in a
Luau module (a "generator"), so its structure lives in git like any other code.
The generator returns a plain `Instance` — it never carries gameplay state.

**Firm rules and suggestions.** Two kinds of guidance live here and in `references/`:

- **Firm rules** are the ones marked *firm* below. Each guards a bug that is silent and costs a
  debugging session (a stale staged copy, a part that falls out of the world). Follow them.
- **Everything else is a suggestion.** It is the framework's best current advice (some from
  research, some from past games), not a requirement. Diverge when the game's look, feel or
  scale calls for it, and note why in the feature spec so the next chat doesn't undo it.

## A suggested workflow for a new asset or level

1. **Brief.** What is it, how big (from `GameConfig.Metrics`), and from what distance and
   angle will the player see it? A pickup seen from across a room needs a different silhouette
   than a prop seen up close.
2. **Prototype.** A greybox, or a generative tool (see *Prototyping vs shipping*), to settle
   the shape cheaply.
3. **Generator.** Ship it as code following *Core Pattern*.
4. **Look at it.** Capture it (`roblox-capture`) at gameplay distance, as a flat silhouette, and
   from a few angles. Judge shape first, then palette, then detail.
5. **Fix and repeat** until step 4 reads. Then move on; detail the player's space more than the
   background.

For levels, `references/levels.md` has the longer version; for the look of an asset,
`references/art-direction.md`.

## Visual consistency across assets

If `docs/design/STYLE_GUIDE.md` exists, it's the canonical source for colours, shape language
and materials — read it before choosing any `Color3`/`Material`. A project without one is
free-form; don't require it, but defer to it when it exists (a template is at
`../../docs/design/templates/style-guide.md`).

The world's colours are **roles** in `GameConfig.World.Palette` (Ground, Wall, Prop, Accent,
Interactable, Hazard, Goal): a generator picks a role and converts it with `Shared.ConfigTypes`,
instead of writing a raw colour, so one change restyles every asset. `Shared.WorldPalette`
checks that the roles a player must tell apart really differ, and the template's
`WorldRules.spec.lua` runs it.

## Prototyping (MCP generative tools) vs. shipping (this skill)

Two legitimate paths for getting a new asset:

- **Prototyping/iterating on a look**: use `roblox-studio-mcp`'s generative tools
  (`generate_mesh`, `generate_material`, `generate_procedural_model`) to try shapes,
  materials, or concepts directly in Studio. Fast, good for exploring options with the
  user, but the result is **not version-controlled, not deterministic, and not
  reviewable** — it lives only in the DataModel (or an uploaded asset).
- **Shipping/final asset**: once a design is picked, convert it into a hand-written
  generator module following this skill's pattern. This is what gets committed —
  regenerable, diffable, and consistent with "behavior = code".

**Rule of thumb: prototype in B, ship in A.** Even a rough procedural approximation
(primitives standing in for the generated shape, config-driven dimensions) is preferable
to an asset with no source of truth in git. If a generated mesh/material is genuinely needed
as-is (too complex to approximate procedurally), that's a deliberate exception — flag it to the
user rather than silently treating it as shipped.

## Directory Convention

```
ServerStorage/AssetGenerators/
├── GUI/<Name>Generator.lua      (see roblox-ui)
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

Guidance the pattern depends on (rules 5 and 6 are **firm**; the rest are suggestions):

1. **`create<Name>()` builds and returns the instance — it does not parent it.**
   The caller (command bar, or a service script) decides where it goes:
   directly into `workspace`, or into a `ServerStorage.Assets` template folder
   for later `:Clone()`ing.
2. **Sizes, colors, damage, cooldowns — anything tunable — come from
   `GameConfig`, not hardcoded in the generator.** `GameConfig` stores them as plain
   tables/strings; convert with `Shared.ConfigTypes` (`vector3`, `color3`, `udim2`,
   `enum`) inside the generator.
3. **The instance stays state-free.** If the asset later needs runtime state
   (e.g. `IsOpen`, `Cooling`), that's an attribute set by the class that owns
   the entity's behavior, not a field baked into the generator.
4. **Gameplay logic never builds instances inline.** A service script
   (`ServerScriptService/Services/*Service.lua`) requires the generator (or clones a
   template it produced) — it doesn't call `Instance.new` to build game
   objects itself. This keeps the asset regenerable and the logic testable
   independent of the visual.
5. **Firm: staging is destroy-and-regenerate, never "create if missing".** Workspace content
   can be saved into the place file; an existence check then keeps serving that stale copy
   forever after the generator is fixed (this cost a whole investigation once). Destroy any
   existing staged instance and rebuild, every time.
6. **Firm: set `Anchored` explicitly on every generated `BasePart`** (`true` for static and
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
  from then on (`CLAUDE.md`, *What Rojo Syncs vs. What Studio Owns*). Delete the greybox and the
  Baseplate at that point.
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
- Sizes come from `GameConfig.Metrics` and `Shared.LevelMetrics` (door and corridor widths, the
  widest fair gap, a grid to snap to), not from guesses. See `references/levels.md`.

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

## Quick Reference

| Asset need | Directory | Typical root Instance |
|---|---|---|
| Static decoration, terrain prop | `Models/` | `Model` |
| Equippable item | `Tools/` | `Tool` |
| Single part / projectile | `Parts/` | `Part` |
| UI element | `GUI/` | `ScreenGui` / `Frame` (see `roblox-ui`) |
| Greybox room or level | `Models/` or the game's level generator | `Folder` / `Model` with a fixed home |

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
  generator fix. Destroy and regenerate unconditionally instead.
- **Forgetting `Anchored = true` on a generated `BasePart`** — it falls under
  gravity, and if `CanCollide = false` it can fall far enough to trigger
  Roblox's fallen-parts cleanup, silently vanishing with an `AncestryChanged`
  event but no `Destroying` — a genuinely confusing bug to debug from the
  symptom alone. Set `Anchored` explicitly on every generated part, don't
  rely on the engine default.
- **Judging an asset only up close.** Look at it at the distance and angle the player sees it
  from (`roblox-capture`); a shape that reads at arm's length can vanish across a room.
