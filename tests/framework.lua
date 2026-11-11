--!strict
-- The framework's own headless checks (framework file; games don't edit it).
-- They hold for every game built on this template. Game tests go in tests/game.lua.

local H = require("./harness")

-- ---- GameConfig is plain Lua ----------------------------------------------
-- GameConfig must load under Lune and contain only plain values, so every config value
-- stays testable here. If this fails, store the engine type as a table and convert it
-- with Shared/ConfigTypes at the point of use.
H.section("GameConfig is plain Lua")
do
	local ok, GameConfig = pcall(require, "../src/game/ReplicatedStorage/GameConfig")
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

return nil
