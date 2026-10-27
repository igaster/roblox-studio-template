# Game Design Docs

This directory holds the game's own design documentation — separate from the
engineering conventions in `CLAUDE.md` and the testing checklist in
`docs/TESTING.md`. Nothing here affects how Claude edits code; it's a place to
record what the game *is*, not how it's built.

Contents:

- `GDD.md`: the game design document (created by `/kickoff` from `templates/gdd.md`).
- `milestones/M<n>-<slug>.md`: one spec per milestone (created by `/milestone` from
  `templates/milestone.md`), with acceptance criteria, plan, tasks, results, and retro.
- `templates/`: framework-owned templates. Improve them via `framework:` commits.
- Anything else the game needs: feature specs, lore, art direction.

Settled decisions go in `../decisions/`, not here.
