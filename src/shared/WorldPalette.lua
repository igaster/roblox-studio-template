--!strict
-- Pure world-palette rules: the colour ROLES a level and its props are built from, and checks
-- that the roles the player must tell apart really can be told apart. A game keeps its palette in
-- `GameConfig.World.Palette` ({ R, G, B } tables, 0-255) and generators pick a role, never a
-- raw colour. No engine types, so the rules also run under Lune.
-- Synced to ReplicatedStorage.Shared.WorldPalette.
--
-- The two functions mirror how the framework tags rules:
--   validate(palette)   hard problems (a missing role, roles too close to tell apart): a test fails
--   advisories(palette) things worth a look (roles that differ only in hue): never a failure
--
-- The thresholds below are this framework's heuristics for "readable at a glance", not Roblox or
-- accessibility-standard numbers. A game may tune them by passing its own `limits`.

local WorldPalette = {}

-- The roles a generator may ask for. Gameplay roles carry information the player must read;
-- the others are scenery.
WorldPalette.ROLES = { "Ground", "Wall", "Prop", "Accent", "Interactable", "Hazard", "Goal" }
WorldPalette.GAMEPLAY_ROLES = { "Interactable", "Hazard", "Goal" }

export type Limits = {
	MinGameplayDistance: number, -- RGB distance a gameplay role keeps from scenery and from the other gameplay roles
	MinLuminanceRatio: number, -- advisory: gameplay roles closer than this in brightness rely on hue alone
}

WorldPalette.DEFAULT_LIMITS = { MinGameplayDistance = 70, MinLuminanceRatio = 1.4 }

local function isChannel(v: any): boolean
	return type(v) == "number" and v >= 0 and v <= 255
end

local function isColor(c: any): boolean
	return type(c) == "table" and isChannel(c.R) and isChannel(c.G) and isChannel(c.B)
end

local function distance(a: any, b: any): number
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2)
end

-- WCAG relative luminance (the same formula as UI/ThemeSchema; pure modules don't require each
-- other, so it's repeated here).
local function luminance(c: any): number
	local function ch(v: number): number
		local s = v / 255
		return if s <= 0.03928 then s / 12.92 else ((s + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * ch(c.R) + 0.7152 * ch(c.G) + 0.0722 * ch(c.B)
end

local function ratio(a: any, b: any): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

function WorldPalette.validate(palette: any, limits: Limits?): { string }
	if type(palette) ~= "table" then
		return { "GameConfig.World.Palette must be a table" }
	end
	local lim = limits or WorldPalette.DEFAULT_LIMITS
	local problems: { string } = {}
	for _, role in ipairs(WorldPalette.ROLES) do
		if not isColor(palette[role]) then
			table.insert(problems, "World.Palette." .. role .. " must be { R, G, B } with 0-255 channels")
		end
	end
	if #problems > 0 then
		return problems
	end
	for _, role in ipairs(WorldPalette.GAMEPLAY_ROLES) do
		for _, other in ipairs({ "Ground", "Wall" }) do
			if distance(palette[role], palette[other]) < lim.MinGameplayDistance then
				table.insert(problems, string.format("%s is too close to %s to read at a glance", role, other))
			end
		end
	end
	local gameplay = WorldPalette.GAMEPLAY_ROLES
	for i = 1, #gameplay do
		for j = i + 1, #gameplay do
			if distance(palette[gameplay[i]], palette[gameplay[j]]) < lim.MinGameplayDistance then
				table.insert(problems, string.format("%s and %s are too close to tell apart", gameplay[i], gameplay[j]))
			end
		end
	end
	return problems
end

-- Gameplay roles that differ in hue but not in brightness: players with colour-vision
-- differences may read them as one colour. Not a failure; pair them with a shape, icon or label.
function WorldPalette.advisories(palette: any, limits: Limits?): { string }
	local lim = limits or WorldPalette.DEFAULT_LIMITS
	local notes: { string } = {}
	if #WorldPalette.validate(palette, limits) > 0 then
		return notes
	end
	local gameplay = WorldPalette.GAMEPLAY_ROLES
	for i = 1, #gameplay do
		for j = i + 1, #gameplay do
			if ratio(palette[gameplay[i]], palette[gameplay[j]]) < lim.MinLuminanceRatio then
				table.insert(notes, string.format("%s and %s are similar in brightness: don't rely on colour alone", gameplay[i], gameplay[j]))
			end
		end
	end
	return notes
end

return WorldPalette
