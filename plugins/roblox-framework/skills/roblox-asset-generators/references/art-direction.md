# Art direction for generated assets: suggestions

Read when the look of an asset, prop or area matters. **All of this is suggestion, not rule.** It
is the common ground across game-art writing, mostly studio and tool blogs, so treat any specific
number as a starting point. A game with a deliberate style (busy, realistic, hand-drawn) may do the
opposite; note why in `docs/design/STYLE_GUIDE.md` or the feature spec.

## Read it at the distance the player sees it

- **Silhouette first.** Every significant object (a pickup, an enemy, something to interact with)
  should read as a solid shape at gameplay camera distance. The usual reading order is shape, then
  palette, then detail ([style-guide overview](https://rocketbrush.com/blog/the-ultimate-character-art-style-guide-for-artists-and-developers)).
- **Check it, don't assume.** Capture the asset small and from the usual camera angle
  (`roblox-capture`), not only up close; a common mistake is judging silhouette from a close-up.
- **Detail the player's space.** Spend detail where the player looks and moves; keep the background
  simple. Tiny accessories that vanish at gameplay distance are wasted effort.

## Palette

- **Use roles, not colours.** `GameConfig.World.Palette` gives Ground, Wall, Prop, Accent,
  Interactable, Hazard and Goal; a generator picks a role. One change then restyles everything.
- **Keep the gameplay roles distinct.** Interactable, Hazard and Goal should differ clearly from
  the ground and each other. `Shared.WorldPalette.validate` checks this; its thresholds are this
  framework's heuristic, not a standard, and a game can pass its own limits.
- **Don't carry meaning by colour alone.** Players with colour-vision differences may read two
  colours as one when they match in brightness ([IGDA top ten](https://igda-gasig.org/how/game-accessibility-top-ten-se/)).
  `WorldPalette.advisories` flags this; a shape, icon or motion alongside the colour solves it.
- **Test on the target display.** A palette that works on a monitor can wash out on a phone.

## Style

- **Commit to one.** Low-poly and stylized art fail when hedged: smooth shading mixed with faceted,
  uneven detail density, textures that don't match the shapes ([low-poly style guide](https://bugnet.io/blog/low-poly-3d-a-style-guide-for-small-teams)).
  Decide the shape language (chunky, angular, organic) and the proportions once in `STYLE_GUIDE.md`.
- **Give each area a signature.** A distinct mix of colour, material, shape language, light and
  atmosphere lets a player tell where they are from a single screenshot.
- **A small material set** (a few Roblox materials used consistently) usually looks more
  intentional than many, and keeps assets looking like one family.

## Using this with generators

- Pick colours from `World.Palette` roles and materials from the style guide; keep both in
  `GameConfig`, never hardcoded in the generator.
- When two assets disagree, the style guide wins; when there is no style guide, match what is
  already in the game.
- When you change a role's colour, look at the captures again: roles are tuned together.
