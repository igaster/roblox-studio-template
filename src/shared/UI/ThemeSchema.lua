--!strict
-- Pure UI-theme rules: the token shape a game's `GameConfig.Ui` must have, and a validator that
-- returns readable problems. No engine types, so the rules run under Lune (tests/framework.lua)
-- and a game's own tests can call `ThemeSchema.validate(GameConfig.Ui)`.
-- Synced to ReplicatedStorage.Shared.UI.ThemeSchema; Theme.lua turns validated tokens into
-- engine values.
--
-- Colors are named by ROLE (Panel, Primary, Danger), never by what they look like (Brass), so
-- every component works for every game's look. A game picks the values; the framework picks
-- the roles.

local ThemeSchema = {}

-- Every role a component may ask for. A theme without one fails validation, so a component
-- can never hit a missing colour at runtime.
ThemeSchema.COLOR_ROLES = {
	"Panel", -- panel background
	"PanelBorder", -- panel rim
	"Track", -- bar track, chip backdrop
	"Primary", -- main action fill
	"PrimaryHover",
	"PrimaryPressed",
	"OnPrimary", -- text on Primary
	"Disabled", -- fill of a disabled control
	"OnDisabled",
	"Text",
	"TextDim",
	"TextOutline", -- stroke behind text drawn over the 3D world
	"Accent", -- default bar fill
	"Danger",
	"DangerHover",
	"DangerPressed",
	"Warning",
	"Good",
}

ThemeSchema.TEXT_SIZES = { "Small", "Body", "Title", "Display" }

-- Button variants: which colour roles a button uses in each state. A game may add or replace
-- variants in `Ui.ButtonVariants`; these are the defaults.
ThemeSchema.DEFAULT_BUTTON_VARIANTS = {
	primary = { Base = "Primary", Hover = "PrimaryHover", Pressed = "PrimaryPressed", Text = "OnPrimary" },
	danger = { Base = "Danger", Hover = "DangerHover", Pressed = "DangerPressed", Text = "OnPrimary" },
	ghost = { Base = "Track", Hover = "PanelBorder", Pressed = "Track", Text = "Text" },
}

local NUMBER_FIELDS = { "MinTextSize", "MinTouchSize", "Radius", "Stroke", "Padding", "TweenSeconds", "PanelTransparency" }
local STRING_FIELDS = { "DisplayFont", "BodyFont" }

local function isChannel(v: any): boolean
	return type(v) == "number" and v >= 0 and v <= 255
end

local function isColor(v: any): boolean
	return type(v) == "table" and isChannel(v.R) and isChannel(v.G) and isChannel(v.B)
end

local function checkColors(ui: any, problems: { string })
	if type(ui.Colors) ~= "table" then
		table.insert(problems, "Ui.Colors must be a table")
		return
	end
	for _, role in ipairs(ThemeSchema.COLOR_ROLES) do
		if not isColor(ui.Colors[role]) then
			table.insert(problems, "Ui.Colors." .. role .. " must be { R, G, B } with 0-255 channels")
		end
	end
end

local function checkSizes(ui: any, problems: { string })
	if type(ui.TextSizes) ~= "table" then
		table.insert(problems, "Ui.TextSizes must be a table")
		return
	end
	for _, token in ipairs(ThemeSchema.TEXT_SIZES) do
		local size = ui.TextSizes[token]
		if type(size) ~= "number" or size <= 0 then
			table.insert(problems, "Ui.TextSizes." .. token .. " must be a positive number")
		elseif type(ui.MinTextSize) == "number" and size < ui.MinTextSize then
			table.insert(problems, string.format("Ui.TextSizes.%s (%d) is below Ui.MinTextSize (%d)", token, size, ui.MinTextSize))
		end
	end
end

