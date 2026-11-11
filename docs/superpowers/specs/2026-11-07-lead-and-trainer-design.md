# Design: framework Lead mode + Trainer plugin

Date: 2026-11-07 · Branch: `v2` · Status: ready for owner approval

## Intent

Two separate ways of using AI agents on top of this Roblox framework:

1. **Lead (part of the framework).** A creator can hand the agent a game idea and have it
   designed and built end-to-end, deciding as much or as little as the creator wants, then
   take over to refine. This is a game-production role and knows nothing about improving the
   framework.
2. **Trainer (a plugin in this repo, off by default).** The framework maintainer uses it to
   improve the framework by having games designed and built: it plays the game's *owner*,
   drives the Lead, observes, collects friction, reviews and proposes framework changes. It
   never makes game decisions itself.

Why: today's dogfooding run (Tiptoe Bandits M1) showed the loop works but was hand-wired: a
human-started session, ad-hoc operating rules sent by message, a scratch review file, and game
and framework files mixed in one tree. This design makes both roles repeatable and keeps them
from contaminating each other.

## Goals

- A creator can say "build a game like X end-to-end" and get design docs, milestones and a
  built, verified M1 without being asked more than they chose to be asked.
- The same Lead behaviour runs in real use and in training (no training-only instructions
  injected into the Lead), so training measures what creators actually get.
- The maintainer can say "train the framework" / "improve the framework" and get a
  repeatable run: brief → Lead runs the game → findings → proposed framework changes.
- Fix the framework findings from the M1 run (below) so the next training run tests an
  improved framework.

## Non-goals

- Parallel developer agents (Option B) — the design leaves room for it but doesn't build it.
- Fully unattended Studio: opening Studio, Rojo Connect and the Studio MCP toggle stay human
  steps (the Lead detects and asks; it never works around them).
- Committing or modifying the in-progress Tiptoe Bandits game files.

## Anti-goals (failure even if it "works")

- Lead and Trainer overlap: the Lead critiques the framework, or the Trainer makes game
  design decisions.
- The Lead behaves differently when trained than when used by a creator.
- Trainer scaffolding becomes active in a creator's clone without them asking.
- Any agent silently widening its own or another session's permissions.

## Decided by the owner

- Two roles, no overlap: framework Lead (game decisions) vs. Trainer plugin (framework
  improvement).
- **Option A**: the Lead is a *mode* within one session (it designs and builds), structured so
  it can later delegate milestones to developer sessions (Option B).
- **Friction logging is a framework feature**, not something the Trainer injects.
- **An "owner involvement" setting** is the contract between owner and Lead.
- The **Trainer acts as the owner** in training runs.
- The Trainer plugin **lives in this repo** (`plugins/`), off by default.
- When the scenario's owner policy doesn't cover a Lead question, the Trainer answers
  "your call, mark it `(assumed)`" (never decides itself).
- **Training runs in place by default**: a single-game session builds the game in this repo's
  own working tree (as the Tiptoe Bandits run did). The **multi-game mode** (several games in
  sequence, each a full local git clone in a numbered folder under a training root, with its
  own place file and a human step per game) is **optional and built later** (see
  `docs/TODO.md`).
- Framework fixes are committed locally before the next game; pushing is batched and only
  on the owner's request.
- **The framework is aware of the Trainer**: when the user asks for "training" or to "improve
  the framework", the agent suggests enabling it, or enables it when the user asked for that.

## Part 1 — Framework Lead mode

### `roblox-lead` skill (new, thin)

Triggers on: "build a game end-to-end", "make the whole game", "take it from here", "run the
next milestone", or any request to proceed without step-by-step involvement.

Responsibilities (and only these):
- Read the **Owner involvement** setting and follow it (below).
- Run the end-to-end loop: `roblox-game-design` pipeline (stages 0–4) → build the milestone
  (`superpowers:executing-plans` when available, else follow the plan directly) → stage 5
  result → next milestone, until the stop condition.
- Keep a **production log**: the milestone files' Status/Result sections plus the GDD
  Decisions log (no new file).
