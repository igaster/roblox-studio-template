--!strict
-- The headless Lune test runner (framework file; games don't edit it). Each game's
-- tests/run.lua calls it from the game root:
--
--   lune run tests/run.lua          (from the game folder; `make test`)
--   lune run tests/run.lua --slow   (also runs *.slow.spec.lua; `make test-all`)
--
-- Runs the framework's checks (tests/framework.lua), then every game spec in the game's
-- tests/specs/, and exits 1 if any check failed. Lune resolves requires relative to the
-- requiring file, so the game's run.lua passes in how to require its specs and GameConfig.
--
-- Game tests go in tests/specs/<Name>.spec.lua, one file per module or topic, found
-- automatically. A spec returns a function that receives the harness (tests/harness.lua):
--
--   local TowerMath = require("../../src/game/ReplicatedStorage/Modules/TowerMath")
--   return function(H)
--       H.eq("cost at level 2", TowerMath.cost(2), 150)
--   end
--
-- Framework libraries are required through the game's `@framework` alias (.luaurc), e.g.
-- require("@framework/tests/lib/balance/Parallel").
--
-- Each spec gets a section named after its file; call H.section() inside for sub-sections.
-- Name long simulations <Name>.slow.spec.lua: they run only with --slow, so `make test`
-- stays fast. A spec that takes over a second prints its time.

local fs = require("@lune/fs")
local process = require("@lune/process")

local H = require("./harness")
local frameworkChecks = require("./framework")

export type Options = {
	requireSpec: (name: string) -> any,
	requireGameConfig: () -> any,
}

local SPEC_DIR = "tests/specs"

local function runSpec(options: Options, moduleName: string)
	H.section(moduleName)
	local started = os.clock()
	local ok, err = pcall(function()
		local spec = options.requireSpec(moduleName)
		assert(type(spec) == "function", "a spec must return function(H)")
		spec(H)
	end)
	H.check(moduleName .. " ran without error" .. (if ok then "" else ": " .. tostring(err)), ok)
	local seconds = os.clock() - started
	if seconds > 1 then
		print(string.format("  (%s took %.1f s)", moduleName, seconds))
	end
end

-- Returns how many slow specs were skipped.
local function runSpecs(options: Options, runSlow: boolean): number
	if not fs.isDir(SPEC_DIR) then
		return 0
	end
	local names = fs.readDir(SPEC_DIR)
	table.sort(names)
	local skipped = 0
	for _, name in ipairs(names) do
		local moduleName = string.match(name, "^(.+%.spec)%.luau?$")
		if moduleName and string.find(moduleName, "%.slow%.spec$") and not runSlow then
			skipped += 1
		elseif moduleName then
			runSpec(options, moduleName)
		end
	end
	return skipped
end

return function(options: Options)
	frameworkChecks(options.requireGameConfig)
	local skipped = runSpecs(options, table.find(process.args, "--slow") ~= nil)
	if skipped > 0 then
		print(string.format("\n(%d slow spec file(s) skipped; run with --slow or `make test-all`)", skipped))
	end
	H.finish()
end