local function checkVariants(ui: any, problems: { string })
	for name, variant in pairs(ui.ButtonVariants or {}) do
		for _, key in ipairs({ "Base", "Hover", "Pressed", "Text" }) do
			local role = type(variant) == "table" and variant[key]
			if type(role) ~= "string" or type(ui.Colors) ~= "table" or ui.Colors[role] == nil then
				table.insert(problems, string.format("Ui.ButtonVariants.%s.%s must name a colour role", tostring(name), key))
			end
		end
	end
end

-- ---- Contrast (WCAG 2.x relative luminance; Game Accessibility Guidelines) ----------------

ThemeSchema.MIN_TEXT_CONTRAST = 4.5 -- normal text on its background
ThemeSchema.MIN_GRAPHIC_CONTRAST = 3 -- bars, buttons and other non-text UI against what is behind them

local function channel(v: number): number
	local s = v / 255
	return if s <= 0.03928 then s / 12.92 else ((s + 0.055) / 1.055) ^ 2.4
end

function ThemeSchema.luminance(c: { R: number, G: number, B: number }): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

-- Contrast ratio, 1 (identical) to 21 (black on white).
function ThemeSchema.contrast(a: { R: number, G: number, B: number }, b: { R: number, G: number, B: number }): number
	local la, lb = ThemeSchema.luminance(a), ThemeSchema.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Text colour roles a component may put on an arbitrary fill (a chip), best first.
local READABLE_CANDIDATES = { "OnPrimary", "Text", "TextOutline" }

-- The colour role that reads best on `fillRole`: the candidate with the highest contrast.
function ThemeSchema.readableText(ui: any, fillRole: string): string
	local best, bestRatio = READABLE_CANDIDATES[1], 0
	for _, role in ipairs(READABLE_CANDIDATES) do
		local ratio = ThemeSchema.contrast(ui.Colors[role], ui.Colors[fillRole])
		if ratio > bestRatio then
			best, bestRatio = role, ratio
		end
	end
	return best
end

-- (foreground role, background role) pairs every component draws, as text.
local TEXT_PAIRS = { { "Text", "Panel" }, { "TextDim", "Panel" }, { "Text", "Track" }, { "TextDim", "Track" } }
-- Non-text pairs: bar fills over their track, and buttons over the panel they sit on.
local GRAPHIC_PAIRS = {
	{ "Accent", "Track" },
	{ "Danger", "Track" },
	{ "Warning", "Track" },
	{ "Good", "Track" },
	{ "Primary", "Panel" },
}

local function checkPair(ui: any, fg: string, bg: string, minimum: number, what: string, problems: { string })
	local ratio = ThemeSchema.contrast(ui.Colors[fg], ui.Colors[bg])
	if ratio < minimum then
		table.insert(problems, string.format("%s: %s on %s is %.1f:1, needs %.1f:1", what, fg, bg, ratio, minimum))
	end
end

-- Contrast problems of a structurally valid theme. Button text is checked against every state
-- the button shows; a disabled control is exempt (WCAG exempts inactive components).
local function checkContrast(ui: any, problems: { string })
	for _, pair in ipairs(TEXT_PAIRS) do
		checkPair(ui, pair[1], pair[2], ThemeSchema.MIN_TEXT_CONTRAST, "Text contrast", problems)
	end
	for _, pair in ipairs(GRAPHIC_PAIRS) do
		checkPair(ui, pair[1], pair[2], ThemeSchema.MIN_GRAPHIC_CONTRAST, "Graphic contrast", problems)
	end
	local names = {}
	for name in pairs(ThemeSchema.buttonVariants(ui)) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local v = ThemeSchema.buttonVariants(ui)[name]
		for _, state in ipairs({ "Base", "Hover", "Pressed" }) do
			checkPair(ui, v.Text, v[state], ThemeSchema.MIN_TEXT_CONTRAST, "Button '" .. name .. "' " .. state, problems)
		end
	end
end

