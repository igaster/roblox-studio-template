# Game Design Docs

This directory holds the game's own design documentation — separate from the
engineering conventions in `CLAUDE.md` and the testing checklist in
`docs/TESTING.md`. Nothing here affects how Claude edits code; it's a place to
record what the game *is*, not how it's built.

Suggested contents as the project grows:

- `GDD.md`: the game design document. Start from `templates/GDD.md`.
- `milestones/M<N>-<name>.md`: one file per milestone: its goal, the feature specs it
  includes, and when it's done. Start from `templates/milestone.md`. Development is
  organized around milestones: a new game or a large feature is planned as a sequence
  of milestones, each with its own specs. A milestone's implementation plan lives
  next to it as `M<N>-<name>-plan.md`.
- `features/<Name>.md`: one spec per feature. Start from `templates/feature-spec.md`.
- `references/<Game>.md`: teardowns of existing games used as inspiration. Start from
  `templates/reference-teardown.md`; written by the `roblox-game-teardown` skill.
- `STYLE_GUIDE.md`: colors and materials, read by `roblox-asset-generators`.
- `balance-model.md`: only if the game keeps a balance model (`roblox-game-modeling`). Start
  from `templates/balance-model.md`.
- Lore, art direction, or other reference material.

Outside this folder: settled decisions in `../decisions/` (one file each), and the handoff
page `../STATUS.md` (from `templates/status.md`).

`templates/` is part of the framework; everything else here belongs to the game.
The `roblox-game-design` skill guides the design process and fills in these templates.

World building note: a new place from Studio's Baseplate template has a Baseplate whose top
is at Y = 0. Generated floors at Y = 0 z-fight with it (flickering), so place generated floors
slightly above it or remove the Baseplate.
