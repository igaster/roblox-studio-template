--!strict
-- Headless unit tests for the project's PURE gameplay logic. Modules under
-- ReplicatedStorage/Modules that have no Roblox dependencies run here under Lune
-- with no Studio needed.
--
-- Run:  lune run tests/run.lua      (from the project root)
--
-- Exits with code 1 if any assertion fails, so it can gate CI / pre-commit.
--
-- This ships wired to Modules/ExampleMath as a starting template. Point it at your
-- real `*Math` modules and grow the assertions as you add gameplay logic.

local process = require("@lune/process")

local ExampleMath = require("../src/game/ReplicatedStorage/Modules/ExampleMath")

-- ---- tiny test harness ---------------------------------------------------
local passed, failed = 0, 0
local failures = {}

local function check(name, cond)
	if cond then
		passed += 1
	else
		failed += 1
		table.insert(failures, name)
		print("  FAIL: " .. name)
	end
end

local function eq(name, actual, expected)
	check(name .. " (got " .. tostring(actual) .. ", want " .. tostring(expected) .. ")", actual == expected)
end

local function near(name, actual, expected, tol)
	tol = tol or 1e-6
	check(
		name .. " (got " .. tostring(actual) .. ", want ~" .. tostring(expected) .. ")",
		math.abs(actual - expected) <= tol
	)
end

-- ---- ExampleMath ---------------------------------------------------------
print("ExampleMath")
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

-- ---- CI smoke check -------------------------------------------------------
-- Dummy assertion to confirm the CI workflow actually executes this file.
-- Safe to remove once CI is verified working.
print("CI smoke check")
eq("dummy: 1 + 1", 1 + 1, 2)

-- ---- summary -------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("Failing tests:")
	for _, name in ipairs(failures) do
		print("  - " .. name)
	end
	process.exit(1)
end
print("All tests passed.")
