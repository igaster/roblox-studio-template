-- Central configuration for all game settings.
-- Add your game-specific config tables here and require this module wherever needed.
--
-- PLAIN LUA ONLY: numbers, strings, booleans and tables. No Vector3, Color3, UDim2,
-- CFrame or Enum values. This keeps GameConfig loadable under Lune, so Tier 1 tests can
-- read real config values (tests/framework.lua fails if this rule is broken). Store engine
-- types as tables and convert where they're used, with ReplicatedStorage.Shared.ConfigTypes:
--   Size = { X = 1, Y = 4, Z = 1 }      → ConfigTypes.vector3(cfg.Size)
--   Color = { R = 255, G = 200, B = 0 } → ConfigTypes.color3(cfg.Color)
--   Material = "Neon"                   → ConfigTypes.enum("Material", cfg.Material)

local GameConfig = {}

-- Example entity config structure:
-- GameConfig.Characters = {
--   Hero = {
--     MaxHealth = 100,
--     MoveSpeed = 16,
--     JumpPower = 50,
--   },
-- }

-- Entities: define stats for any game actors (players, NPCs, mobs, vehicles, etc.)
GameConfig.Characters = {}

-- Items: weapons, tools, collectibles, power-ups
GameConfig.Items = {}

-- Rounds/sessions: duration, scoring, win conditions
GameConfig.Rounds = {}

-- Metrics: the sizes a level is built from (see `roblox-asset-generators`, references/levels.md).
-- These are starting values for the default R15 avatar; measure your own avatar and movement and
-- change them. Generators read them instead of guessing sizes, and `Shared.LevelMetrics` derives
-- the widest fair gap and ledge from them.
GameConfig.Metrics = {
	PlayerHeight = 5, -- studs, standing
	PlayerWidth = 2,
	WalkSpeed = 16, -- studs/s
	JumpHeight = 7.2, -- studs a jump rises
	DoorHeight = 8, -- clear opening
	DoorWidth = 6,
	CorridorWidth = 8,
	StepHeight = 1.5, -- tallest step walked up without jumping
	SafetyMargin = 0.25, -- share of a jump's reach a fair gap leaves unused
	GridSize = 5, -- studs; level pieces are placed and sized in multiples of it
}

-- World: named constants tied to the map or environment
GameConfig.World = {
	-- Colour roles for generated levels and props (references/art-direction.md). Generators pick a
	-- role, not a raw colour. Replace these neutral greyboxing colours with the game's own.
	Palette = {
		Ground = { R = 110, G = 110, B = 115 },
		Wall = { R = 150, G = 150, B = 155 },
		Prop = { R = 130, G = 120, B = 110 },
		Accent = { R = 70, G = 150, B = 220 },
		Interactable = { R = 240, G = 200, B = 60 },
		Hazard = { R = 220, G = 50, B = 50 },
		Goal = { R = 120, G = 220, B = 255 },
	},
}

-- Economy: any in-game currency or resource values
GameConfig.Economy = {}

return GameConfig
