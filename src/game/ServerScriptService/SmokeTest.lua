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
-- This is a template. Replace the example checks below with your game's real loop:
-- require your classes, build real Instances via the AssetGenerators, fast-forward any
-- time-based state, and assert the observable results.

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

	-- Example placeholder assertion so the harness runs out of the box. Swap this for
	-- real setup: PlayerClass.new(...), a generated model, fast-forwarded state, etc.
	check("ExampleMath reachable from the engine", ExampleMath.clamp(99, 0, 10) == 10)

	print(string.format("=== %d passed, %d failed ===", passed, failed))
	if failed == 0 then
		print("SMOKE TEST OK")
	else
		warn("SMOKE TEST FAILED")
	end
	return failed == 0
end

return SmokeTest
