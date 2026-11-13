--!strict
-- This game's Tier 1 entry point (`make test`). The runner is the framework's
-- (../../tests/runner.lua); this file only hands it the game's specs and GameConfig, which it
-- can't require itself because Lune resolves requires relative to the requiring file.
-- Game specs go in tests/specs/<Name>.spec.lua (see the runner's header).
local run = require("@framework/tests/runner")

run({
	requireSpec = function(name: string): any
		return require("./specs/" .. name)
	end,
	requireGameConfig = function(): any
		return require("../src/game/ReplicatedStorage/GameConfig")
	end,
})