-- Readable problems, empty when the theme is usable.
function ThemeSchema.validate(ui: any): { string }
	local problems: { string } = {}
	if type(ui) ~= "table" then
		return { "GameConfig.Ui must be a table" }
	end
	checkColors(ui, problems)
	for _, key in ipairs(NUMBER_FIELDS) do
		if type(ui[key]) ~= "number" then
			table.insert(problems, "Ui." .. key .. " must be a number")
		end
	end
	for _, key in ipairs(STRING_FIELDS) do
		if type(ui[key]) ~= "string" or ui[key] == "" then
			table.insert(problems, "Ui." .. key .. " must be a font family name")
		end
	end
	checkSizes(ui, problems)
	checkVariants(ui, problems)
	if #problems == 0 then -- contrast needs every role present and valid
		checkContrast(ui, problems)
	end
	return problems
end

-- The button variants a theme offers: the defaults, overridden or extended by the game's.
function ThemeSchema.buttonVariants(ui: any): { [string]: { [string]: string } }
	local merged: { [string]: { [string]: string } } = {}
	for name, variant in pairs(ThemeSchema.DEFAULT_BUTTON_VARIANTS) do
		merged[name] = variant
	end
	for name, variant in pairs(ui.ButtonVariants or {}) do
		merged[name] = variant
	end
	return merged
end

export type ButtonState = { disabled: boolean, selected: boolean, pressed: boolean, hovered: boolean }

-- The (fill, text) colour roles of a button in a state: disabled wins over selected/pressed,
-- which win over hover.
function ThemeSchema.buttonRoles(variant: { [string]: string }, state: ButtonState): (string, string)
	if state.disabled then
		return "Disabled", "OnDisabled"
	end
	local fill = if state.pressed or state.selected then variant.Pressed elseif state.hovered then variant.Hover else variant.Base
	return fill, variant.Text
end

-- The height a button needs: its text plus padding, never below the touch-target floor.
function ThemeSchema.buttonHeight(ui: any, textSize: number): number
	return math.max(textSize + 18, ui.MinTouchSize)
end

-- The framework's neutral default theme: valid, deliberately plain. A game copies this into its
-- own `GameConfig.Ui` and changes it; `isDefault` lets a test fail a game that ships it
-- untouched (every game should choose its own look).
ThemeSchema.DEFAULT = {
	Colors = {
		Panel = { R = 30, G = 34, B = 42 },
		PanelBorder = { R = 90, G = 98, B = 112 },
		Track = { R = 20, G = 22, B = 28 },
		-- Bright fills with dark text: white text fails 4.5:1 on a mid-tone fill in some state.
		Primary = { R = 95, G = 165, B = 255 },
		PrimaryHover = { R = 130, G = 190, B = 255 },
		PrimaryPressed = { R = 70, G = 135, B = 225 },
		OnPrimary = { R = 12, G = 14, B = 20 },
		Disabled = { R = 60, G = 64, B = 72 },
		OnDisabled = { R = 140, G = 146, B = 158 },
		Text = { R = 240, G = 242, B = 246 },
		TextDim = { R = 160, G = 166, B = 178 },
		TextOutline = { R = 10, G = 12, B = 16 },
		Accent = { R = 80, G = 190, B = 170 },
		Danger = { R = 245, G = 110, B = 100 },
		DangerHover = { R = 255, G = 140, B = 130 },
		DangerPressed = { R = 220, G = 90, B = 80 },
		Warning = { R = 240, G = 165, B = 70 },
		Good = { R = 110, G = 215, B = 130 },
	},
	DisplayFont = "GothamSSm",
	BodyFont = "GothamSSm",
	TextSizes = { Small = 18, Body = 22, Title = 28, Display = 48 },
	MinTextSize = 14, -- nothing renders smaller on screen
	MinTouchSize = 44, -- smallest height of anything tappable
	Radius = 8,
	Stroke = 2,
	Padding = 8,
	TweenSeconds = 0.2,
	PanelTransparency = 0.08,
}

local function sameValue(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not sameValue(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- True when a game's theme is the framework default, unchanged.
function ThemeSchema.isDefault(ui: any): boolean
	return sameValue(ui, ThemeSchema.DEFAULT)
end

return ThemeSchema
