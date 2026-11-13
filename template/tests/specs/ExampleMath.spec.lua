--!strict
-- SAMPLE game spec (game file): tests the template's sample module Modules/ExampleMath.
-- Delete it, together with ExampleMath.lua, once the game has real specs of its own.
--
-- tests/run.lua finds every tests/specs/*.spec.lua and calls the returned function with the
-- shared harness (tests/harness.lua): H.check, H.eq, H.near, H.section. Paths in require()
-- are relative to this file.

local ExampleMath = require("../../src/game/ReplicatedStorage/Modules/ExampleMath")

return function(H)
	H.eq("clamp below min", ExampleMath.clamp(-5, 0, 10), 0)
	H.eq("clamp above max", ExampleMath.clamp(42, 0, 10), 10)
	H.eq("clamp within range", ExampleMath.clamp(7, 0, 10), 7)

	H.near("lerp start", ExampleMath.lerp(0, 100, 0), 0)
	H.near("lerp mid", ExampleMath.lerp(0, 100, 0.5), 50)
	H.near("lerp end", ExampleMath.lerp(0, 100, 1), 100)
	H.near("lerp clamps t past 1", ExampleMath.lerp(0, 100, 2), 100)

	H.eq("stageForRatio 0 -> 1", ExampleMath.stageForRatio(0, 5), 1)
	H.eq("stageForRatio 1 -> 5", ExampleMath.stageForRatio(1, 5), 5)
	H.eq("stageForRatio 0.5 -> 3", ExampleMath.stageForRatio(0.5, 5), 3)
	H.eq("stageForRatio clamps >1", ExampleMath.stageForRatio(2, 5), 5)
end
