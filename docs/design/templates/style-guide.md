# Style guide

> Copy to `docs/design/STYLE_GUIDE.md`. Short and specific: a page an agent reads before it picks a
> colour, a shape or a font. The skills defer to this file when it exists. The values themselves
> live in `GameConfig` (`World.Palette` for the world, `Ui` for the interface); this page says what
> they are *for*, so a later change keeps the intent. Everything here is a decision the creator can
> reopen, not a rule an agent must obey blindly: an agent may diverge and says why in the feature spec.

## Mood and references
Three words for how the game should feel, and up to three reference games or images with what is
taken from each (and what is not).

## Shape language
What shapes the world is made from (chunky and rounded, sharp and angular, organic), and the
proportions that make assets look like they belong together (thick or thin, tall or squat).

## World palette (`GameConfig.World.Palette`)
| Role | Used for | Why this colour |
|---|---|---|
| Ground | What the player walks on | |
| Wall | Boundaries and large surfaces | |
| Prop | Scenery that does nothing | |
| Accent | The game's signature colour | |
| Interactable | Anything the player can use | |
| Hazard | Anything that hurts | |
| Goal | Where the player is going | |

The three gameplay roles (Interactable, Hazard, Goal) stay distinct from the ground and from each
other. Say here how each is also shown by something other than colour (a shape, an icon, a motion).

## Areas
For each area or biome: its signature (colour, material, shape language, light) so a player knows
where they are from a single screenshot.

## Readability
The distance and angle the player usually sees things from, and the one thing that must read
there in each situation (the next objective, the threat, the reward).

## Interface (`GameConfig.Ui`)
- **Look:** the feeling of buttons and panels (soft, metallic, flat) and the one detail that makes
  them this game's.
- **Colour roles:** which colour is the main action, which is danger, which is good news.
- **Type:** the display font and the body font, and why.
- **Always visible / contextual / hidden:** the HUD elements in each tier. Survival or progress
  information stays visible; anything needed only in some situations appears when it matters.
- **Never colour alone:** how each state (selected, disabled, low health) is also shown by a
  shape, an icon or text.
- **Touch and small screens:** what the smallest supported window drops or moves.

## Assets
Anything the generators need that isn't obvious from the palette: material choices (smooth,
metal, wood), whether parts are smooth-shaded or faceted, and the level of detail the player's
space gets compared with the background.
