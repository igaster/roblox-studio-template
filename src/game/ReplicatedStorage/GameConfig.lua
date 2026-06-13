-- Central configuration for all game settings.
-- Add your game-specific config tables here and require this module wherever needed.

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
