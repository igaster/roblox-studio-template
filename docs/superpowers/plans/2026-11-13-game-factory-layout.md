# Game Factory Layout Implementation Plan

> **For agentic workers:** steps use checkbox (`- [ ]`) syntax for tracking. Work on branch
> `restructure/game-factory`. Commits are local, by explicit path, never pushed unless the
> maintainer asks.

**Goal:** One framework, many self-contained games. Each game lives in `games/<name>/` as its
own git repo, can be switched to, moved to another machine or shared with a collaborator,
and never writes into framework files. The framework keeps learning from every game: from
trainer-driven runs, and also from sessions where a human developer drives the game.

**Non-goals (now):** running games in parallel; a hosted service; changing how the Lead
designs or builds games.

**Status:** draft for the maintainer (2026-11-13). Rollback point taken (see *Rollback*).

## Why

Today the game is built in the framework's own tree. Its files are "everything outside the
framework path list" (`commit-framework.sh --list`), computed from git by `game.py`. That
leaks both ways:
- starter files (`GameConfig.lua`, `SmokeTest.lua`, `ExampleMath*`) are template files the game
  edits or deletes in place, so framework commits need `--starters` and hunk staging;
- `docs/decisions/`, `docs/design/`, `docs/superpowers/` mix framework and game files;
- switching games means moving files in and out of `.training/archive/` (`game.py park/load`);
- a game can't be cloned elsewhere or shared, because it has no repo of its own.

## Target layout

"Factory" below means **this repo's root**, not a new folder. `$FACTORY` is the path from a
game back to it (`../..`).

```
<repo root>/                    this repo: framework only, everything tracked is framework
  CLAUDE.md                     framework conventions (imported by each game's CLAUDE.md)
  plugins/roblox-framework/     skills, agents, commands, hooks (moved from .claude/)
  plugins/roblox-trainer/       unchanged role; adapted to games/
  src/shared/                   framework Luau modules (unchanged path)
  src/framework/                FrameworkSmokeTest.lua (moved from src/game/ServerScriptService)
  tests/                        harness.lua, framework.lua, run.lua, lib/ (framework only)
  docs/design/templates/        doc templates, read in place, never copied-then-edited
  docs/superpowers/ docs/TODO.md  framework plans and backlog
  template/                     starter game; only ever copied by `new-game`
  scripts/                      verify.sh, new-game.sh, framework.mk
  .ledger/                      shared learnings (local, gitignored as today)
  .training/                    trainer only (gitignored; the Lead is denied reading it)
    games/<name>/               scenario.md, state.json (was TRAINING_STATE.json), messages/,
                                messages-out/, live.jsonl
    snapshots/                  rollback snapshots
  games/                        gitignored by the factory; each child is its own git repo
    <name>/
      game.json                 title, placeId, universeId, frameworkCommit last built on
      CLAUDE.md                 `@../../CLAUDE.md` + game-specific notes
      .claude/settings.json     permissions: write only inside this folder
      Makefile                  `FACTORY ?= ../..` + `include $(FACTORY)/scripts/framework.mk`
      default.project.json      its src/ + ../../src/shared + ../../src/framework
      src/game/...              same internal layout as today
      tests/specs/ tests/sim/   the game's tests and simulations
      docs/STATUS.md TESTING.md design/ decisions/ captures/
      FRAMEWORK_FEEDBACK.md     friction + corrections for the framework (see Q3)
      .local/                   gitignored: place file, sourcemap, logs, sessions.jsonl
```

