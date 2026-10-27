-- In-engine integration smoke test. Drives the REAL classes / asset generators with
-- real Instances inside the Roblox runtime and asserts the full gameplay loop end to
-- end. Complements the headless Lune tests (tests/suite.lua), which cover only the pure
-- math.
--
-- This is a ModuleScript (no ".server") so it never auto-runs. Run it manually from
-- the Studio command bar (edit mode, no Play needed):
--
--   require(game.ServerScriptService.SmokeTest).run()
--
-- Prints per-step PASS/FAIL and a summary to the Output window.
--
-- Game checks don't go in this file: add ModuleScripts under
-- ServerScriptService/SmokeTests/, which this runner discovers and runs in name order.
-- Each one returns a function that receives `check(name, cond)`:
--
--   return function(check)
--       local match = Match.new(...)
--       match:update(30)
--       check("wave started", match.wave == 1)
--   end
--
-- Inside each module: require your classes, build real Instances via the
-- AssetGenerators, fast-forward any time-based state, and assert the observable
-- results. Clean up any Instances you create.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExampleMath = require(ReplicatedStorage.Modules.ExampleMath)

local SmokeTest = {}

function SmokeTest.run()
	local passed, failed = 0, 0
	local function check(name, cond)
		if cond then
			passed += 1
			print("  PASS: " .. name)
		else
			failed += 1
			warn("  FAIL: " .. name)
		end
	end

	print("=== smoke test ===")

	-- Example placeholder assertion so the harness runs out of the box. Game checks go
	-- in SmokeTests/ (see header), not here.
	check("ExampleMath reachable from the engine", ExampleMath.clamp(99, 0, 10) == 10)

	local folder = script.Parent:FindFirstChild("SmokeTests")
	local modules = folder and folder:GetChildren() or {}
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	for _, module in ipairs(modules) do
		if module:IsA("ModuleScript") then
			print("-- " .. module.Name)
			local ok, err = pcall(function()
				require(module)(check)
			end)
			check(module.Name .. " ran without error: " .. tostring(err), ok)
		end
	end

	print(string.format("=== %d passed, %d failed ===", passed, failed))
	if failed == 0 then
		print("SMOKE TEST OK")
	else
		warn("SMOKE TEST FAILED")
	end
	return failed == 0
end

return SmokeTest
