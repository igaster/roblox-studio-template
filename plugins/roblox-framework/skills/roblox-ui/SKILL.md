---
name: roblox-ui
description: Use when adding, changing or checking any Roblox UI — a HUD, menu, shop, panel, button, ScreenGui, a UI theme or style, text size or colours — e.g. "add a HUD", "build the shop screen", "restyle the buttons", "does the HUD overlap on phones" — or when creating or editing any file under AssetGenerators/GUI/ or a Controller that binds to a GUI.
---

# Roblox UI

## Overview

UI is built by **GUI generators** from the framework's **UI kit** (`ReplicatedStorage.Shared.UI`),
with the game's look taken from tokens in `GameConfig.Ui`. A client controller binds to the
finished UI by name; it never builds it. Three pieces:

- **The kit** (`Shared.UI.Kit`): `screen`, `applyScale`, `panel`, `label`, `button`, `bar`, `chip`.
  It builds the conventions in, so they don't have to be remembered.
- **The tokens** (`GameConfig.Ui`, checked by `Shared.UI.ThemeSchema`): colour *roles*, fonts, text
  sizes, radius, padding, a touch-target floor. The game picks the values; the kit picks the roles.
- **The check** (`Shared.LayoutCheck`): measures a HUD at several window sizes, UI scales and game
  phases.

**Firm rules and suggestions.** The *firm* items below guard silent bugs or break the layout check.
Everything else is a suggestion: diverge when the game needs it and note why in the feature spec.
A component the kit lacks goes in the game's own `GUI/` folder, built from the same `Theme`.

**State of the kit.** It is extracted from two games' UI helpers and its headless parts (the token
schema, contrast and button-state rules) are tested under Lune. The engine side (`Kit`, `Theme`,
`ButtonStates`) is compile-checked only until a game has used it in Studio. If something misbehaves
in Play, log it in `FRAMEWORK_FEEDBACK.md`.

## The flow (firm)

`ServerStorage` (where generators live) is invisible to clients, so:

1. A server service builds the UI from `GUI/<Name>Generator.lua` and parents a copy into each
   player's `PlayerGui` on join (and on respawn if `ResetOnSpawn` is true; `Kit.screen` turns it off).
2. The client controller (`Controllers/<Name>Controller.lua`) does
   `player:WaitForChild("PlayerGui"):WaitForChild("<Name>")` and binds to attributes and remotes. It
   never builds the UI itself.

The rules for any generator still apply (`roblox-asset-generators`): the generator returns the
instance and does not parent it, tunables come from `GameConfig`, the instance carries no gameplay
state (state is an attribute set by the owning class), and nothing is "created if missing".

## Building with the kit

```lua
local Kit = require(ReplicatedStorage.Shared.UI.Kit)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local theme = Theme.new(GameConfig.Ui) -- errors, listing every problem, if the tokens are invalid

local gui = Kit.screen("Hud")
local root = gui.Root
local status = Kit.panel(theme, "StatusBar", { size = UDim2.fromOffset(320, 64), parent = root })
Kit.label(theme, "Coins", "$0", "Body", { parent = status, sample = "$99,999" })
Kit.button(theme, "Shop", "Shop", { parent = root, variant = "primary" })
Kit.bar(theme, "Health", UDim2.fromOffset(240, 18), { parent = root, fill = "Good", ghost = true })
```

- **Roles, not colours.** Ask for `Primary`, `Danger`, `Good`; never a raw `Color3`. A theme change
  then restyles every element. The default theme is neutral and valid, and `ThemeSchema.isDefault`
  lets a test fail a game that ships it untouched (every game should choose its own look).
- **Variants.** Buttons take a `variant` (`primary`, `danger`, `ghost`); a game adds or replaces
  variants in `Ui.ButtonVariants`. A game-specific shape (a hexagonal button, a parchment panel)
  belongs in the game's own generator.
- **State is an attribute.** `Disabled` and `Selected` on a button; the client calls
  `ButtonStates.bind(theme, playerGui)` once and every kit button gets hover, pressed and disabled
  colours.

## What the kit builds in

Each of these used to be a rule to remember; they are now behaviour:

- One screen root: `ScreenGui > Root (Frame) > everything`, plus a `UIScale`. `Kit.applyScale`
  sets the scale and resizes `Root` by the inverse so it still fills the window.
- One `UICorner` per object (a second call edits the existing one).
- Buttons never shorter than `Ui.MinTouchSize`.
- `ScreenInsets = CoreUISafeInsets` (the default): content stays below Roblox's top bar and clear of
  device notches. This is the same as the older `IgnoreGuiInset = false`.
- Labels take a `sample` (worst-case text) so `LayoutCheck` measures them at their longest.
- Text drawn over the 3D world takes `outline = true`.

## Tokens and contrast

