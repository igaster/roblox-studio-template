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

-- World: named constants tied to the map or environment
GameConfig.World = {}

-- Economy: any in-game currency or resource values
GameConfig.Economy = {}

return GameConfig
