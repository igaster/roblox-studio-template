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

### Phase 0: Remaining spikes (throwaway, scratchpad)
- [ ] Real skills from a plugin: do `roblox-*` skills still trigger when namespaced
      (`roblox-framework:roblox-lead`)? Re-run L-001's probe (domain skills load on cue).
- [ ] `${CLAUDE_PLUGIN_ROOT}` inside skill text: substituted or not? Decides how skills name
      framework paths (else a SessionStart hook prints `FACTORY=<abs path>`).
- [ ] Rojo: `$path` outside the project folder (`../../src/shared`) serves and syncs.
- [ ] `rojo sourcemap` of today's `default.project.json` vs the new game project: same
      instance tree (names, classes), only file paths differ.
- [ ] Lune: `tests/run.lua` run from a game folder finds `tests/specs` there and the harness at
      `$FACTORY`.
- [ ] Collaborator route: `claude plugin install roblox-framework@<marketplace> --scope project`
      from a game folder; does it stay current after framework edits (L-083: cached copies)?
- [ ] Record results here; drop anything that fails and pick the fallback named in the step.

### Phase 1: Framework as a plugin
- [ ] Move `.claude/{skills,agents,commands,hooks}` → `plugins/roblox-framework/`; add
      `.claude-plugin/plugin.json`; list it in `.claude-plugin/marketplace.json`.
- [ ] `hooks/hooks.json` carries `status-freshness.sh` and the session registry (Phase 4).
- [ ] Root `.claude/settings.json` keeps only what factory-root sessions need.
- [ ] `.claude/skills/roblox-trainer` (pointer skill): keep at the root (it's for the maintainer).

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
- [ ] `FRAMEWORK_FEEDBACK.md` → game root; `tdx.rbxl` → `.local/`.
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
