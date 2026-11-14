# Framework TODO

Deferred work, newest first. Each item links to the design that describes it.

## Recorded play sessions for tuning: what is built, what is left

Status: partly built (2026-11-14). **Built:** `SessionRecorder` tags every session with
`schema`, `source` (agent, studio, live) and `configStamp` (`shared/ConfigStamp`, same stamp in
Lune and in the engine, checked in `FrameworkSmokeTest`); `tests/lib/balance/Sessions` loads and
validates exports, splits current from stale by stamp, filters by source, reads one session
(`firstTime`, `count`, `summary`, `events`), and compares each metric's median with the model's
value (`compare`); **digests** (`Sessions.digest`, `loadDigests`, `metric`, `diffDigests`): the
game's own metrics computed inside Studio, a few hundred bytes per session, saved under
`playtests/digests/` and compared across retunes (`Sessions` lives in `src/framework/`, so the
engine can run it; checked in `FrameworkSmokeTest` and in Lune); the playtest skill documents the
workflow and G15 rung 4 uses it. No game uses any of it yet.
**Decision (2026-11-14, maintainer): no stored raw play runs.** Raw sessions stay in Studio's
memory and are never saved wholesale: an agent saves the small digest instead, and exports raw
JSON over MCP only for a short session (it passes through the agent's context, twice when written
to a file). Not pursued, with the reasons, in case it is reopened: automatic export to a file (a
Studio `HttpService` POST to a local Lune collector, which keeps the data out of any model's
context but needs "Allow HTTP Requests" in the place and a running collector); reading the Output
log from a subagent (works without setup, but the data passes through a model twice and copying
needs a checksum check; Studio's log files on disk only appear after Studio restarts); live
sessions from published servers (needs durable storage and a check of Roblox's data rules).
**Left, if it is ever needed:**
1. **A game adopts it.** Call `setConfig`, record the decisions its model also makes, write a
   metrics map for `Sessions.compare`. The first game to do this decides what is missing. Read
   Clockwork Keep's `tests/sim/` adapter first for what already exists.
2. **Replay as a persona.** `Sessions.events(session, kind)` gives the decisions in order; a
   game's adapter can feed them to its simulation to check that the model reproduces the run.
   Build the shared helper when a second game needs it.

## Cross-server session lock: wrap ProfileStore or build our own (L-030)

Status: evaluated 2026-11-14, not decided. `MockDataStore` and `StoreContract` exist
(`docs/decisions/0001-publish-late.md`); the session lock is the remaining half of L-030.
ProfileStore (Apache-2.0, one ModuleScript) has cross-server session locking over
MessagingService and a `.Mock` store, but it calls `DataStoreService` directly (no injection, so
no Lune tests), has no schema `Version`, and the docs don't say what a failed load does to a
real save. Options: (a) wrap it behind our own store interface and keep our ProfileStore's
Version/read-only rules on top; (b) build a small lock in `UpdateAsync` (owner id and expiry in
the profile), tested with `MockDataStore:interleave()`. Decide in Driftbloom M2 (G2), then
fold the result into a shared `Profiles` module.

## Review the milestone, milestone-plan and milestone-catalog templates after Driftbloom M2

Status: scheduled (2026-11-14). `docs/design/templates/milestone.md`, `milestone-plan.md` and
`milestone-catalog.md` (new) were drafted from Clockwork Keep's plans and Driftbloom M1, before any game used them.
Driftbloom M2 is the first milestone planned from them. When M2 closes, compare the plan as
written with what happened: unused sections, missing ones, whether the checkpoints and the
rules block helped, whether `Check-ins` in the GDD template was used, which catalog entries the Lead kept,
merged or skipped (and whether any verdict was missing), and whether the tuning ladder (G15, the
plan's *Tuning task*, the milestone's *Targets*) was used or ignored. Fix the templates and the
`roblox-game-design` skill's stage 2 and 4 text, in one `framework:` commit.

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
