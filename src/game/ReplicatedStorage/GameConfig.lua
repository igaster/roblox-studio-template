-- Central configuration for all game settings.
-- Tower/enemy model names in Studio must match the keys used here.

local GameConfig = {}

-- Example tower config structure:
-- GameConfig.Towers = {
--   BasicTower = {
--     Cost = 100,
--     Damage = 10,
--     Range = 20,
--     FireRate = 1.0,
--   },
-- }

GameConfig.Towers = {}

GameConfig.Enemies = {}

GameConfig.Waves = {}

GameConfig.Map = {
  WaypointFolder = "Waypoints", -- Folder name inside the map model containing waypoints
}

GameConfig.Economy = {
  StartingGold = 200,
  BaseGoldPerKill = 10,
}

return GameConfig
