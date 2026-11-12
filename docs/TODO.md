# Framework TODO

Deferred work, newest first. Each item links to the design that describes it.

## Multiplayer test bot

Status: idea (run 001, Tiptoe Bandits M4, 2026-11-07). MCP drives one client, so two-player
rules are tested only as pure `*Rules` modules plus a human checklist (`roblox-test`, Tier 3).
Candidate: a Studio-only "bot player" (an NPC rig that services treat as a player, driven
through `TestHooks` commands) for scripted two-player playtests. Build when a second game
needs it.

## Training across multiple games (multi-game mode)

Status: designed, not built. Owner decision 2026-11-07: build later, once single-game
(in-place) training has produced enough data to compare runs across games.

- One training session builds several games in sequence, never in parallel.
- Each game is a full local `git clone` of the framework in a numbered folder under a
  training root inside the repo, gitignored (`.training/archive/NNN-<name>/`), pinned to its commit,
  with its own place file saved by the human; `TRAINING_STATE.json` at the training root.
- Human step at the start of each game (new Baseplate place, save into the folder, Rojo
  Connect); the trainer switches `rojo serve` between game folders.
- Aggregate findings across runs (`.ledger/runs/`) to spot recurring
  framework problems.
- Design: `docs/superpowers/specs/2026-11-07-lead-and-trainer-design.md`, section
  *Multi-game mode*.

## Later options mentioned in the design

- Upgrade a game in progress to a newer framework commit (framework-file manifest + merge).
- `game/` folder split, making games portable across framework versions.
- Delegate build tasks to sub-agents (Option B). Skipped 2026-11-12, and the unused
  `game-developer` agent removed: revisit only if a fresh Lead per milestone or checkpoint
  still grows too large. A new builder agent needs: "don't design or change scope; report
  deviations and why", the skills to load for its task, and what to do when it can't ask
  the owner.
- A dedicated `critic` agent for training reviews.

## Lint, format and type tooling

Status: idea (fresh-agent interview, 2026-11-07). CLAUDE.md asks for "consistent formatting"
but nothing enforces it. Candidates: StyLua (format), selene (lint), luau-lsp with a Rojo
sourcemap (types), pinned in `rokit.toml`, run by `make check` and CI. Add when a game shows
real formatting or type bugs, not before.

## Auto-load the trainer plugin (revisit after Tiptoe Bandits)

Status: deferred (2026-11-07). Re-evaluate when the current game is done and the
`roblox-trainer` plugin has stopped changing. Then install it at local scope so sessions find
it without `--plugin-dir`:
`claude plugin marketplace add . --scope local` and
`claude plugin install roblox-trainer@roblox-framework --scope local`
(after later plugin edits: `claude plugin update roblox-trainer@roblox-framework`).
Until then, start sessions with `claude --plugin-dir plugins/roblox-trainer`, which reads the
folder directly.