**Key choice: a game keeps today's internal layout.** A session's working directory is the
game root, so `src/game/...`, `docs/STATUS.md`, `tests/specs/` in skills and in the Lead's own
docs stay correct. Only references to *framework* files change (they're at `$FACTORY`).

### What goes where

**`docs/` splits.** Game docs move into each game's `docs/`. The root `docs/` keeps only
framework docs: `docs/design/templates/`, `docs/design/README.md`, `docs/superpowers/` (framework
plans and specs), `docs/TODO.md`. `docs/decisions/README.md` and the empty `design/` folders
become part of `template/`.

| Output | Where | Why |
|---|---|---|
| GDD, feature specs, milestone plans, decisions, STATUS, TESTING | game repo `docs/` | describes this game |
| Captures, balance model, sim baselines | game repo | evidence for this game's checks |
| Playtest session recordings, debug logs, place file, sourcemap | game `.local/` | machine-local, large or regenerated |
| `FRAMEWORK_FEEDBACK.md` | game root (Q3) | raw friction, harvested by the trainer |
| Scenario, owner policy, trainer messages, live logs | `.training/games/<name>/` | the Lead must not read them |
| Ledger cards, harvests, pending decisions, scorecard, run records, coverage | `.ledger/` | across games |
| Framework plans, decisions about the framework | factory `docs/superpowers/`, `docs/TODO.md` | framework |
| Genre teardowns written game-agnostic | factory `docs/design/references/` (Q4) | reusable |
| Code that proves general (used by 2 games) | promoted into `src/shared/` or `template/` | framework library |

## Where to start a session

| Who | Working directory | Command |
|---|---|---|
| Trainer (autonomous runs) | factory root | `claude --plugin-dir plugins/roblox-trainer` |
| Lead started by the trainer | `games/<name>` | `lead.py` sets `cwd` and passes `--plugin-dir` |
| Developer driving one game | `games/<name>` | `make claude` (= `claude --plugin-dir ../../plugins/roblox-framework`) |
| Framework maintenance | factory root | `claude` |

## Spike results (2026-11-13, probes in the scratchpad, Haiku)

A child git repo under a parent folder, session started in the child:
- parent `CLAUDE.md`: **loaded**;
- parent `.claude/skills`, `.claude/agents`, `.claude/settings.json` hooks: **not loaded**
  (control run in the parent loads all three);
- framework as a plugin via `--plugin-dir ../../fw`: skill, agent and SessionStart hook
  **loaded**;
- plugin enabled through the child's `.claude/settings.json` (`extraKnownMarketplaces` with a
  `directory` source + `enabledPlugins`): **not loaded** headless (likely needs an install or a
  trust prompt). Hence the `make claude` launcher with `--plugin-dir`.

## Phases

### Phase 0: Remaining spikes (throwaway, scratchpad) — DONE 2026-11-13
Testbed: a scratch copy of the repo in the new layout (`games/ck` = Clockwork Keep's 254 files
from the snapshot manifest + the template starters; framework skills/agents/commands/hooks
packaged as `plugins/roblox-framework`).
- [x] **Real skills from a plugin trigger.** "Add a sword tool…" (plan mode): old layout loads
      `roblox-asset-generators`; game folder + `--plugin-dir` loads
      `roblox-framework:roblox-asset-generators`. One sample each; the namespaced name is the
      only difference. Skill references in `CLAUDE.md` should name skills without relying on
      the prefix.
- [x] **`${CLAUDE_PLUGIN_ROOT}` is substituted in skill text** (absolute plugin path). Skills
      name framework files as `${CLAUDE_PLUGIN_ROOT}/../../<path>`.
- [x] **Rojo `$path` outside the project folder works**, and **sourcemap parity holds**: today's
      project vs `games/ck/default.project.json` (`../../src/shared`,
      `../../src/framework/FrameworkSmokeTest.lua`): 127 instances each, identical names and
      classes. Connecting Studio after the move deletes or recreates nothing.
- [x] **Lune from a game folder: 1,590/0** (same as the old layout) and **balance check OK**
      (0 of 2,540 baseline values changed), after three changes:
      - framework runner becomes a module (`tests/runner.lua`); the game has a 6-line shim
        `tests/run.lua` passing `requireSpec` and `requireGameConfig`; `tests/framework.lua`
        becomes `function(requireGameConfig)`;
      - the game's `.luaurc` aliases `framework` → `../..`; game code that used framework
        libraries by relative path (`require("../lib/balance/…")`, 4 files in Clockwork Keep)
        uses `@framework/tests/lib/…` (migration rewrites them; the modeling skill says so);
      - framework code that names framework files relative to the working directory
        (`Parallel.lune("tests/lib/balance/testdata/double.lua")`) prefixes `FRAMEWORK_ROOT`
        (set by `framework.mk`). Game worker paths (`tests/sim/worker.lua`) stay game-relative.
      - Also: the "every src/ file compiles" check must walk the game's `src/` and
        `$FRAMEWORK_ROOT/src/`.
- [x] **Collaborator install route:** an installed plugin is a cached copy that needs
      `claude plugin update` after framework edits (README, L-083). Acceptable for
      collaborators; `make claude` (`--plugin-dir`) stays the default.
- [x] Parent-folder probe (earlier): parent `CLAUDE.md` loads; parent `.claude/{skills,agents}`
      and settings hooks don't; `enabledPlugins` via a directory marketplace in the child's
      settings didn't load headless.
