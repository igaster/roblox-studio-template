# roblox-trainer (optional plugin)

Improves this framework by having games designed and built through it. The trainer plays the
game's **owner**: it gives the framework's Lead (`roblox-lead` skill) a brief, answers the
Lead's questions from a scenario policy, watches the run, reviews it for framework friction
and proposes framework fixes. It never makes game decisions itself, and the Lead is never told
it is being trained.

Off by default. Creators building games don't need it. When someone asks Claude to **train
or improve the framework** by having games built through it, this is the tool: suggest
enabling it (below), or enable it if they asked for that.

**Picking up training?** Start with `.training/STATUS.md` at the repo root (local, gitignored):
the current state, how to start a session, and the next options. The maintainer's standing
rules are below.

## Enable

For one session (also the way to develop the plugin, since it reads the folder directly):

```bash
claude --plugin-dir plugins/roblox-trainer
```

Persistently for this clone (installs a cached copy; after editing the plugin run
`claude plugin update roblox-trainer@roblox-framework`):

```bash
claude plugin marketplace add . --scope local
claude plugin install roblox-trainer@roblox-framework --scope local
```

Disable with `claude plugin disable roblox-trainer@roblox-framework`.

## What it does (in-place mode)

A training session builds one game in this repo's working tree:

1. `scripts/session.py start <name>` (or `--continue` for the game already in the tree).
2. You: Studio open on this project's place, Rojo plugin connected (once per session).
3. The trainer starts a headless Lead (`scripts/lead.py`) with a scenario brief, answers it
   as the owner, and reviews at each milestone end.
4. Approved framework fixes are committed with `scripts/commit-framework.sh` (framework
   paths only, never game files). Nothing is pushed.

Scenario briefs and owner policies live in `.training/scenarios/` (gitignored; the Lead is
denied reading `.training/`). Run records go to `.ledger/runs/` after the run. Everything the
trainer records in `.ledger/` stays local (gitignored); only its structure is committed. Games take turns in
the tree (one at a time): `game-switch` parks a game in `.training/archive/` and loads
another, and the framework stays shared and current throughout.

## Memory across games

One game's run is weak evidence, so most findings don't change the framework directly. They go
to the **learnings ledger** (`.ledger/learnings/`): one card per symptom, plus an occurrence each time
another run hits it. Between runs, `framework-harvest` ranks the cards by impact × runs × scope,
puts each through its gates (framework-caused, general, enough evidence, not already
covered), and turns the survivors into the smallest change that works: a check before a skill
line, a skill line before a `CLAUDE.md` line. It also proposes rules to prune. See
`.ledger/learnings/README.md`.

Harvests don't depend on anyone remembering them. `learnings.py due` says when one is due (5+
ready cards, or 3+ milestones since the last), a SessionStart hook prints a reminder, and the
milestone close-out runs a due harvest in **autonomous mode**. Low-risk changes (references,
small skill additions, tested helpers, trainer scripts, card housekeeping) are applied and
committed locally. Risky ones (`CLAUDE.md`, skill descriptions, the Lead's permissions,
shared APIs, removing rules) wait in `.ledger/learnings/pending-decisions.md` for the
maintainer. The Lead's build never waits for that queue.

Scripts (Python ones run with `python3 -I`):
- `scripts/status.py`: one screen: the game in the tree, the session, whether the Lead is
  running and what it's doing now, archived games, uncommitted framework changes, open
  human checks, whether a harvest is due, harvest-ready cards.
- `scripts/lead.py`: `start`, `say`, `fresh` (a new Lead conversation at a milestone's end,
  continuing from the repo), `stop`, `resume`, `running`. Budget guard: at 90% of the 5-hour
  usage window (`LEAD_PAUSE_AT`) the Lead is told to pause at a safe point and report; each
  call ends with a `[budget]` line. Logs every owner message
  to `.training/messages/` and streams the Lead's events to `.training/live/`.
- `scripts/game.py`: `park`, `load`, `switch` and `list` games in `.training/archive/`.
- `scripts/human_checks.py`: every check still waiting for a human, from the milestone files
  and `docs/TESTING.md`.
- `scripts/scorecard.py`: one row per milestone in `.ledger/scorecard.md`: how much an agent
  managed alone (minutes, denials, errors, human blockers, agent-verified vs open checks).
  Its trend across games is the measure of "suitable for AI game development".
- `scripts/learnings.py`: `rank` the cards, get the `next-id`, `check` their format, and
  `watch` whether adopted fixes stayed fixed in a run.
- `scripts/transcript.py`: a `digest` of the Lead's transcript, and run `metrics`.
- `scripts/context-budget.sh`: how much framework text agents read.
- `.ledger/learnings/coverage.md`: which framework areas each run exercised. Use it to pick the next
  game. Starts from `coverage.template.md`.

Skills:
- `framework-training`: run a session.
- `owner-proxy`: answer as the owner.
- `framework-review`: review a run and capture its learnings, with a blind second reviewer
  and an audit of the owner's messages.
- `framework-harvest`: curate the ledger into framework changes, asked for by the maintainer
  or run autonomously at a close-out when due (risky changes queued for the maintainer).
- `game-switch`: move games in and out of the tree; the framework stays shared.

Permission profile for the headless Lead: `permissions/lead-profile.json` (approved by the
owner; never widened without approval).

Tests for the scripts: `python3 -I plugins/roblox-trainer/tests/test_trainer.py` (throwaway
git repos, a stub in place of `claude`; nothing touches the real tree).

## Maintainer rules

The maintainer's standing instructions, kept here so they don't depend on one account's
memory.

- **The framework stays game-agnostic.** Handoff notes, session state, scenarios and
  anything about a specific game are local, in `.training/` at the repo root (gitignored;
  the Lead is denied reading it), and are never committed.
- **Commits only when asked, and framework files only.**
  - The games are test beds, so their files are never committed.
  - Use `scripts/commit-framework.sh`. New files must be named.
  - For a file with framework and game hunks, stage only the framework hunks: build a patch
    and `git apply --cached` it, since interactive staging isn't available.
  - Starter files (`commit-framework.sh --starters`: the template ships them, the game owns
    them) are never staged from the working copy. Stage the template version by hand.
  - Before committing, list what will be committed and what is left out. When unsure, ask.
- **Never push, open a PR or create a remote branch** unless asked at that moment. Asking
  for a commit is not asking for a push.
- **Framework fixes need the maintainer's approval.** They are committed only while no
  Lead is working.
- **One game at a time** (2026-11-08). Don't add framework support for parallel games
  (worktrees, per-game Rojo ports, several Studios). Games run one after another; the
  framework is shared and always the latest, and learnings build up across games through
  the ledger.
