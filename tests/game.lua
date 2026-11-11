--!strict
-- The game's headless unit tests (game file): pure gameplay logic under
-- ReplicatedStorage/Modules and the real GameConfig, run under Lune with no Studio.
--
-- Run all tests:  lune run tests/run.lua    (from the project root; `make test`)
-- run.lua also runs the framework's own checks (tests/framework.lua) and prints the summary.
--
-- Add one block per *Math module, using the shared helpers from tests/harness.lua.

local H = require("./harness")
local eq, near = H.eq, H.near

-- ---- ExampleMath (SAMPLE) ---------------------------------------------------
-- A sample block that shows the pattern. It tests the template's sample module
-- Modules/ExampleMath. Safe to delete, together with ExampleMath.lua, once the game
-- has real tests of its own.
local ExampleMath = require("../src/game/ReplicatedStorage/Modules/ExampleMath")

H.section("ExampleMath (sample)")
eq("clamp below min", ExampleMath.clamp(-5, 0, 10), 0)
eq("clamp above max", ExampleMath.clamp(42, 0, 10), 10)
eq("clamp within range", ExampleMath.clamp(7, 0, 10), 7)

near("lerp start", ExampleMath.lerp(0, 100, 0), 0)
near("lerp mid", ExampleMath.lerp(0, 100, 0.5), 50)
near("lerp end", ExampleMath.lerp(0, 100, 1), 100)
near("lerp clamps t past 1", ExampleMath.lerp(0, 100, 2), 100)

eq("stageForRatio 0 -> 1", ExampleMath.stageForRatio(0, 5), 1)
eq("stageForRatio 1 -> 5", ExampleMath.stageForRatio(1, 5), 5)
eq("stageForRatio 0.5 -> 3", ExampleMath.stageForRatio(0.5, 5), 3)
eq("stageForRatio clamps >1", ExampleMath.stageForRatio(2, 5), 5)

return nil