- [ ] Interactive only: a SessionStart hook's `systemMessage` shows on the start screen (Phase 4b).

### Phases 1–3: DONE 2026-11-13 (92b6874, 29b40e0, b8c32ab)
Checked: a game made by `new-game` passes Tier 1 (50/0), builds with Rojo, `make verify` names
it; a game session reads framework files, is denied `.training/`, and loads
`roblox-framework:*` skills; trainer tests 24/24. Changes against the steps below:
- **No `@import` in the game's `CLAUDE.md`:** the framework's `CLAUDE.md` already loads from the
  parent folder (Phase 0), so the template's `CLAUDE.md` holds only game notes.
- **Framework root access:** `game-local.sh` writes `settings.local.json` with the framework
  root in `permissions.additionalDirectories` (without it every framework read asked first)
  plus the `.training/` and other-games denies. `.ledger/` is not denied (Q2: framework edits
  allowed); revisit if a game session starts writing cards.
- **superpowers** is no longer enabled in project settings: it was installed for the root's
  project only, so a game folder warned. The framework treats it as optional;
  `roblox-initialize` now says to install it at user scope. Phase 5: does the Lead need it?
- `docs/design/README.md` moved into `template/` (it describes a game's design folder).
- `tests/framework.lua` checks stay at the function's top level (not re-indented).
- CI checks a game made fresh from `template/` (new-game, then test and Rojo build).
- `bootstrap` checks `lune --version` (the root has no game to test).
- Not done yet: the root's `make` forwards to `.local/active-game`, which nothing writes until
  `/start` (Phase 4b).

### Phase 5: DONE 2026-11-13 (fe9af48)
Kept `TRAINING_STATE.json` at the root (the trainer's one state file) with a new `gameDir`,
rather than moving state to `.training/games/<name>/`: same effect, far less churn. Deferred.
`lead.py` runs the Lead in `gameDir` with `--plugin-dir`, `--add-dir <root>`, the root's
`.mcp.json`, absolute `.training/.ledger` denials and other games denied; the budget hook gets
the root as an argument (inside a game folder git names the game's repo). `transcript.py`
searches every config dir and project folder (fixes the L-092 gap). Trainer tests 28/28.

### Phase 6: DONE 2026-11-13 (move) — Lead test pending
Moved the 251 untracked game files + `FRAMEWORK_FEEDBACK.md` + place files (`.local/`) into
`games/clockwork-keep/` (made by `new-game`, `git init`, nothing committed); removed the 2
deleted starters; rewrote 4 requires to `@framework`; `game.json` filled; session `gameDir`
set. Checks: Rojo tree 127 = 127 (identical to before the move); Tier 1 1,590/0; balance OK;
framework repo clean; `status.py` shows the game. Pending: Studio reconnect + sync probe, then
the fresh-Lead test (task 9).

### Phase 1: Framework as a plugin
- [ ] Move `.claude/{skills,agents,commands,hooks}` → `plugins/roblox-framework/`; add
      `.claude-plugin/plugin.json`; list it in `.claude-plugin/marketplace.json`.
- [ ] `hooks/hooks.json` carries `status-freshness.sh` and the session registry (Phase 4).
- [ ] Root `.claude/settings.json` keeps only what factory-root sessions need.
- [ ] Hooks in the plugin use `${CLAUDE_PLUGIN_ROOT}` (today `$CLAUDE_PROJECT_DIR/.claude/hooks/…`).

### Phase 2: Template and new-game
- [ ] `template/`: `game.json`, `CLAUDE.md` shim, `.claude/settings.json`, `Makefile` shim,
      `default.project.json`, `.gitignore` (`.local/`, `*.rbxl*`, `sourcemap.json`),
      `src/game/**` starters (GameConfig, SmokeTest, ExampleMath + spec, Main scripts, empty
      AssetGenerators), `docs/` skeleton (`STATUS.md` from the template, `TESTING.md`,
      `decisions/README.md`, `design/{features,milestones,references}/.gitkeep`).
- [ ] Remove the starters from the factory's `src/game/`; move `FrameworkSmokeTest.lua` to
      `src/framework/`. Factory root no longer has a servable game.
- [ ] `scripts/new-game.sh <name>`: copy `template/` → `games/<name>`, fill `game.json`
      (`frameworkCommit`), `git init`, first commit. Refuses if the folder exists.
- [ ] `scripts/framework.mk`: `serve`, `test`, `test-all`, `balance`, `verify`, `claude`, all
      run from the game root. Factory `Makefile`: `new-game`, `games` (list), and
      `serve GAME=<name>` as a convenience.
- [ ] Game `.claude/settings.json`: allow edits inside the folder and on framework files
      (`../../**`, Q2); deny `Read`/`Edit` on `../../.training/**` and on other games
      (`../*` except this one). `.ledger/**`: read-only (Q2 doesn't cover the ledger; the
      trainer owns it).
- [ ] `tests/framework.lua`'s checks (GameConfig plain values) read the game's GameConfig.

### Phase 3: Rewrite framework paths
Files that name game or framework paths today: `CLAUDE.md`, `README.md`,
`.claude/hooks/status-freshness.sh`, skills `roblox-game-design`, `roblox-lead`,
`roblox-playtest`, `roblox-test`, `docs/design/README.md`, `docs/design/templates/*`,
`tests/run.lua`, `tests/framework.lua`, `scripts/verify.sh`, `bootstrap.sh`/`.bat`.
- [ ] `CLAUDE.md` *Project Structure*: game root vs factory root; a framework edit made from a
      game session stays game-agnostic and is committed in the factory repo, apart from game
      changes (Q2).
- [ ] Skills: framework paths via `$FACTORY` (or the Phase 0 mechanism); game paths unchanged.
- [ ] `verify.sh`: run from a game folder; checks `game.json`, Rojo serving that project.
- [ ] Bootstrap: installs tools once at the factory; `new-game` for the first game.

### Phase 4: Learning from human-driven sessions
- [ ] Session registry: a framework SessionStart hook appends
      `{session_id, transcript_path, started, driver, frameworkCommit}` to the game's
      `.local/sessions.jsonl` (hook stdin has `session_id` and `transcript_path`). `driver` is
      `lead` when `lead.py` sets `FRAMEWORK_DRIVER=lead`, else `human`.
- [ ] `CLAUDE.md` line: when the developer overrides your approach or a framework rule, log it
      in `FRAMEWORK_FEEDBACK.md` as `kind: correction` (what the framework said, what they did
      instead, why).
- [ ] `/debrief` command (framework plugin): reads this session's transcript, drafts
      corrections, decisions and friction for the developer to confirm, appends to
      `FRAMEWORK_FEEDBACK.md`.
- [ ] Trainer: `framework-review --game <name> --expert` reads `sessions.jsonl` (driver human)
      and the feedback file; ledger occurrences get `source: trainer|expert`;
      `learnings.py rank` weights `expert` higher. Only game-agnostic lessons are kept.

### Phase 4b: Home screen (`/start`) — maintainer request 2026-11-13
Problem: a fresh session (first-time user, or returning after weeks while the framework
moved on) doesn't know how to continue.
- [ ] `scripts/overview.py` (deterministic, cheap; the command only formats and offers
      choices). From the repo root it reports:
      - **framework:** commit, `framework:` commits since your last visit (`.local/last-seen`
        per clone), and since each game's `frameworkCommit` (what a game hasn't been updated
        for);
      - **active game** (`.local/active-game`): title, milestone and checkpoint, *Waits on
        the creator* from its `docs/STATUS.md`, open human checks, uncommitted changes, last
        activity;
      - **other games:** one line each (milestone, last activity, waiting items);
      - **published?** from `game.json` (placeId, last publish noted by the publish step;
        live state needs Open Cloud: later);
      - **handover docs:** each game's `docs/STATUS.md`; `.training/STATUS.md` when the trainer
        is present; `pending-decisions.md` count, harvest due.
- [ ] `/start` command (root `.claude/commands/start.md`): runs the overview, then offers:
      continue the active game (prints `cd games/<x> && make claude`, or with the trainer,
      starts its Lead), switch game, new game (`make new-game`), a detailed report of one game
      (STATUS, milestone boxes, decisions waiting, human checks), "what's new in the
      framework". First run with no games: setup (`/roblox-initialize`) then new game.
- [ ] Same command inside a game folder (from the framework plugin): that game's report only.
- [ ] **Default screen:** a root SessionStart hook prints one line to the user
      (`systemMessage`): "<Game> in progress (M4l, CP28; 2 items wait on you). /start for
      options", or "No games yet: /start", or "Framework changed since your last visit
      (N commits): /start". It also adds context for the agent: if the user's first message
      names no task, offer `/start`. `CLAUDE.md` gets the same one line.

### Phase 5: Trainer on games/
- [ ] `TRAINING_STATE.json` → `.training/games/<name>/state.json`; scenarios, messages and live
      logs move under `.training/games/<name>/`. Active game: `.training/active`.
- [ ] `lead.py`: `cwd=games/<name>`, `--plugin-dir`, `FRAMEWORK_DRIVER=lead`; profile paths
      relative to the game; transcripts found via `sessions.jsonl` first (fixes the L-092
      config-dir gap: today `$CLAUDE_CONFIG_DIR` set → only that dir is searched).
- [ ] `commit-framework.sh`: framework = everything tracked in the factory; refuse paths under
      `games/`; `--starters` and hunk staging retired.
- [ ] `game.py park/load` retired; `game.py list` lists `games/`. `session.py`, `status.py`,
      `human_checks.py`, `scorecard.py`, `transcript.py` take the game from `.training/active`.
- [ ] `framework-training`, `game-switch`, `framework-review` skills and the README updated;
      `tests/test_trainer.py` updated (throwaway repos with a `games/` child).

### Phase 6: Move Clockwork Keep (the test game)
See the section below.

### Phase 7: Tiptoe Bandits and clean-up (optional)
- [ ] Load `.training/archive/001-tiptoe-bandits` into `games/tiptoe-bandits` with the same
      steps as Phase 6, on the framework commit it was parked on noted in its `game.json`.
- [ ] Retire `.training/archive/` once both games are under `games/`.

### Phase 8: Close
- [ ] README (factory, starting a game, the session table), `.training/STATUS.md`, a decision
      record in the factory for the layout.
- [ ] Squash-merge to `main` when the maintainer says so (cf. the v2 squash plan). Never push
      unasked.

## Moving Clockwork Keep into the new structure

Clockwork Keep is at M4l CP28 (tasks 9–10 open), Lead idle. It continues in the new layout as
the test of this plan.

**Preconditions**
- [ ] Lead idle (`lead.py running` says no); Studio in Edit mode.
- [ ] Snapshot present: `.training/snapshots/2026-11-13-clockwork-keep-pre-restructure/`
      (254 game files, 2 deleted starters, `.ledger` and `.training`; `manifest.json`).
- [x] Rojo server stopped before any file moves (done 2026-11-13); Studio not connected.
- [x] Place copy downloaded (`tdx2.rbxl`, also in the snapshot as `place-copy-2026-11-13.rbxl`).
      How: in Studio, File → Download a Copy (published places have no Save to File) →
      a local `.rbxl`, as the rollback for Studio-owned content (Rojo may delete instances
      whose mapping changes). The place's version history on Roblox is a second fallback.
- [ ] Phases 0–5 done; `tests/test_trainer.py` passes.

**Steps**
- [ ] `scripts/new-game.sh clockwork-keep` (template copy, `git init`).
- [ ] Overlay the game's files from the snapshot manifest's `files` list (moved, not copied, from
      the factory tree), keeping their relative paths; then delete the manifest's `deleted`
      starters (`ExampleMath.lua`, its spec).
- [ ] Rewrite the 4 game files that require framework libraries by relative path
      (`tests/sim/{KeepCheck,Report,Sidegrade}.lua`, `tests/specs/Balance.slow.spec.lua`) to
      `@framework/…` (Phase 0).
- [ ] `FRAMEWORK_FEEDBACK.md` → game root; `tdx.rbxl`, `tdx2.rbxl` → `.local/`.
- [ ] `game.json`: title "Clockwork Keep", placeId 87673016436451, universeId 10775412362,
      `frameworkCommit` = the branch head.
- [ ] Trainer state: `TRAINING_STATE.json` → `.training/games/clockwork-keep/state.json`;
      `scenarios/002-like-tower-defense-x.md` → `scenario.md`; `messages/`, `messages-out/`,
      `live/clockwork-keep.jsonl` alongside. `human-checks-clockwork-keep.md` too.
- [ ] Game repo: `git init` only, no commit (Q1).
- [ ] Factory `git status`: no game files left; `src/game/` gone or template-free.

**Verify**
- [ ] `rojo sourcemap` parity: the new game project's instance tree equals the old one's
      (names, classes; file paths differ). Any difference is fixed before Studio connects.
- [ ] From `games/clockwork-keep`: `make test` = Tier 1 1,590/0 (as at CP28 + task 10's fixes).
- [ ] `make serve` from the game folder; Studio Rojo Disconnect → Connect (+ Accept);
      `FrameworkSmokeTest` and `PlacementController` sizes match disk.
- [ ] Smoke test passes (was 291/0 on the pre-task-10 code; expect more checks now).
- [ ] Factory-root trainer `status.py` shows the game, session and Lead state correctly.
- [ ] **The real test:** `lead.py fresh` from the factory with a "Rojo is reconnected, carry on
      with task 9" message. The Lead runs in `games/clockwork-keep`; its first reply (handoff
      check against `docs/STATUS.md`) must orient correctly, find its skills, and make no
      reads or writes outside the game folder (check the transcript for `../` paths and
      denials). Then tasks 9–10 → CP29 and the M4l close-out run on the new layout.

## Follow-ups (after the refactor)

### Connect Rojo only to the right Studio place (maintainer request 2026-11-13)
Two layers, both driven by `game.json`:
- **Published place: Rojo's own guard.** The project file's `servePlaceIds` ("a list of place
  IDs that this project may be live-synced to… helps prevent overwriting the wrong game",
  rojo.space v7 project format). `new-game`/migration writes the game's placeId there, so the
  Rojo plugin refuses to sync into any other published place, even after the user clicks
  Connect. Test: a second place open → Connect is refused.
- **Pre-serve check (`make serve`, agent side).** Before `rojo serve`, the Studio MCP's
  `list_roblox_studios` gives every open Studio's name, `mode`, and either `placeId` /
  `universeId` (published, `persistedToCloud`) or `file` (local file). Compare with
  `game.json` (`placeId`, or `localFile` for a game kept as a file):
  - no Studio open → "open <title> first";
  - none matches → warn and name what is open;
  - several Studios open, one matches → say which to connect from;
  - a local-file game: match the file path; `servePlaceIds` can't help (unpublished places
    have PlaceId 0), so this check is the only guard. Consider publishing early.
  `make serve` is a shell command and can't call MCP itself: the check runs where an agent
  starts Rojo (the `roblox-studio-mcp` skill's readiness step, `/start`, the trainer's
  readiness), and `make serve` prints a reminder when `servePlaceIds` is empty.
- After Accept, keep the existing sync probe (sizes or hashes of a synced script against disk,
  L-015): it catches a stale session, which neither layer above does.

## Rollback

To return to the old structure:
1. `git switch main` (framework back to `0ddf068`, the layout before this plan).
2. Move or delete `games/clockwork-keep/` (keep it if the move worked and only the framework
   side is being reverted).
3. `tar -xzf game-tree.tar.gz -C <repo-root>` from the snapshot; delete the 2 paths in the
   manifest's `deleted`.
4. If `.ledger/` or `.training/` were changed: `tar -xzf local-state.tar.gz -C <repo-root>`.
5. Studio: Rojo Disconnect → Connect; if instances went missing, open the saved place copy.
6. `make verify`, `make test`, smoke test. Work done in the new layout after the snapshot
   (e.g. task 9) has to be copied back by hand; note it in `.training/STATUS.md`.

## Open questions for the maintainer

1. **Game repos — DECIDED (maintainer, 2026-11-13):** each game gets its own git repo at its
   folder root. Nothing is committed in it yet; what it excludes (docs, plans…) is decided
   later. So `new-game.sh` runs `git init` without a first commit for now.
2. **Framework edits from a game session — DECIDED:** allowed. A game session may edit
   framework files (`$FACTORY/**`). Those edits land in the factory repo's working tree and
   are committed there, separately from game changes (`framework:` commits, as today). Still
   denied: `.training/**`, and other games' folders.
3. **`FRAMEWORK_FEEDBACK.md` — DECIDED:** tracked in the game repo for now (see 1).
4. **Teardowns:** keep a game's teardown in the game, or write game-agnostic ones to the
   factory's `docs/design/references/`? Proposed: in the game; promote by hand.
5. **Collaboration:** Rojo and Team Create clash when both sync. Proposed: one syncing
   developer at a time, or a personal copy of the place each; not solved in this plan.
6. **Decision ids** collide when two people write `0014` in parallel. Proposed: keep numbers
   for now (single developer); revisit with the first collaborator.

## Risks

- **Skill triggering** changes when skills come from a plugin (namespaced names). Phase 0
  measures it; L-001 is the precedent.
- **Rojo deletes instances** whose mapping changes. Sourcemap parity check + place copy.
- **Lead re-orientation**: a fresh Lead in a moved tree may trust stale paths in its own docs.
  The handoff check is the test; any wrong orientation is a finding.
- **Big diff on the framework**: every skill touched. Phases land as separate commits on the
  branch so a failing phase can be reverted alone.