- Pause correctly: at milestone boundaries per the involvement setting; whenever a human-only
  step is needed (Studio/Rojo), stating exactly what and why.

It does **not** duplicate design guidance: all design questions, templates and rules stay in
`roblox-game-design`. (My call: thin new skill instead of extending `roblox-game-design`, so
"how to design" and "how to run production autonomously" stay separate and testable.)

### Owner involvement setting (the owner ↔ Lead contract)

A short section at the top of `docs/design/GDD.md` (added to the GDD template):

| Level | Lead asks the owner… | Lead decides alone (marks `(assumed)`) |
|---|---|---|
| `full` | at every pipeline stage and design choice | nothing material |
| `milestones` (default) | selling point, GDD approval, each milestone plan | everything inside an approved milestone |
| `none` | nothing; reports at milestone ends | everything, logged in the Decisions log |

Plus: **Stop after:** `M1` / `M<N>` / `never` (default `M1`). Owner can change both any time.
Questions to the owner are always plain text at the end of a turn (never interactive
dialogs), so the same Lead works with a human, a remote-controlled session or the Trainer.

### `game-developer` agent definition (prepared, unused by default)

`.claude/agents/game-developer.md`: a subagent persona that implements one approved
milestone plan (or task) following CLAUDE.md, reports per checkpoint, never changes design
or scope. Not invoked in Option A; it exists so Option B is a configuration change, not a
redesign. (My call: ship it now but keep the Lead skill on "build it yourself".)

### Friction log (framework feature)

