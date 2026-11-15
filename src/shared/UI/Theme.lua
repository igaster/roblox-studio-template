--!strict
-- Turns a game's validated `GameConfig.Ui` tokens into engine values (Color3, Font). Every
-- component in Kit.lua takes a Theme, so a game's look lives in one place: GameConfig.Ui.
-- Engine-side only (uses Color3/Font); the pure rules are in ThemeSchema.lua.
-- Synced to ReplicatedStorage.Shared.UI.Theme.
--
--   local theme = Theme.new(GameConfig.Ui)   -- errors, listing every problem, if the tokens are invalid
--   theme:color("Primary")                   -- Color3
--   theme:size("Body")                       -- number (text size at scale 1)

local ConfigTypes = require(script.Parent.Parent.ConfigTypes)
local ThemeSchema = require(script.Parent.ThemeSchema)

export type Variant = { Base: string, Hover: string, Pressed: string, Text: string }

export type Theme = {
	ui: any,
	variants: { [string]: Variant },
	color: (self: Theme, role: string) -> Color3,
	font: (self: Theme, kind: string?) -> Font,
	size: (self: Theme, token: string) -> number,
}

local Theme = {}
Theme.__index = Theme

function Theme.new(ui: any): Theme
	local problems = ThemeSchema.validate(ui)
	if #problems > 0 then
		error("Theme: invalid GameConfig.Ui:\n  " .. table.concat(problems, "\n  "), 2)
	end
	return setmetatable({ ui = ui, variants = ThemeSchema.buttonVariants(ui) }, Theme) :: any
end

function Theme.color(self: Theme, role: string): Color3
	local c = self.ui.Colors[role]
	assert(c, "Theme: unknown colour role " .. tostring(role))
	return ConfigTypes.color3(c)
end

-- "display" or "body" (default). Font.new never errors on a missing family: if it isn't
-- installed Roblox renders the default font, which still reads fine.
function Theme.font(self: Theme, kind: string?): Font
	local family = if kind == "display" then self.ui.DisplayFont else self.ui.BodyFont
	return Font.new("rbxasset://fonts/families/" .. family .. ".json", Enum.FontWeight.Bold)
end

function Theme.size(self: Theme, token: string): number
	return self.ui.TextSizes[token] or self.ui.TextSizes.Body
end

return Theme
