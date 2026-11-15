--!strict
-- Client-side: gives every Kit button (attribute KitButton) its hover, pressed and disabled
-- colours, from the button's variant in the theme. Call `ButtonStates.bind(theme, playerGui)`
-- once from a controller; it also styles buttons added later (a list row, a reopened panel).
-- Synced to ReplicatedStorage.Shared.UI.ButtonStates.
--
-- State attributes (set by the controller that owns the button):
--   Disabled = true   disabled colours, regardless of hover
--   Selected = true   shown as pressed (a toggled tab, a chosen option)

local Theme = require(script.Parent.Theme)
local ThemeSchema = require(script.Parent.ThemeSchema)

local ButtonStates = {}

local function style(theme: Theme.Theme, button: Instance)
	if not (button:IsA("TextButton") and button:GetAttribute("KitButton")) then
		return
	end
	if button:GetAttribute("KitButtonBound") then
		return
	end
	button:SetAttribute("KitButtonBound", true)
	local variant = theme.variants[button:GetAttribute("ButtonVariant") or "primary"]
	local hovered, pressed = false, false
	local function paint()
		local fill, text = ThemeSchema.buttonRoles(variant, {
			disabled = button:GetAttribute("Disabled") == true,
			selected = button:GetAttribute("Selected") == true,
			pressed = pressed,
			hovered = hovered,
		})
		button.BackgroundColor3 = theme:color(fill)
		button.TextColor3 = theme:color(text)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		paint()
	end)
	button.MouseLeave:Connect(function()
		hovered, pressed = false, false
		paint()
	end)
	button.MouseButton1Down:Connect(function()
		pressed = true
		paint()
	end)
	button.MouseButton1Up:Connect(function()
		pressed = false
		paint()
	end)
	button:GetAttributeChangedSignal("Disabled"):Connect(paint)
	button:GetAttributeChangedSignal("Selected"):Connect(paint)
	paint()
end

function ButtonStates.bind(theme: Theme.Theme, container: Instance)
	for _, d in ipairs(container:GetDescendants()) do
		style(theme, d)
	end
	container.DescendantAdded:Connect(function(d)
		style(theme, d)
	end)
end

return ButtonStates
