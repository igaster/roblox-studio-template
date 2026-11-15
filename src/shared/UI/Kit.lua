--!strict
-- The framework's UI component library: panel, label, button, bar, chip, and the screen root.
-- Every builder takes a Theme first and returns its instance; `opts.parent` is optional (a
-- generator builds a tree top-down, so parenting a child as it is made is fine; the screen
-- itself is parented by the service that gives it to a player).
-- Synced to ReplicatedStorage.Shared.UI.Kit. A game builds its GUI generators from these and
-- takes its look from GameConfig.Ui (see ThemeSchema.lua); a component it lacks goes in the
-- game's own GUI/ folder, built from the same Theme.
--
-- The conventions the roblox-asset-generators skill used to state in prose are built in:
--   * one screen root: ScreenGui > Root (Frame) > everything, plus a UIScale (Kit.applyScale)
--   * one UICorner per object (corner() edits the existing one)
--   * buttons are never shorter than Ui.MinTouchSize
--   * text stays above Ui.MinTextSize (ThemeSchema.validate checks the tokens)
--   * a label with changing text sets `sample` so LayoutCheck measures its worst case
--   * button state (Disabled, Selected) is an attribute, so it can be read from outside

local Theme = require(script.Parent.Theme)
local ThemeSchema = require(script.Parent.ThemeSchema)

type Theme = Theme.Theme

local Kit = {}

export type Place = { size: UDim2?, position: UDim2?, anchor: Vector2?, parent: Instance? }

local function place(obj: GuiObject, opts: Place)
	obj.Size = opts.size or obj.Size
	obj.Position = opts.position or obj.Position
	obj.AnchorPoint = opts.anchor or obj.AnchorPoint
	obj.Parent = opts.parent
end

-- Round the corners of `obj`; a second call changes the existing UICorner instead of adding one
-- (two UICorners on one object: only one applies and the shape silently stays wrong).
local function corner(obj: GuiObject, radius: number?)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = obj
end
Kit.corner = corner

-- ScreenGui > Root > content. The client sets the scale with Kit.applyScale (only the client
-- knows its window), using LayoutMath.uiScale. `ScreenInsets` keeps the HUD below Roblox's top bar.
function Kit.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = displayOrder or 0
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = gui
	return gui
end

-- Scale the whole screen: UIScale shrinks or grows it, and Root is resized by the inverse so it
-- still fills the window.
function Kit.applyScale(gui: ScreenGui, scale: number)
	local uiScale = gui:FindFirstChild("Scale") :: UIScale
	local root = gui:FindFirstChild("Root") :: Frame
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

export type PanelOpts = Place & { className: string? } -- className "CanvasGroup": fades as one

function Kit.panel(theme: Theme, name: string, opts: PanelOpts?): Frame
	local o = opts or {}
	local f = Instance.new(o.className or "Frame") :: Frame
	f.Name = name
	f.BackgroundColor3 = theme:color("Panel")
	f.BackgroundTransparency = theme.ui.PanelTransparency
	f.BorderSizePixel = 0
	corner(f, theme.ui.Radius)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = theme.ui.Stroke
	stroke.Color = theme:color("PanelBorder")
	stroke.Parent = f
	local pad = Instance.new("UIPadding")
	local padding = UDim.new(0, theme.ui.Padding)
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = padding, padding, padding, padding
	pad.Parent = f
	place(f, o)
	return f
end

export type LabelOpts = {
	parent: Instance?,
	font: string?, -- "display" | "body"
	color: string?, -- colour role, default Text
	align: Enum.TextXAlignment?,
	outline: boolean?, -- stroke for text drawn over the 3D world
	sample: string?, -- worst-case text, for LayoutCheck
	className: string?,
}

function Kit.label(theme: Theme, name: string, text: string, token: string, opts: LabelOpts?): TextLabel
	local o = opts or {}
	local l = Instance.new(o.className or "TextLabel") :: TextLabel
	l.Name = name
	l.Text = text
	l.BackgroundTransparency = 1
	l.FontFace = theme:font(o.font)
	l.TextSize = theme:size(token)
	l.TextColor3 = theme:color(o.color or "Text")
	l.TextXAlignment = o.align or Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, theme:size(token) + 6)
	if o.sample then
		l:SetAttribute("LayoutSample", o.sample)
	end
	if o.outline then
		local s = Instance.new("UIStroke")
		s.Color = theme:color("TextOutline")
		s.Transparency = 0.3
		s.Thickness = 1.5
		s.Parent = l
	end
	l.Parent = o.parent
	return l
