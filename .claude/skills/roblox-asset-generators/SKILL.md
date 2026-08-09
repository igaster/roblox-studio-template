---
name: roblox-asset-generators
description: Use when adding, prototyping, or shipping a visual/3D Roblox asset (model, tool, part, GUI) — e.g. "add a sword tool", "spawn a chest model", "create a new NPC model", "prototype a few weapon looks" — and there's no existing Studio instance to clone from yet. Covers both quick MCP-generated prototypes and the version-controlled generator-module pattern for shipping.
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
