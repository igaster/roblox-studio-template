--!strict
-- SAMPLE game spec (game file): checks the game's level metrics and world palette with the
-- framework's pure rules. Keep it: a change to `GameConfig.Metrics` or `GameConfig.World.Palette`
-- that makes the numbers inconsistent (a door shorter than the player, a hazard the colour of the
-- ground) fails here instead of showing up as an unfair level. Palette advisories are printed,
-- never failed: they are things worth a look, not rules.

local GameConfig = require("../../src/game/ReplicatedStorage/GameConfig")
local LevelMetrics = require("@framework/src/shared/LevelMetrics")
local WorldPalette = require("@framework/src/shared/WorldPalette")

return function(H)
	H.section("GameConfig.Metrics is consistent")
	for _, problem in ipairs(LevelMetrics.validate(GameConfig.Metrics)) do
		H.check(problem, false)
	end
	H.check("the widest fair gap is positive", LevelMetrics.maxGap(GameConfig.Metrics) > 0)

	H.section("GameConfig.World.Palette is readable")
	for _, problem in ipairs(WorldPalette.validate(GameConfig.World.Palette)) do
		H.check(problem, false)
	end
	for _, note in ipairs(WorldPalette.advisories(GameConfig.World.Palette)) do
		print("  note: " .. note)
	end
end
