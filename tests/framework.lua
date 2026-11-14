--!strict
-- The framework's own headless checks (framework file; games don't edit it).
-- They hold for every game built on this template. Game tests go in the game's tests/specs/
-- (see runner.lua). Called by the runner with the game's GameConfig loader; the checks below
-- stay at the top level of the function (not re-indented) to keep their history readable.

local H = require("./harness")
local process = require("@lune/process")

-- The framework root as seen from the working directory (the game root): set by
-- scripts/framework.mk; games live two folders down.
local FRAMEWORK_ROOT = process.env.FRAMEWORK_ROOT or "../.."

return function(requireGameConfig: () -> any)

-- ---- GameConfig is plain Lua ----------------------------------------------
-- GameConfig must load under Lune and contain only plain values, so every config value
-- stays testable here. If this fails, store the engine type as a table and convert it
-- with Shared/ConfigTypes at the point of use.
H.section("GameConfig is plain Lua")
do
	local ok, GameConfig = pcall(requireGameConfig)
	H.check("GameConfig loads under Lune (no Vector3/Color3/Enum at load time)", ok)

	local PLAIN = { number = true, string = true, boolean = true, table = true }
	local function findNonPlain(value: any, path: string, seen: { [any]: boolean }): string?
		if not PLAIN[type(value)] then
			return path .. " (" .. type(value) .. ")"
		end
		if type(value) == "table" and not seen[value] then
			seen[value] = true
			for key, child in pairs(value) do
				local bad = findNonPlain(child, path .. "." .. tostring(key), seen)
				if bad then
					return bad
				end
			end
		end
		return nil
	end
	if ok then
		local bad = findNonPlain(GameConfig, "GameConfig", {})
		H.check("GameConfig holds only plain values" .. (bad and (": " .. bad) or ""), bad == nil)
	end
end