end

export type ButtonOpts = {
	parent: Instance?,
	token: string?, -- text size token, default Body
	variant: string?, -- a key of the theme's button variants, default "primary"
	width: number?, -- pixels, default 140
	sample: string?,
}

-- Colours for hover, pressed and disabled come from the variant; ButtonStates.bind (client)
-- wires them up. `Disabled` and `Selected` are attributes.
function Kit.button(theme: Theme, name: string, text: string, opts: ButtonOpts?): TextButton
	local o = opts or {}
	local variant = o.variant or "primary"
	local v = theme.variants[variant]
	assert(v, "Kit.button: unknown variant " .. variant)
	local token = o.token or "Body"
	local b = Kit.label(theme, name, text, token, {
		className = "TextButton",
		color = v.Text,
		align = Enum.TextXAlignment.Center,
		sample = o.sample,
	}) :: any
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = theme:color(v.Base)
	b.AutoButtonColor = false -- ButtonStates handles hover/pressed/disabled
	b.Size = UDim2.fromOffset(o.width or 140, ThemeSchema.buttonHeight(theme.ui, theme:size(token)))
	corner(b, theme.ui.Radius)
	b:SetAttribute("KitButton", true)
	b:SetAttribute("ButtonVariant", variant)
	b.Parent = o.parent
	return b
end

export type BarOpts = Place & {
	fill: string?, -- colour role, default Accent
	track: string?, -- colour role, default Track
	ghost: boolean?, -- a Danger strip behind Fill, for "just lost" damage trails
	label: string?,
	ticks: number?, -- divide the track into this many segments
}

-- Track with Fill (scale X = fraction), optional Ghost (behind Fill), Label and ticks.
function Kit.bar(theme: Theme, name: string, size: UDim2, opts: BarOpts?): Frame
	local o = opts or {}
	local radius = theme.ui.Radius
	local track = Instance.new("Frame")
	track.Name = name
	track.BackgroundColor3 = theme:color(o.track or "Track")
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	corner(track, radius)
	local function strip(stripName: string, role: string, z: number)
		local s = Instance.new("Frame")
		s.Name = stripName
		s.Size = UDim2.fromScale(1, 1)
		s.BackgroundColor3 = theme:color(role)
		s.BorderSizePixel = 0
		s.ZIndex = z
		corner(s, radius)
		s.Parent = track
	end
	if o.ghost then
		strip("Ghost", "Danger", 1)
	end
	strip("Fill", o.fill or "Accent", 2)
	local ticks = o.ticks or 0
	for i = 1, ticks - 1 do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. i
		tick.Size = UDim2.new(0, 2, 1, 0)
		tick.Position = UDim2.fromScale(i / ticks, 0)
		tick.BackgroundColor3 = theme:color("Track")
		tick.BackgroundTransparency = 0.4
		tick.BorderSizePixel = 0
		tick.ZIndex = 3
		tick.Parent = track
	end
	if o.label then
		local l = Kit.label(theme, "Label", o.label, "Small", { parent = track, align = Enum.TextXAlignment.Center, outline = true })
		l.Size = UDim2.fromScale(1, 1)
		l.ZIndex = 4
	end
	place(track, { size = size, position = o.position, anchor = o.anchor, parent = o.parent })
	return track
end

-- A small rounded tag. `role` is the colour role of its fill; the text colour is whichever
-- candidate reads best on it (ThemeSchema.readableText), so any role is safe to use.
function Kit.chip(theme: Theme, name: string, text: string, role: string, parent: Instance?): TextLabel
	local textRole = ThemeSchema.readableText(theme.ui, role)
	local c = Kit.label(theme, name, text, "Small", { color = textRole, align = Enum.TextXAlignment.Center })
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = theme:color(role)
	c.AutomaticSize = Enum.AutomaticSize.X
	c.Size = UDim2.fromOffset(0, theme:size("Small") + 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, theme.ui.Padding + 2)
	pad.PaddingRight = UDim.new(0, theme.ui.Padding + 2)
	pad.Parent = c
	corner(c)
	c.Parent = parent
	return c
end

return Kit
