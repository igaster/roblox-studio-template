---
name: roblox-asset-generators
description: Use when adding a new visual/3D Roblox asset (model, tool, part, GUI) to a Rojo-synced project — e.g. "add a sword tool", "spawn a chest model", "create a new NPC model" — and there's no existing Studio instance to clone from yet.
---

# Roblox Asset Generators

## Overview

Roblox 3D assets (models, tools, parts, meshes) normally live only in Studio and
aren't version-controlled. The workaround: build the asset procedurally in a
Luau module (a "generator"), so its structure lives in git like any other code.
The generator returns a plain `Instance` — it never parents itself, and it
never carries gameplay state.

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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local SwordGenerator = {}

function SwordGenerator.createSword()
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.Grip = CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(-90), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = GameConfig.Sword.HandleSize
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
   codebase; generators aren't an exception.
3. **The instance stays state-free.** If the asset later needs runtime state
   (e.g. `IsOpen`, `Cooling`), that's an attribute set by the class that owns
   the entity's behavior, not a field baked into the generator.
4. **Gameplay logic never builds instances inline.** A service script
   (`ServerScriptService/*.server.lua`) requires the generator (or clones a
   template it produced) — it doesn't call `Instance.new` to build game
   objects itself. This is what keeps the asset regenerable and the logic
   testable independent of the visual.

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
