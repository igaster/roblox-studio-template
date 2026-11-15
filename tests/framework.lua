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

-- ---- UI theme (src/shared/UI/ThemeSchema, used by Kit and a game's GameConfig.Ui) -------
H.section("UI ThemeSchema")
do
	local ThemeSchema = require("../src/shared/UI/ThemeSchema")
	local function copy(v: any): any
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, child in pairs(v) do
			c[k] = copy(child)
		end
		return c
	end

	H.eq("the default theme is valid", #ThemeSchema.validate(ThemeSchema.DEFAULT), 0)
	H.check("the default theme is recognised as the default", ThemeSchema.isDefault(copy(ThemeSchema.DEFAULT)))

	local custom = copy(ThemeSchema.DEFAULT)
	custom.Colors.Primary = { R = 200, G = 60, B = 60 }
	H.check("a changed theme is no longer the default", not ThemeSchema.isDefault(custom))
	H.eq("a non-table theme is one problem", #ThemeSchema.validate(nil), 1)

	local noRole = copy(ThemeSchema.DEFAULT)
	noRole.Colors.Danger = nil
	H.eq("a missing colour role is reported", #ThemeSchema.validate(noRole), 1)

	local badChannel = copy(ThemeSchema.DEFAULT)
	badChannel.Colors.Text = { R = 300, G = 0, B = 0 }
	H.eq("a colour channel over 255 is reported", #ThemeSchema.validate(badChannel), 1)

	local small = copy(ThemeSchema.DEFAULT)
	small.TextSizes.Small = 10
	H.eq("text below MinTextSize is reported", #ThemeSchema.validate(small), 1)

	local badVariant = copy(ThemeSchema.DEFAULT)
	badVariant.ButtonVariants = { fancy = { Base = "Primary", Hover = "Nope", Pressed = "Primary", Text = "OnPrimary" } }
	H.eq("a variant naming an unknown role is reported", #ThemeSchema.validate(badVariant), 1)

	local variants = ThemeSchema.buttonVariants(badVariant)
	H.check("defaults stay when a game adds a variant", variants.primary ~= nil and variants.fancy ~= nil)
	H.eq("a button is at least the touch size", ThemeSchema.buttonHeight(ThemeSchema.DEFAULT, 18), 44)
	H.eq("a tall text makes a taller button", ThemeSchema.buttonHeight(ThemeSchema.DEFAULT, 40), 58)

	-- Contrast (WCAG ratios: black on white is 21:1, anything on itself 1:1)
	local black, white = { R = 0, G = 0, B = 0 }, { R = 255, G = 255, B = 255 }
	H.near("black on white is 21:1", ThemeSchema.contrast(black, white), 21, 0.01)
	H.near("a colour on itself is 1:1", ThemeSchema.contrast(white, white), 1, 0.001)

	local lowText = copy(ThemeSchema.DEFAULT)
	lowText.Colors.Text = { R = 70, G = 74, B = 84 } -- near the panel colour
	local lowProblems = ThemeSchema.validate(lowText)
	H.check("low-contrast text is reported", #lowProblems >= 1 and string.find(lowProblems[1], "Text contrast", 1, true) ~= nil)

	local lowButton = copy(ThemeSchema.DEFAULT)
	lowButton.Colors.OnPrimary = { R = 255, G = 255, B = 255 } -- white on the bright default fill
	H.check("a button text that fails in some state is reported", #ThemeSchema.validate(lowButton) >= 1)

	local lowBar = copy(ThemeSchema.DEFAULT)
	lowBar.Colors.Accent = { R = 30, G = 34, B = 44 } -- the track's own colour
	H.check("a bar fill that vanishes into its track is reported", #ThemeSchema.validate(lowBar) >= 1)

	H.eq("dark text is chosen on a bright fill", ThemeSchema.readableText(ThemeSchema.DEFAULT, "Good"), "TextOutline")
	H.eq("light text is chosen on a dark fill", ThemeSchema.readableText(ThemeSchema.DEFAULT, "Track"), "Text")

	local v = ThemeSchema.DEFAULT_BUTTON_VARIANTS.primary
	local function roles(s: any)
		local state = { disabled = false, selected = false, pressed = false, hovered = false }
		for k, val in pairs(s) do
			state[k] = val
		end
		return ThemeSchema.buttonRoles(v, state)
	end
	H.eq("rest colour is Base", (roles({})), "Primary")
	H.eq("hover colour", (roles({ hovered = true })), "PrimaryHover")
	H.eq("pressed beats hover", (roles({ hovered = true, pressed = true })), "PrimaryPressed")
	H.eq("selected looks pressed", (roles({ selected = true })), "PrimaryPressed")
	H.eq("disabled beats everything", (roles({ disabled = true, pressed = true, hovered = true })), "Disabled")
end

-- ---- Level metrics and world palette (src/shared/LevelMetrics, WorldPalette) ---------------
H.section("LevelMetrics")
do
	local LevelMetrics = require("../src/shared/LevelMetrics")
	local m = {
		PlayerHeight = 5,
		PlayerWidth = 2,
		WalkSpeed = 16,
		JumpHeight = 7.2,
		DoorHeight = 8,
		DoorWidth = 6,
		CorridorWidth = 8,
		StepHeight = 1.5,
		SafetyMargin = 0.25,
		GridSize = 5,
	}
	H.eq("consistent metrics have no problems", #LevelMetrics.validate(m), 0)
	-- airTime = 2 * sqrt(2h / g) = 2 * sqrt(14.4 / 196.2) = 0.5418 s
	H.near("air time follows from jump height and gravity", LevelMetrics.airTime(m), 0.5418, 0.001)
	H.near("jump distance is walk speed times air time", LevelMetrics.jumpDistance(m), 16 * 0.5418, 0.02)
	H.near("a fair gap keeps the safety margin", LevelMetrics.maxGap(m), 16 * 0.5418 * 0.75, 0.02)
	H.near("a fair ledge keeps the safety margin", LevelMetrics.maxLedge(m), 5.4, 0.001)
	local moon = { Gravity = 98.1 }
	for k, v in pairs(m) do
		moon[k] = v
	end
	H.check("lower gravity lengthens the jump", LevelMetrics.jumpDistance(moon :: any) > LevelMetrics.jumpDistance(m))
	H.eq("snap rounds to the grid", LevelMetrics.snap(m, 12), 10)
	H.eq("snap rounds up past halfway", LevelMetrics.snap(m, 13), 15)

	local function broken(key: string, value: any)
		local c: any = {}
		for k, v in pairs(m) do
			c[k] = v
		end
		c[key] = value
		return #LevelMetrics.validate(c)
	end
	H.eq("a missing number is reported", broken("GridSize", nil), 1)
	H.eq("a door no taller than the player is reported", broken("DoorHeight", 5), 1)
	H.eq("a door no wider than the player is reported", broken("DoorWidth", 2), 1)
	H.eq("a corridor narrower than its door is reported", broken("CorridorWidth", 4), 1)
	H.eq("a step as tall as a jump is reported", broken("StepHeight", 7.2), 1)
	H.eq("a safety margin of 1 is reported", broken("SafetyMargin", 1), 1)
	H.eq("a non-table is one problem", #LevelMetrics.validate(nil), 1)
end

H.section("WorldPalette")
do
	local WorldPalette = require("../src/shared/WorldPalette")
	local good = {
		Ground = { R = 110, G = 110, B = 115 },
		Wall = { R = 150, G = 150, B = 155 },
		Prop = { R = 130, G = 120, B = 110 },
		Accent = { R = 70, G = 150, B = 220 },
		Interactable = { R = 240, G = 200, B = 60 },
		Hazard = { R = 220, G = 50, B = 50 },
		Goal = { R = 60, G = 120, B = 255 },
	}
	local function with(role: string, color: any)
		local c: any = {}
		for k, v in pairs(good) do
			c[k] = v
		end
		c[role] = color
		return c
	end

	H.eq("a distinct palette is valid", #WorldPalette.validate(good), 0)
	H.eq("a non-table is one problem", #WorldPalette.validate(nil), 1)
	H.eq("a missing role is reported", #WorldPalette.validate(with("Goal", nil)), 1)
	H.eq("a channel over 255 is reported", #WorldPalette.validate(with("Hazard", { R = 300, G = 0, B = 0 })), 1)
	H.check("a hazard that matches the ground is reported", #WorldPalette.validate(with("Hazard", { R = 112, G = 110, B = 115 })) >= 1)
	H.check("two gameplay roles that match are reported", #WorldPalette.validate(with("Goal", good.Hazard)) >= 1)
	H.check("tighter limits accept what the default rejects", #WorldPalette.validate(with("Hazard", { R = 112, G = 110, B = 150 }), { MinGameplayDistance = 10, MinLuminanceRatio = 1 }) == 0)

	-- Hue-only difference: red and green of equal brightness are hard to tell apart for some players.
	local redGreen = with("Goal", { R = 0, G = 140, B = 0 })
	redGreen.Hazard = { R = 200, G = 0, B = 0 }
	H.eq("a valid palette can still carry an advisory", #WorldPalette.validate(redGreen), 0)
	H.check("similar-brightness gameplay roles get an advisory", #WorldPalette.advisories(redGreen) >= 1)
	H.eq("an invalid palette gets no advisories", #WorldPalette.advisories(with("Goal", nil)), 0)
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