-- ---- ServiceLoader discovery ----------------------------------------------
-- Builds a Services tree with @lune/roblox and checks which modules ServiceLoader would
-- start. Nested Folders are searched; a ModuleScript's children (Rojo init.lua
-- submodules) are not services.
H.section("ServiceLoader discovery")
do
	local roblox = require("@lune/roblox")
	local ServiceLoader = require("../src/shared/ServiceLoader")

	local function make(className: string, name: string, parent: any)
		local inst = roblox.Instance.new(className)
		inst.Name = name
		inst.Parent = parent
		return inst
	end

	local services = make("Folder", "Services", nil)
	make("ModuleScript", "PlotService", services)
	local combat = make("Folder", "Combat", services)
	make("ModuleScript", "DamageService", combat)
	local inventory = make("ModuleScript", "InventoryService", services)
	make("ModuleScript", "Slots", inventory)
	make("Script", "NotAModule", services)

	local names = {}
	for _, module in ipairs(ServiceLoader.findModules(services)) do
		table.insert(names, module.Name)
	end
	H.eq("finds 3 services", #names, 3)
	H.eq("nested folder searched, sorted by path", names[1], "DamageService")
	H.eq("init.lua module included", names[2], "InventoryService")
	H.eq("top-level module included", names[3], "PlotService")

	-- Two modules with one name: start()'s name table would hide one, so start() warns.
	make("ModuleScript", "PlotService", combat)
	local dupes = ServiceLoader.duplicateNames(ServiceLoader.findModules(services))
	H.eq("duplicate name found once", #dupes, 1)
	H.eq("duplicate name reported", dupes[1], "PlotService")
	H.eq("no duplicates in distinct names", #ServiceLoader.duplicateNames({ services, combat }), 0)
end

-- ---- ServiceLoader init() phase -------------------------------------------
-- A yielding init() is caught (start() warns and waits for it); an error names the module.
H.section("ServiceLoader init() phase")
do
	local ServiceLoader = require("../src/shared/ServiceLoader")
	local ran = false
	H.eq("finished init() returns nil", ServiceLoader.beginInit("A", function()
		ran = true
	end), nil)
	H.check("init() ran synchronously", ran)

	local pending = ServiceLoader.beginInit("B", function()
		coroutine.yield()
	end)
	H.eq("yielding init() returns its thread", type(pending), "thread")

	local ok, err = pcall(ServiceLoader.beginInit, "Broken", function()
		error("boom")
	end)
	H.check("failing init() raises", not ok)
	H.check("error names the module", string.find(tostring(err), "Broken.init() failed", 1, true) ~= nil)
end

-- ---- LayoutMath (HUD layout rules used by Shared/LayoutCheck) ---------------
H.section("LayoutMath")
do
	local LayoutMath = require("../src/shared/LayoutMath")
	local a = { Name = "A", X = 0, Y = 0, W = 100, H = 40 }
	local b = { Name = "B", X = 100, Y = 0, W = 50, H = 40 }
	local c = { Name = "C", X = 90, Y = 10, W = 50, H = 40 }
	H.check("touching edges don't overlap", not LayoutMath.overlap(a, b))
	H.check("real overlaps are found", LayoutMath.overlap(a, c))
	H.eq("a clean layout has no problems", #LayoutMath.problems({ a, b }, 200, 100), 0)
	H.eq("an overlap and an off-screen element are both reported", #LayoutMath.problems({ a, c }, 120, 100), 2)
	H.eq("allowed pairs are skipped", #LayoutMath.problems({ a, c }, 200, 100, { ["C|A"] = true }), 0)
	H.eq("a wildcard allows any overlap", #LayoutMath.problems({ a, c }, 200, 100, { ["A|*"] = true }), 0)
	H.near("a large window keeps the chosen scale", LayoutMath.uiScale(1.15, 1920, 1080, 960, 540), 1.15)
	H.check("a narrow window shrinks the UI to fit", LayoutMath.uiScale(1, 665, 520, 960, 540) * 960 <= 665)
	H.near("the tighter axis wins", LayoutMath.uiScale(1, 2000, 270, 960, 540), 0.5)
end

-- ---- MockDataStore (src/framework) and the store contract ------------------------
-- The mock must behave like the real DataStore on everything the contract lists
-- (src/framework/StoreContract.lua); FrameworkSmokeTest runs the same cases in-engine.
H.section("MockDataStore follows the store contract")
do
	local MockDataStore = require("../src/framework/MockDataStore")
	local StoreContract = require("../src/framework/StoreContract")
	StoreContract.basic(MockDataStore.new, H)
	StoreContract.faults(MockDataStore.new, H)

	local service = MockDataStore.newService()
	H.check("the service stand-in gives the same store for the same name", service:GetDataStore("A") == service:GetDataStore("A"))
	H.check("the service stand-in separates names", service:GetDataStore("A") ~= service:GetDataStore("B"))
	H.check("the service stand-in says it is a mock", service.IsMock == true)
	H.check("newForStudio refuses to run outside Studio", not pcall(MockDataStore.newForStudio))
end

-- The mock is a development tool: only a game's DataService (its Studio fallback), its Tier 2
-- SmokeTest and its tests/ may use it. Anything else requiring it could ship fake storage to
-- real players.
H.section("MockDataStore is not used outside DataService, SmokeTest and tests")
do
	local fs = require("@lune/fs")
	local allowed = { ["DataService.lua"] = true, ["SmokeTest.lua"] = true }
	local offenders: { string } = {}
	local function walk(dir: string)
		for _, name in ipairs(fs.readDir(dir)) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif string.match(name, "%.luau?$") and not allowed[name] then
				if string.find(fs.readFile(path), "MockDataStore", 1, true) then
					table.insert(offenders, path)
				end
			end
		end
	end
	walk("src")
	H.check("only DataService.lua and SmokeTest.lua mention MockDataStore (found: " .. table.concat(offenders, ", ") .. ")", #offenders == 0)
end

-- ---- Every source file compiles ------------------------------------------------
-- Studio-only code (services, controllers, generators) never runs under Lune, so this is
-- the only headless check that catches a syntax error in it before Studio does.
H.section("Every src/ file compiles")
do
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	local count = 0
	local function walk(dir: string)
		for _, name in ipairs(fs.readDir(dir)) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif string.match(name, "%.luau?$") then
				count += 1
				local ok, err = pcall(luau.compile, fs.readFile(path))
				if not ok then
					H.check(path .. " compiles: " .. tostring(err), false)
				end
			end
		end
	end
	walk("src") -- the game's code
	walk(FRAMEWORK_ROOT .. "/src") -- the framework's (shared modules, FrameworkSmokeTest)
	H.check(count .. " files checked", count > 0)
end

-- ---- Balance toolkit (tests/lib/balance, roblox-game-modeling skill) -----------
H.section("Balance toolkit")
require("./lib/balance/BalanceLib.spec")(H, FRAMEWORK_ROOT)

end
