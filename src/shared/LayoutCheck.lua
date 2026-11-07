-- Automated HUD layout check (client, Studio only). For each window size × UI scale ×
-- phase it clones the HUD's root frame into an off-screen frame of that size, shows the
-- elements that phase shows, fills labels with worst-case text, and checks with
-- LayoutMath that every visible top-level element is on screen and none overlap. A
-- deliberate "canary" overlap runs first, so a check that measures nothing fails loudly.
--
-- Conventions it relies on (see the roblox-asset-generators skill):
--   * The HUD is one ScreenGui whose content sits in a single root Frame with a UIScale
--     child; the root's direct GuiObject children are the layout elements.
--   * A label whose text varies sets the attribute LayoutSample to its longest text.
--   * An element whose own size is zero (an anchor) is measured as the union of its
--     visible children.
--
-- Usage, from a Studio-only LocalScript:
--   TestHooks.devCommand("LayoutCheck", function()
--       return LayoutCheck.run({ root = hud.Root, phases = {...}, ... })
--   end)

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local LayoutMath = require(script.Parent.LayoutMath)

local LayoutCheck = {}

LayoutCheck.DEFAULT_SIZES = { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }

local function fillSamples(root)
	for _, item in ipairs(root:GetDescendants()) do
		if (item:IsA("TextLabel") or item:IsA("TextButton")) and item:GetAttribute("LayoutSample") then
			item.Text = item:GetAttribute("LayoutSample")
		end
	end
end

-- The element and its visible direct children, as one rectangle relative to `origin`.
local function rectOf(element, origin)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local function add(gui)
		local p, s = gui.AbsolutePosition - origin, gui.AbsoluteSize
		if s.X > 0 and s.Y > 0 then
			minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
			maxX, maxY = math.max(maxX, p.X + s.X), math.max(maxY, p.Y + s.Y)
		end
	end
	add(element)
	for _, child in ipairs(element:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			add(child)
		end
	end
	if minX == math.huge then
		return nil
	end
	return { Name = element.Name, X = minX, Y = minY, W = maxX - minX, H = maxY - minY }
end

-- Measures one case and returns LayoutMath problems (strings).
local function measure(options, holder, width, height, step, phase, canary)
	local min = options.minSize or { width, height }
	local scale = LayoutMath.uiScale(step, width, height, min[1], min[2])
	holder.Size = UDim2.fromOffset(width, height)
	local root = options.root:Clone()
	local uiScale = root:FindFirstChildOfClass("UIScale")
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	local visible = {}
	for _, name in ipairs(options.always or {}) do
		visible[name] = true
	end
	for _, name in ipairs(options.phases[phase]) do
		visible[name] = true
	end
	for _, element in ipairs(root:GetChildren()) do
		if element:IsA("GuiObject") then
			element.Visible = visible[element.Name] == true
		end
	end
	fillSamples(root)
	if options.prepare then
		options.prepare(root, phase, Vector2.new(width / scale, height / scale))
	end
	if canary then
		-- Put the second element exactly on the first: this must be reported.
		local a, b = root[canary[1]], root[canary[2]]
		a.Visible, b.Visible = true, true
		b.AnchorPoint, b.Position = a.AnchorPoint, a.Position
	end
	root.Parent = holder
	task.wait() -- let the layout engine size AutomaticSize frames
	task.wait()
	local rects = {}
	for _, element in ipairs(root:GetChildren()) do
		if element:IsA("GuiObject") and element.Visible then
			table.insert(rects, rectOf(element, holder.AbsolutePosition))
		end
	end
	root:Destroy()
	return LayoutMath.problems(rects, width, height, options.allowed)
end

-- options:
--   root      the HUD's root Frame (with a UIScale child)
--   phases    { [phase] = { element names visible in that phase } }
--   always    element names visible in every phase (optional)
--   sizes     window sizes { { w, h }, ... } (default DEFAULT_SIZES)
--   steps     UI scale steps the player can pick (default { 1 })
--   minSize   { w, h } logical size the layout needs (LayoutMath.uiScale; optional)
--   allowed   overlaps allowed on purpose, "A|B" or "A|*" (modals, floating menus)
--   canary    { a, b }: two always-present element names; b is moved onto a
--   prepare   function(root, phase, logicalSize) to fill worst-case content (optional)
-- Returns a one-line "LAYOUT OK ..." or "LAYOUT FAILED ..." with one line per problem.
function LayoutCheck.run(options)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LayoutCheck"
	gui.IgnoreGuiInset = true
	gui.Archivable = false
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(10000, 0) -- measured, never seen
	holder.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	-- A HUD that doesn't ignore the top bar inset has that much less height.
	local inset = if options.root:FindFirstAncestorOfClass("ScreenGui").IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y

	local ok, result = pcall(function()
		if options.canary then
			local firstPhase = next(options.phases)
			local caught = measure(options, holder, 1280, 720 - inset, 1, firstPhase, options.canary)
			if #caught == 0 then
				return "LAYOUT CHECK BROKEN: a deliberate overlap was not found"
			end
		end
		local all, cases = {}, 0
		for _, size in ipairs(options.sizes or LayoutCheck.DEFAULT_SIZES) do
			for _, step in ipairs(options.steps or { 1 }) do
				for phase in pairs(options.phases) do
					cases += 1
					for _, problem in ipairs(measure(options, holder, size[1], size[2] - inset, step, phase)) do
						table.insert(all, string.format("%dx%d @%d%% %s: %s", size[1], size[2], math.floor(step * 100 + 0.5), phase, problem))
					end
				end
			end
		end
		if #all == 0 then
			return string.format("LAYOUT OK (%d cases%s)", cases, if options.canary then ", canary caught" else "")
		end
		return string.format("LAYOUT FAILED (%d problems in %d cases)\n%s", #all, cases, table.concat(all, "\n"))
	end)
	gui:Destroy()
	if not ok then
		error(result, 0)
	end
	return result
end

return LayoutCheck