`ThemeSchema.validate(GameConfig.Ui)` checks the tokens (a game's own spec should call it) and
reports contrast problems in plain text: normal text 4.5:1 and non-text UI (bars, buttons) 3:1, from
WCAG and the Game Accessibility Guidelines. Button text is checked in every state the button shows.
When it fails, change the colour (bright fills with dark text is the usual fix); don't weaken the
threshold unless the game has a reason.

- **Don't carry meaning by colour alone.** Pair a state (low health, selected, disabled) with a shape,
  an icon or text ([IGDA top ten](https://igda-gasig.org/how/game-accessibility-top-ten-se/)).
- **Let players scale text.** A UI-size setting and a text-size floor (`Ui.MinTextSize`) are worth
  having; Xbox's guidance scales icons with text up to 200% ([Xbox XAG 101](https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/101)).
- **Touch targets.** 44 px is the common mobile minimum (general mobile guidance, not a Roblox
  number); `Ui.MinTouchSize` sets the game's.

## HUD layout (firm for the layout check; the rest are suggestions)

Overlaps and off-screen elements show up at window sizes and UI scales nobody tried, so don't check
a HUD by eye at one size. Build it like this and `Shared.LayoutCheck` measures it:

- **One root** (firm). `Kit.screen` makes it: Root's direct children are the layout elements (status
  bar, hotbar, side panels, modals); everything else nests inside one of them.
- **Scale with a minimum logical size.** Design for a minimum (e.g. 960×540). The HUD controller
  sets `Kit.applyScale(gui, LayoutMath.uiScale(step, w, h, minW, minH))`, so the player's UI-scale
  step applies on large windows and small windows shrink the HUD instead of overlapping it. Compute
  it from the `ScreenGui`'s `AbsoluteSize` (the usable area), not the camera's `ViewportSize`.
- **Keep important readouts out of the top-right** while Roblox's player list is on.
- **Modals switch world prompts off.** While a modal is open set
  `ProximityPromptService.Enabled = false` (and back on when the last modal closes): prompts draw
  through a translucent panel and can be triggered from behind it.
- **Anchors.** A floating menu that follows something in the world can be a zero-size anchor frame;
  the check measures the union of its visible children.

Register the check as a Studio-only dev command in the HUD controller's `init()`, with the game's
phases:

```lua
TestHooks.registerCommand("LayoutCheck", function()
	return LayoutCheck.run({
		root = hud.Root,
		always = { "StatusBar", "Hotbar" },
		phases = { Lobby = { "LobbyPanel" }, Playing = { "Minimap" }, Paused = { "PauseMenu" } },
		sizes = { { 665, 520 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } },
		steps = { 0.9, 1, 1.15 }, -- UI scale choices offered to the player
		minSize = { 960, 540 },
		allowed = { ["PauseMenu|*"] = true }, -- modals may cover the HUD
		canary = { "Hotbar", "StatusBar" }, -- a deliberate overlap that must be caught first
		prepare = function(root, phase, size) end, -- show every list row, long texts
	})
end)
```

Run it in a Play session on the **Client** datamodel through the LocalPlayer's attributes
(`Dev_LayoutCheck`, see `roblox-playtest`) after GUI changes. The result starts with `LAYOUT OK`,
`LAYOUT FAILED` (one line per problem) or `LAYOUT CHECK BROKEN` (the canary overlap wasn't found, so
the check measured nothing). The rules (`Shared.LayoutMath`) are pure and covered by the Lune tests.

## Layering

**Screen UI always draws over in-world UI.** Every `ScreenGui` draws over every `BillboardGui`
(health bars, prompts, labels), whatever `ZIndex` or `DisplayOrder` say. So:

- keep screen plates small and near the edges; a wide bar at the top hides whatever is behind it in
  the world;
- make large plates semi-transparent (a `CanvasGroup` panel, `className = "CanvasGroup"`, with
  `GroupTransparency`), and fade them while world UI projects behind them (`Camera:WorldToViewportPoint`
  on the billboards' adornees, a few times a second);
- a layout check of screen rects can't see this; check it in Play with world UI behind the plate.

## What belongs on the HUD (suggestions)

- **Rank by urgency.** Survival and progress information stays visible; situational information
  appears when it applies and disappears after ([bugnet](https://bugnet.io/blog/how-to-design-a-readable-hud)).
  The layout check's phases already express "contextual".
- **Visual weight shows importance.** A HUD where everything is equally loud is hard to read.
- **Choose where information lives.** Diegetic or spatial UI (in the world) can beat a HUD for ammo
  or navigation; a plain HUD tends to win for health ([Peacocke et al. 2018](https://www.yorku.ca/mack/ec2018.html)).
  Immersion and clarity trade off; decide per piece of information.
- **Feedback.** Echo the core loop and design visual, audio and any haptic feedback together; more
  is not better ([summary](https://gamedeveloper.com/design/squeezing-more-juice-out-of-your-game-design-)).

## Style guide

`docs/design/STYLE_GUIDE.md` (template: `../../docs/design/templates/style-guide.md`) says what the
tokens are *for* (the mood, which colour is the main action, which elements are always visible). Read
it before choosing token values; the values themselves live in `GameConfig.Ui`, which stays plain
Lua (no `Color3` or `Font`; the kit converts).

## Common mistakes

- **Two `UICorner`s on one object.** Only one applies and the shape silently stays wrong. Use
  `Kit.corner`, which edits the existing one.
- **A controller building UI.** The client can't require a generator (`ServerStorage`), and building
  in a controller splits the look across two places. Build in the generator, bind in the controller.
- **A raw colour or size in a generator.** It escapes the theme; use a role or a token.
- **Checking a HUD at one window size.** Run `LayoutCheck`; phones and small windows are where it breaks.
- **Meaning by colour alone.** Add a shape, icon or text.
- **A wide screen plate at the top.** It hides the world behind it; keep plates small or fade them.