- File: `FRAMEWORK_FEEDBACK.md` at the repo root, **gitignored in the template** (it's
  per-clone working notes, never game content). (My call on name/location: explicit name so
  it's never confused with game feedback.)
- `CLAUDE.md` gets a short "Framework friction" convention: when the framework (CLAUDE.md,
  skills, templates, shared modules) is missing something, unclear, wrong, or gets in the way,
  append one entry; don't go looking for problems. Entry format = today's FEEDBACK.md format
  (When / Framework said or lacked / Workaround / Suggestion).
- Always on (cheap, one entry per real friction). Real creators benefit; the Trainer reads it.

## Part 2 — Trainer plugin (`plugins/roblox-trainer/`)

Plugin layout (Claude Code plugin format), listed in a repo-root
`.claude-plugin/marketplace.json` so this repo is its own plugin source:

```
plugins/roblox-trainer/
├── .claude-plugin/plugin.json
├── skills/
│   ├── framework-training/     # run a training run end to end (orchestration)
│   ├── owner-proxy/            # how to act as the owner: answer per scenario policy
│   └── framework-review/       # review a run: transcript + friction log → findings → fixes
├── agents/
│   └── critic.md               # optional independent reviewer of the built game
├── scenarios/                  # reusable briefs + owner policy (e.g. like-a-game.md)
├── scripts/                    # provision workspace, launch/resume headless Lead, watch
└── README.md
```

### In-place mode (built now, default)

- The game is built in this repo's working tree; Rojo keeps serving this repo, and the human
  connects Studio once at the start of the session.
- Game and framework files share the tree, so the Trainer **commits framework files only**,
  by an explicit path list (`CLAUDE.md .claude .claude-plugin plugins scripts src/shared
  docs/design/templates docs/design/README.md docs/superpowers Makefile .mcp.json
  default.project.json rokit.toml .gitignore`); game files are never committed by the Trainer.
- Framework fixes reach the running game immediately, so they're applied **only at milestone
  boundaries**, while the Lead is idle. Each milestone Result records the framework commit it
  ran against.
- The Lead could read `plugins/roblox-trainer/` here (no clone to strip it from). Mitigation:
  scenario briefs and owner policies are passed to the Trainer at session start (from a file
  outside the repo or the maintainer's message), not stored in the plugin; run records are
  written only after the run. (My call.)
- State: `TRAINING_STATE.json` at the repo root (gitignored): game name, framework commit at
  start, Lead session id, current milestone, lock.

### Multi-game mode (later, optional — design kept for reference)

```
<training-root>/                     default: ../roblox-training/ (sibling of this repo; my call)
├── TRAINING_STATE.json              current game, framework commit, Rojo port, place file,
│                                    lead session id, milestone; also a lock (one trainer)
├── 001-tiptoe-bandits/              full local clone of the framework at commit X + the game
│   └── 001-tiptoe-bandits.rbxl      its own place, created and saved by the human
└── 002-…/
```

- **One training session builds several games in sequence**, never in parallel.
- **Each game is a full local `git clone`** of this repo's framework branch at its current
  commit (`git clone --branch <branch> <this-repo-path> <training-root>/00N-<name>`):
  pinned, only committed files, git history kept so the trainer can `git diff <commit>` to
  detect the lead editing framework files (a friction signal).
- Provisioning then: removes the clone's `origin` remote (no accidental push into the
  framework), deletes `plugins/roblox-trainer/` from the clone, and makes the Studio/context7
  MCP servers usable without a prompt (copy the MCP approval or launch with `--mcp-config`).
- **Framework fixes must be committed before the next game is provisioned** (the trainer
  refuses to provision from a dirty framework tree). Fixes never reach a game already in
  progress; the next game tests them. **Pushing is separate and batched**, only when the
  owner asks.
- **Human step at the start of each game**: in Studio, File → New (Baseplate), save as
  `<game-folder>/<game-folder>.rbxl`, close the previous game's place, click Rojo Connect.
  The trainer has already stopped the previous Rojo server and started one on the new game
  folder. It then verifies: `list_roblox_studios` shows the place named after the folder
  (also selects the `studio_id`), Rojo connection established, sync probe passes.
- `roblox-studio-mcp`'s "never restart `rojo serve`" rule gets an explicit exception:
  switching projects between games is allowed; restarting to "fix" sync is still forbidden.

### A training run (one game)

1. **Pick a scenario** (brief + owner policy + involvement level + stop condition). Scenario
   policies are written or approved by the owner, never drafted by the trainer.
2. **Provision** the next game folder (above) and do the human step.
3. **Launch the Lead headless** in the game folder (`claude -p … --resume`) with the approved
   permission profile; the Trainer only sends the scenario brief and, per policy, owner
   answers. It injects no training instructions (the friction log is a framework convention).
4. **Owner answers**: per the scenario policy. When the policy doesn't cover a question, the
   Trainer replies "your call, mark it `(assumed)`" (owner decision: the Trainer never makes
   a game decision). Scenarios may list topics that always go to the maintainer instead.
   Runs can therefore proceed unattended between human steps.
5. **Observe**: follow the Lead's transcript; intervene only as the owner or for human-only
   blockers (asking the maintainer).
6. **Review** at milestone ends / run end (`framework-review`): Lead transcript +
   `FRAMEWORK_FEEDBACK.md` + produced artifacts + `git diff` of framework files → findings
   ranked by severity.
7. **Propose framework changes** to the maintainer; on approval, implement and commit in
   this repo (framework files only), never in a game folder.
8. **Record the run** in `plugins/roblox-trainer/runs/<NNN>-<name>.md` (scenario, framework
   commit, findings, which became changes) — committed, so improvement history is kept.

### Isolation and versions (my calls)

- **The Lead never sees Trainer material.** Provisioning deletes `plugins/roblox-trainer/`
  (scenarios with planned owner answers, past run records) from the game clone. Creators'
  clones still contain the folder (owner decision: plugin lives in this repo); it's inert
  unless enabled.
- **A game is pinned** to the framework commit it was cloned from (see *Training workspace*).
  Upgrading a game in progress, or a `game/` folder split that would make games portable
  across framework versions, are possible later features, not part of this work.

### Permission profile (approved once by the owner)

The headless Lead can't answer prompts, so it runs with a predefined profile: allowed tools
(file edits within the workspace, `lune`/`rojo`/`make`/`git status|diff` shell commands,
Studio + context7 MCP tools) and **no** `git commit/push`. The Trainer drafts the profile;
the owner approves it once; it's committed in the plugin. The Trainer never widens it on its
own.

### Framework awareness (owner decision)

- `CLAUDE.md` gets one line: if the user asks to train/improve the framework, suggest
  enabling the `roblox-trainer` plugin (or enable it if they asked you to), and explain it's
  off by default.
- Enabling = adding the repo's marketplace + `roblox-trainer` to `enabledPlugins` in
  `.claude/settings.local.json` (personal, not committed), effective on next session start;
  or launching with `claude --plugin-dir plugins/roblox-trainer`. **Verify both mechanisms in
  a spike before building on them.**
- The plugin is inert in creators' clones unless enabled.

## Part 3 — Framework fixes from the M1 run

Folded into this work (details and evidence in `2026-11-07-m1-run-findings.md`, next to this
file):

1. **TestHooks event buffer invisible via `execute_luau`** (fresh module copy). Move the
   buffer to the DataModel (e.g. a folder/attribute store under ServerStorage) so any context
   can read it; verify in Studio. *(highest priority)*
2. Greybox/prototype **levels**: document the level-generator variant (builds into a fixed
   home, always rebuild at start, retire when hand-placed art takes over); add to CLAUDE.md
   "What Rojo Syncs" and `roblox-asset-generators`.
3. The stale-content rule must be visible at **planning** time (CLAUDE.md or the design
   skill's stage 4), not only in the asset skill.
4. `roblox-asset-generators` didn't trigger when creating a generator from a plan: widen its
   description triggers.
5. **GUI generator pattern**: server builds the UI into the player's PlayerGui (or
   ReplicatedStorage); client controllers bind to it. Document it.
6. **Rojo sync**: stale tree + live TCP + "wrong session ID" warning ⇒ ask for
   Disconnect → Connect (common after sleep); re-probe once before declaring a blocker. Update
   `roblox-studio-mcp`.
7. `roblox-playtest`: generalize the "single `execute_luau` with a sampling loop" advice to any
   fast-changing state; add `character_navigation` failing inside Studio's own tool as a known
   failure with the teleport/attribute fallback.
8. Template hygiene: ship `docs/design/{references,milestones,features}/` folders; gitignore
   `.superpowers/`; reset `default.project.json` name; note that the template
   place's Baseplate (top at Y=0) z-fights with generated floors.
9. `make verify` readiness check, shell-checkable parts only: toolchain on PATH (with
   `~/.rokit/bin` fallback), Rojo serving on 34872, and a Studio process holding an
   established connection to it (`lsof`). The MCP side (Studio MCP reachable, tree actually
   synced) is checked by the agent via `roblox-studio-mcp`, not by `make`. (My call.)
10. **`critic` references**: CLAUDE.md and `roblox-playtest` mention a `critic` agent that
    doesn't ship. Replace with "a fresh reviewer subagent" (what the Lead already did in M1),
    so the Lead's behaviour never depends on the Trainer plugin. The Trainer may have its own
    critic for reviewing runs; the Lead never calls it. (My call.)

## Constraints

- Only framework files are committed; the Tiptoe Bandits files in this tree stay untouched
  and uncommitted (see *Tiptoe Bandits*).
- Nothing pushed to the remote without the owner asking.
- Plugin format and CLI flags (`--plugin-dir`, `--mcp-config`, `--append-system-prompt`,
  `-p/--resume`, permission flags) are verified in a spike before the plan relies on them.

## Left to the builder

- Exact skill wording, trigger phrases and file names beyond those fixed above.
- Script language for `scripts/` (shell or Lune), as long as it runs on macOS.
- The TestHooks storage representation, as long as all contexts can read it and it stays
  bounded.
- Order of work, provided the spike comes before anything depending on headless sessions or
  plugin enabling.

## Tiptoe Bandits (owner decision)

Out of scope for now: its files stay untouched and uncommitted in this tree, and are excluded
from every framework commit. Its future (move to the training root or not) is decided later.
Note: an in-place training session can only start once this tree has no other game in it
(Tiptoe moved or removed); until then, the next in-place session waits or uses a clean clone.
