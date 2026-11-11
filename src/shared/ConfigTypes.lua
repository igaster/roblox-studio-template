-- shared/ConfigTypes.lua
--
-- GameConfig.lua holds only plain Lua values (numbers, strings, booleans, tables) so it
-- loads under Lune and every config value is testable headlessly (Tier 1). Engine
-- types are stored as plain tables and converted at the point of use with these:
--
--   GameConfig.Sword = { HandleSize = { X = 1, Y = 4, Z = 1 }, Color = { R = 200, G = 200, B = 210 },
--                        Material = "Metal" }
--   handle.Size     = ConfigTypes.vector3(GameConfig.Sword.HandleSize)
--   handle.Color    = ConfigTypes.color3(GameConfig.Sword.Color)
--   handle.Material = ConfigTypes.enum("Material", GameConfig.Sword.Material)
--
-- Only call these from engine-side code (generators, classes, services, controllers),
-- never from pure *Math modules.

local ConfigTypes = {}

local function field(value: any, key: string, typeName: string): number
	local v = value[key]
	if type(v) ~= "number" then
		error(string.format("ConfigTypes.%s: field %q must be a number, got %s", typeName, key, typeof(v)), 3)
	end
	return v
end

local function expectTable(value: any, typeName: string)
	if type(value) ~= "table" then
		error(string.format("ConfigTypes.%s: expected a table, got %s", typeName, typeof(value)), 3)
	end
end

-- { X, Y, Z } → Vector3
function ConfigTypes.vector3(value: { X: number, Y: number, Z: number }): Vector3
	expectTable(value, "vector3")
	return Vector3.new(field(value, "X", "vector3"), field(value, "Y", "vector3"), field(value, "Z", "vector3"))
end

-- { X, Y } → Vector2
function ConfigTypes.vector2(value: { X: number, Y: number }): Vector2
	expectTable(value, "vector2")
	return Vector2.new(field(value, "X", "vector2"), field(value, "Y", "vector2"))
end

-- { R, G, B } with 0–255 channels → Color3
function ConfigTypes.color3(value: { R: number, G: number, B: number }): Color3
	expectTable(value, "color3")
	return Color3.fromRGB(field(value, "R", "color3"), field(value, "G", "color3"), field(value, "B", "color3"))
end

-- { XScale, XOffset, YScale, YOffset } → UDim2 (GUI sizes/positions)
function ConfigTypes.udim2(value: { XScale: number, XOffset: number, YScale: number, YOffset: number }): UDim2
	expectTable(value, "udim2")
	return UDim2.new(
		field(value, "XScale", "udim2"),
		field(value, "XOffset", "udim2"),
		field(value, "YScale", "udim2"),
		field(value, "YOffset", "udim2")
	)
end

-- ("Material", "Neon") → Enum.Material.Neon
function ConfigTypes.enum(enumName: string, itemName: string): EnumItem
	local ok, item = pcall(function()
		return (Enum :: any)[enumName][itemName]
	end)
	if not ok or item == nil then
		error(string.format("ConfigTypes.enum: Enum.%s.%s does not exist", tostring(enumName), tostring(itemName)), 2)
	end
	return item
end

return ConfigTypes
