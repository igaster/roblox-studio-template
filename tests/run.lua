--!strict
-- Entry point for the headless Lune tests (framework file; games don't edit it):
--
--   lune run tests/run.lua          (from the project root; `make test`)
--   lune run tests/run.lua --slow   (also runs *.slow.spec.lua; `make test-all`)
--
-- Runs the framework's checks (tests/framework.lua), then every game spec in tests/specs/,
-- and exits 1 if any check failed.
--
-- Game tests go in tests/specs/<Name>.spec.lua, one file per module or topic, found
-- automatically. A spec returns a function that receives the harness (tests/harness.lua):
--
--   local TowerMath = require("../../src/game/ReplicatedStorage/Modules/TowerMath")
--   return function(H)
--       H.eq("cost at level 2", TowerMath.cost(2), 150)
--   end
--
-- Each spec gets a section named after its file; call H.section() inside for sub-sections.
-- Name long simulations <Name>.slow.spec.lua: they run only with --slow, so `make test`
-- stays fast. A spec that takes over a second prints its time.

local fs = require("@lune/fs")
local process = require("@lune/process")

local H = require("./harness")

local SPEC_DIR = "tests/specs"

require("./framework")

local function runSpec(moduleName: string)
	H.section(moduleName)
	local started = os.clock()
	local ok, err = pcall(function()
		local spec = require("./specs/" .. moduleName)
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
local function runSpecs(runSlow: boolean): number
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
			runSpec(moduleName)
		end
	end
	return skipped
end

local skipped = runSpecs(table.find(process.args, "--slow") ~= nil)
if skipped > 0 then
	print(string.format("\n(%d slow spec file(s) skipped; run with --slow or `make test-all`)", skipped))
end

H.finish()
