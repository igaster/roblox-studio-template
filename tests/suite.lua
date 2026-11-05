--!strict
-- Headless unit tests for the project's PURE gameplay logic. Modules under
-- ReplicatedStorage/Modules that have no Roblox dependencies run here under Lune
-- with no Studio needed.
--
-- Run:  lune run tests/suite.lua    (from the project root)
--
-- Exits with code 1 if any assertion fails, so it can gate CI / pre-commit.
--
-- Game tests don't go in this file: put them in tests/specs/<Name>.spec.lua, which
-- this suite discovers and runs automatically. Keeping game tests out of this file
-- means framework updates to the harness never conflict with a game's tests.
--
-- A spec module returns a function that receives the harness:
--
--   return function(t)
--       t.eq("adds", 1 + 1, 2)
--       t.near("lerps", 0.5, 0.5)
--       t.check("truthy", true)
--   end
--
-- The ExampleMath block and the CI smoke check below are sample tests kept for
-- reference; delete them once the game has real specs.

local fs = require("@lune/fs")
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
-- Dummy assertion kept as a minimal sample of the pattern — replace with a real
-- check or delete once the suite has genuine assertions of its own.
print("CI smoke check")
eq("dummy: 1 + 1", 1 + 1, 2)

-- ---- discovered specs (tests/specs/*.spec.lua) ---------------------------
-- Specs named *.slow.spec.lua (long simulations) run only with --slow, so the everyday
-- `make test` stays fast. Each spec's time is printed when it takes over a second.
local harness = { check = check, eq = eq, near = near }
local SPEC_DIR = "tests/specs"
local runSlow = table.find(process.args, "--slow") ~= nil
local skippedSlow = 0
if fs.isDir(SPEC_DIR) then
	local names = fs.readDir(SPEC_DIR)
	table.sort(names)
	for _, name in ipairs(names) do
		local moduleName = string.match(name, "^(.+%.spec)%.luau?$")
		local slow = moduleName ~= nil and string.find(moduleName, "%.slow%.spec$") ~= nil
		if moduleName and slow and not runSlow then
			skippedSlow += 1
		elseif moduleName then
			local started = os.clock()
			local ok, err = pcall(function()
				require("./specs/" .. moduleName)(harness)
			end)
			local seconds = os.clock() - started
			print(if seconds > 1 then string.format("%s (%.1f s)", moduleName, seconds) else moduleName)
			check(moduleName .. " ran without error: " .. tostring(err), ok)
		end
	end
end
if skippedSlow > 0 then
	print(string.format("(%d slow spec file(s) skipped; run with --slow or `make test-all`)", skippedSlow))
end

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
