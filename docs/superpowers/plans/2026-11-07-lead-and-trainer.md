# Lead Mode + Trainer Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the M1-run framework findings, add a framework Lead mode (end-to-end game production with an owner-involvement contract and an always-on friction log), and add an off-by-default `roblox-trainer` plugin that improves the framework by running games in local-clone game folders.

**Architecture:** Framework fixes and the Lead live in the existing framework (CLAUDE.md, `.claude/skills/`, `.claude/agents/`, `src/shared/`, `docs/design/templates/`). The Trainer is a Claude Code plugin in `plugins/roblox-trainer/`, listed by a repo-root `.claude-plugin/marketplace.json`; it runs **in place** (the game is built in this repo's working tree) and drives a headless Lead session there. Multi-game mode (local clones under a training root) is deferred to `docs/TODO.md`.

**Tech Stack:** Luau (Roblox, Lune for Tier 1), Rojo, Claude Code skills/agents/plugins, bash (macOS) for plugin scripts.

**Spec:** `docs/superpowers/specs/2026-11-07-lead-and-trainer-design.md` (+ evidence in `docs/superpowers/specs/2026-11-07-m1-run-findings.md`)

## Global Constraints

- **Never touch the Tiptoe Bandits files** (uncommitted game work in this tree): `docs/TESTING.md`, `src/game/ReplicatedStorage/GameConfig.lua`, `src/game/ReplicatedStorage/Modules/*` (incl. the deleted `ExampleMath.lua`), `src/game/ServerScriptService/SmokeTest.lua`, `tests/suite.lua`, `docs/design/{GDD.md,features/,milestones/,references/}`, `FEEDBACK.md`, and game files under `src/game/**`. New framework tests go in **new** files.
- Commits: local only, framework files only, staged by explicit path (never `git add -A`/`.`); **no push**. Message trailer as in recent commits.
- Tool versions are stated only in `rokit.toml`; don't restate them.
- Skill descriptions start with "Use when…" and describe triggers only (no workflow summary).
- The Lead never references the Trainer, training, or the framework-improvement process; the Trainer never makes game decisions (policy-silent questions → "your call, mark it `(assumed)`").
- Friction log file name: `FRAMEWORK_FEEDBACK.md` (repo/game root, gitignored).
- Owner involvement levels: `full` | `milestones` (default) | `none`; **Stop after:** `M<N>` | `never` (default `M1`).
- In-place training: state file `TRAINING_STATE.json` at the repo root (gitignored). Framework commits by the Trainer use only this path list: `CLAUDE.md .claude .claude-plugin plugins scripts src/shared docs/design/templates docs/design/README.md docs/superpowers docs/TODO.md Makefile .mcp.json default.project.json rokit.toml .gitignore`.
- Multi-game mode (training root, local clones, Rojo switching) is **not built** in this plan.
- "Never restart `rojo serve`" stays absolute **except** when switching the served project between games.

## Review Focus

1. **Starting a session while another game already occupies the tree** (e.g. `docs/design/GDD.md` exists) or `TRAINING_STATE.json` holds an active lock → the session-start script refuses with a message, changing nothing. (Task 10)
2. **A framework commit that would include game files** → the commit helper stages only the framework path list and aborts if nothing framework-owned changed. (Task 10)
3. **TestHooks event data with non-JSON values** (Vector3, Instance, nested tables, functions) → logged with values stringified, no error; buffer stays ≤ 500 events. (Task 2)
4. **TestHooks.log called on a client** (no ServerStorage access) → still prints, no error, nothing stored. (Task 2)
5. **Studio has the wrong place open when a game starts** → the trainer's readiness check reports a place-name mismatch instead of starting the Lead. (Task 11, `framework-training` readiness step)

---

### Task 1: Spike — verify the mechanisms the plan relies on (throwaway)

**Files:**
- Create: `docs/superpowers/specs/2026-11-07-spike-results.md` (results only; spike code lives in the scratchpad and is deleted)

**Interfaces:**
- Produces: confirmed (or corrected) commands for Tasks 9–11: plugin loading, headless launch/resume, MCP without prompt, permission flags.

- [ ] **Step 1: Plugin loading.** Create a scratch plugin with one skill; run `claude -p "list your skills" --plugin-dir <scratch-plugin>`; record whether the skill appears and its namespaced name. Then check whether `enabledPlugins` + a local marketplace in a scratch project's `.claude/settings.local.json` loads it on next start. Record exact JSON that worked.
- [ ] **Step 2: Headless session.** In a scratch clone of this repo: `claude -p "say hi" --output-format json` → capture `session_id`; then `claude -p "what did I say?" --resume <id> --output-format json`. Record exact flags and JSON fields.
- [ ] **Step 3: MCP without prompt + permissions.** In the same clone, launch with `--mcp-config .mcp.json` (and separately without, relying on copied `.claude/settings.local.json`); ask it to call `execute_luau` with `print("spike ok")` (Studio open). Try `--permission-mode` / `--allowedTools` values that permit Edit/Write/Bash(lune|rojo|make|git status|git diff) and MCP tools while blocking `git commit`/`git push`. Record what works.
- [ ] **Step 4: `--append-system-prompt`.** Confirm it's honored in `-p` mode (ask the session to repeat a sentence given only there).
- [ ] **Step 6: Write results** to the spike file: per mechanism, works / doesn't / workaround, with exact commands. If a mechanism fails, note which later task changes and how; report to the owner before continuing.
- [ ] **Step 7: Commit** `docs/superpowers/specs/2026-11-07-spike-results.md`.

### Task 2: TestHooks event buffer in the DataModel

**Files:**
- Modify: `src/shared/TestHooks.lua`
- Create: `src/game/ServerScriptService/FrameworkSmokeTest.lua` (ModuleScript, never auto-runs)

**Interfaces:**
- Produces (unchanged public API): `TestHooks.log(category: string, message: string, data: any?)`, `TestHooks.getEvents(sinceTime: number?, category: string?): {Event}` where `Event = { time: number, category: string, message: string, data: any }`, `tagInteractable`, `dumpState`, `teleportNear`.
- Produces: storage `ServerStorage.TestHooksEvents` (Folder), one child per event, oldest removed past `MAX_EVENTS = 500`; any `require()` copy in any server context reads the same events.
- Produces: `FrameworkSmokeTest.run(): boolean` printing per-check `PASS`/`FAIL` and `FRAMEWORK SMOKE OK` / `FRAMEWORK SMOKE FAILED`.

- [ ] **Step 1: Write the failing in-engine test** `FrameworkSmokeTest.run()` with checks:
  - `cross-copy events`: log via `require(ReplicatedStorage.Shared.TestHooks)`, then read via a **fresh** copy (`require(ReplicatedStorage.Shared.TestHooks:Clone())` parented temporarily) → the event is present.
  - `bounded`: log 510 events → `#getEvents() <= 500` and the oldest 10 are gone.
  - `non-JSON data`: log `{ pos = Vector3.new(1,2,3), part = Instance.new("Part"), fn = function() end }` → no error; read back `data.pos` is a string.
  - `filters`: `getEvents(t, "A")` returns only category `A` events at/after `t`.
  - Cleanup: destroy test events/instances it created.
- [ ] **Step 2: Run it in Studio** via MCP `execute_luau` (Server, Play or Edit): `return require(game.ServerScriptService.FrameworkSmokeTest).run()` → expect `cross-copy events` FAIL (current module-local buffer).
- [ ] **Step 3: Implement** storage in `ServerStorage.TestHooksEvents`: each event a child instance with attributes `Time` (os.clock), `Category`, `Message`, `Data` (JSON via `HttpService:JSONEncode` after converting non-JSON values with `tostring`, recursively, depth-limited). On a client (`RunService:IsClient()`), `log` only prints. Update the header comment: remove the `critic` mention; say events are readable from any server context.
- [ ] **Step 4: Re-run** → `FRAMEWORK SMOKE OK`. Also run `lune run tests/suite.lua` → still passes.
- [ ] **Step 5: Commit** `src/shared/TestHooks.lua`, `src/game/ServerScriptService/FrameworkSmokeTest.lua`.

### Task 3: `make verify` and toolchain fallback

**Files:**
- Create: `scripts/verify.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces: `make verify` → runs `scripts/verify.sh`; prints one line per check `OK|FAIL <check>: <detail>`; exit 0 only if all pass. Checks: `rokit`/`rojo`/`lune` resolvable (PATH, else `~/.rokit/bin/`), `rojo serve` listening on 34872, a Studio process with an ESTABLISHED connection to 34872 (`lsof`). Last line reminds that MCP/sync checks are done by the agent (`roblox-studio-mcp`).
- Produces: `make test` uses `lune` from PATH or `~/.rokit/bin/lune`.

- [ ] **Step 1:** Run `make verify` → fails (no target).
- [ ] **Step 2:** Implement `scripts/verify.sh` (bash, `set -u`, macOS `lsof`) and the `verify` target; make `test` resolve `LUNE ?= $(shell command -v lune || echo $(HOME)/.rokit/bin/lune)`.
- [ ] **Step 3:** Verify: with Rojo running and Studio connected → all OK; stop nothing, but run with `PORT=34999 scripts/verify.sh` (support a `PORT` override) → Rojo/Studio checks FAIL, exit non-zero. `make test` still passes.
- [ ] **Step 4: Commit** `scripts/verify.sh`, `Makefile`.

### Task 4: Template hygiene

**Files:**
- Modify: `.gitignore`, `default.project.json`, `docs/design/README.md`
- Create: `docs/design/references/.gitkeep`, `docs/design/milestones/.gitkeep`, `docs/design/features/.gitkeep`

**Interfaces:** Produces: ignored `.superpowers/` and `FRAMEWORK_FEEDBACK.md`; project name `"Roblox Game"`.

- [ ] **Step 1:** Add `.superpowers/`, `/FRAMEWORK_FEEDBACK.md` and `/TRAINING_STATE.json` to `.gitignore`; remove the obsolete `/sandbox/`, `framework-dogfooding` and `critic.md` entries (replaced by the plugin).
- [ ] **Step 2:** Set `default.project.json` `"name"` to `"Roblox Game"`.
- [ ] **Step 3:** Add the three `.gitkeep` files (use `git add -f` if ignored); in `docs/design/README.md` add one line: a new place from Studio's Baseplate template has its top at Y=0, so generated floors should sit above it (or remove the Baseplate).
- [ ] **Step 4:** Verify `rojo sourcemap default.project.json` succeeds and `git status` shows `FRAMEWORK_FEEDBACK.md`-named files ignored (`touch FRAMEWORK_FEEDBACK.md; git check-ignore FRAMEWORK_FEEDBACK.md; rm FRAMEWORK_FEEDBACK.md`).
- [ ] **Step 5: Commit** the files above (the `.gitkeep`s explicitly; never `docs/design/` wholesale — it contains game docs).

### Task 5: Levels, GUI generators and the stale-content rule

**Files:**
- Modify: `CLAUDE.md` (*What Rojo Syncs vs. What Studio Owns*), `.claude/skills/roblox-asset-generators/SKILL.md`, `.claude/skills/roblox-game-design/SKILL.md` (stage 4 only)

**Interfaces:** Produces documented patterns: **level generator** (`build()` replaces its fixed home, e.g. `workspace.<Level>`, called on every server start, retired once art is hand-placed) and **GUI generator** (server builds into each player's `PlayerGui` on join, client controllers `WaitForChild` and bind).

- [ ] **Step 1:** CLAUDE.md: add two bullets: greybox/prototype levels may be built at server start by a level generator, **always rebuild, never "skip if it exists"** (place-saved Workspace content shadows generator fixes); once art is hand-placed in Studio, retire the generator.
- [ ] **Step 2:** Asset skill: description adds triggers "creating or editing any file under `AssetGenerators/`, including from a plan"; add *Level generators* and *GUI generators* subsections (rule 1's "don't parent" applies to reusable assets, not levels/UI roots).
- [ ] **Step 3:** Design skill stage 4: each task that creates world or UI content names its generator kind (asset / level / GUI) per `roblox-asset-generators`.
- [ ] **Step 4:** Verify by dry run: a fresh subagent given "Plan a task that builds the greybox room at server start" (repo read-only) proposes always-rebuild and loads/quotes `roblox-asset-generators`. Record result in the commit message body.
- [ ] **Step 5: Commit** the three files.

### Task 6: Studio MCP and playtest guidance

**Files:**
- Modify: `.claude/skills/roblox-studio-mcp/SKILL.md`, `.claude/skills/roblox-playtest/SKILL.md`

- [ ] **Step 1:** `roblox-studio-mcp`: add *Stale tree with a live connection*: probe shows old content while Studio has an ESTABLISHED connection (`make verify`) → check console/Studio log for `[Rojo-Warn] Received message with wrong session ID` → re-probe once after ~30 s → if still stale, ask the human for **Disconnect → Connect** (common after sleep). Add the project-switch exception to the never-restart rule. Trim the long incident narratives into one *Known failures* list (keep the facts, drop the story).
- [ ] **Step 2:** `roblox-playtest`: generalize the single-`execute_luau` sampling-loop technique to any fast-changing state (NPC state machines, timers), not only custom movement; add `character_navigation` erroring inside Studio's own Assistant tool as a known failure with fallback (teleport via `TestHooks.teleportNear`/`PivotTo` + attributes); replace `critic` / `REPORT.md` / `FEEDBACK_LOG.md` mentions with "a fresh reviewer subagent" / `FRAMEWORK_FEEDBACK.md`.
- [ ] **Step 3:** Verify: `grep -n "critic\|REPORT.md\|FEEDBACK_LOG" .claude/skills` → no matches; `wc -w` of `roblox-studio-mcp/SKILL.md` is lower than before.
- [ ] **Step 4: Commit** both files.

### Task 7: Friction log convention and CLAUDE.md cleanup

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1:** Add section *Framework friction*: when the framework (CLAUDE.md, skills, templates, `src/shared/`) is missing something you needed, unclear, wrong, or gets in your way, append one entry to `FRAMEWORK_FEEDBACK.md` (format: `## <title>` / **When** / **Framework said / lacked** / **Workaround** / **Suggestion**); don't go looking for problems.
- [ ] **Step 2:** Rewrite the Observability paragraphs to drop the `critic` agent; TestHooks events are read via `execute_luau` (Server) and survive across module copies.
- [ ] **Step 3:** Verify `grep -n critic CLAUDE.md` → none.
- [ ] **Step 4: Commit** `CLAUDE.md`.

### Task 8: Lead mode — owner involvement, `roblox-lead`, `game-developer`

**Files:**
- Modify: `docs/design/templates/GDD.md` (top section), `.claude/skills/roblox-game-design/SKILL.md` (one pointer line)
- Create: `.claude/skills/roblox-lead/SKILL.md`, `.claude/agents/game-developer.md`

**Interfaces:**
- Produces: GDD template section `## Owner involvement` with fields `Level: milestones` and `Stop after: M1` and the level table from the spec.
- Produces: `roblox-lead` skill (triggers: "build a game end-to-end", "make the whole game", "take it from here", "run the next milestone", "keep going without me"). Body: read/ask for Owner involvement → loop (`roblox-game-design` stages 0–4 → build the milestone via `superpowers:executing-plans` if available, else follow the plan → stage 5 result) until **Stop after**; questions to the owner as plain text at the end of a turn, never interactive dialogs; decisions taken alone marked `(assumed)` and logged in the GDD Decisions log; human-only Studio steps stated exactly; uses a fresh reviewer subagent at milestone end. No mention of training.
- Produces: `game-developer` agent (description "Use to implement one approved milestone plan or task…"; tools: all; instructions: follow CLAUDE.md and the plan, never change design or scope, report at checkpoints). Not referenced by `roblox-lead` yet beyond one line: "Option for later: delegate a milestone to the `game-developer` agent".

- [ ] **Step 1 (RED):** Dry run with a fresh subagent (repo read-only): "Build a Roblox game about delivering pizzas by hoverboard end-to-end; involve me only for the selling point." Record: does it read an involvement setting, avoid interactive dialogs, plan to continue past the GDD to build M1, mark assumptions, stop after M1?
- [ ] **Step 2:** Write the template section, the skill and the agent.
- [ ] **Step 3 (GREEN):** Re-run the same dry run → all five behaviors present; additionally run "Change the giant's speed" → `roblox-lead` does **not** trigger (`roblox-game-design` mode C does).
- [ ] **Step 4: Commit** the four files.

### Task 9: Trainer plugin scaffold and framework awareness

**Files:**
- Create: `.claude-plugin/marketplace.json`, `plugins/roblox-trainer/.claude-plugin/plugin.json`, `plugins/roblox-trainer/README.md`
- Commit with this task: `docs/TODO.md` (multi-game mode note, already written)
- Modify: `CLAUDE.md` (one awareness line)

**Interfaces:**
- Consumes: Task 1 results (exact enabling mechanism).
- Produces: marketplace name `roblox-framework`, plugin `roblox-trainer` (version `0.1.0`); enabling instructions in the README for both `--plugin-dir plugins/roblox-trainer` and settings-based enabling.
- Produces CLAUDE.md line: "If the user asks to train or improve the framework, suggest enabling the `roblox-trainer` plugin (off by default; see `plugins/roblox-trainer/README.md`), or enable it if they asked you to."

- [ ] **Step 1:** Write the three files and the CLAUDE.md line.
- [ ] **Step 2:** Verify: `claude -p "list your skills" --plugin-dir plugins/roblox-trainer` loads without error (skills come in Task 11); a session in this repo asked "I want to improve the framework" suggests enabling the plugin (dry-run subagent).
- [ ] **Step 3: Commit** the four files and `docs/TODO.md`.

### Task 10: Trainer scripts — in-place session, state, headless Lead, safe commits

**Files:**
- Create: `plugins/roblox-trainer/scripts/session.sh`, `plugins/roblox-trainer/scripts/lead.sh`, `plugins/roblox-trainer/scripts/commit-framework.sh`, `plugins/roblox-trainer/permissions/lead-profile.json`, `plugins/roblox-trainer/tests/session.test.sh`

**Interfaces:**
- Produces: `session.sh start <kebab-name>` → refuses (exit 1, message, no changes) if `docs/design/GDD.md` exists (another game occupies the tree) or `TRAINING_STATE.json` has a live lock (pid alive); otherwise writes `TRAINING_STATE.json` `{ game, frameworkCommit, leadSessionId: null, milestone: null, lockedBy, startedAt, updatedAt }`. `session.sh end` releases the lock. `session.sh milestone <M>` records the milestone and current framework commit.
- Produces: `lead.sh start <brief-file>` / `lead.sh say <message-file>` → headless `claude -p` in the repo root with the permission profile (flags from Task 1), no training instructions, JSON output; stores `leadSessionId` in state; `say` resumes it (exit 1 with a message if no session id).
- Produces: `commit-framework.sh "<message>"` → `git add` only the framework path list (Global Constraints), shows the staged file list, aborts if nothing is staged, then commits with the standard trailer. Never pushes.
- Produces: `lead-profile.json` (allowed: Edit/Write in the repo, Bash `lune|rojo|make|git status|git diff|git log`, MCP `Roblox_Studio`/`context7`; denied: `git commit`, `git push`).

- [ ] **Step 1: Write failing tests** `tests/session.test.sh` (bash, in a temp copy of the repo with `git init`): `start alpha` writes state with `frameworkCommit`; second `start` while locked → exit 1; `start` with a `docs/design/GDD.md` present → exit 1; `end` then `start beta` → OK; `commit-framework.sh` with only a game file changed (`src/game/Foo.lua`) → aborts, nothing committed; with `CLAUDE.md` + a game file changed → commit contains only `CLAUDE.md`; `lead.sh say` with no session → exit 1.
- [ ] **Step 2:** Run → FAIL (scripts missing).
- [ ] **Step 3:** Implement the scripts and profile.
- [ ] **Step 3b: Owner approval.** Show the owner `lead-profile.json` in plain words (what the headless Lead may and may not do); only continue once approved. The trainer never widens it later without a new approval.
- [ ] **Step 4:** Run tests → PASS. Manually: `lead.sh start` with a one-line brief ("Reply OK") returns a session id; `lead.sh say` resumes it.
- [ ] **Step 5: Commit** the five files.

### Task 11: Trainer skills, scenario, run records

**Files:**
- Create: `plugins/roblox-trainer/skills/framework-training/SKILL.md`, `plugins/roblox-trainer/skills/owner-proxy/SKILL.md`, `plugins/roblox-trainer/skills/framework-review/SKILL.md`, `plugins/roblox-trainer/scenarios/like-a-game.md`, `plugins/roblox-trainer/runs/README.md`

**Interfaces:**
- Consumes: Task 10 scripts; Task 8 Owner involvement fields; Task 7 friction log.
- Produces: `framework-training` (triggers: "train the framework", "improve the framework by building games", "start a training session"; steps (in place): `session.sh start` → human step if needed (Studio open on this repo's place, Rojo Connect) → readiness (`make verify`, `list_roblox_studios` shows the expected place else report mismatch, sync probe) → create the GDD's Owner involvement from the scenario → `lead.sh start` with the brief → watch transcript → answer via `owner-proxy` → at each milestone end, with the Lead idle: `framework-review` → propose framework fixes → on approval implement and `commit-framework.sh` → `session.sh milestone` → `lead.sh say` to continue → `session.sh end`). The scenario brief and owner policy are given at session start (a file outside the repo or the maintainer's message), never read from the plugin while the Lead runs.
- Produces: `owner-proxy` (answer only from the scenario policy; uncovered → "your call, mark it `(assumed)`"; listed topics → ask the maintainer; never decide a game question).
- Produces: `framework-review` (inputs: Lead transcript, `FRAMEWORK_FEEDBACK.md`, `git diff <frameworkCommit> -- <framework path list>`, artifacts; output: ranked findings → `runs/<NNN>-<name>.md` with scenario, framework commit, findings, which became changes).
- Produces: `scenarios/like-a-game.md` (brief template "a game like X", owner policy, involvement `milestones`, stop `M1`, always-ask topics: none).
- Not built: the spec's optional `agents/critic.md` (YAGNI; `framework-review` uses a fresh reviewer subagent). Add later if reviews need a dedicated persona.

- [ ] **Step 1 (RED):** Dry run (fresh subagent with `--plugin-dir`, no Studio): "Start a training session with the like-a-game scenario for a game like Grow a Garden." Record whether it starts a session (or refuses because Tiptoe's GDD occupies the tree), asks the human step, refuses to start the Lead without readiness, and never makes a game decision.
- [ ] **Step 2:** Write the skills, scenario and runs README.
- [ ] **Step 3 (GREEN):** Re-run the dry run → all four behaviors; plus a question the policy doesn't cover → answers "your call, mark it `(assumed)`".
- [ ] **Step 4: Commit** the five files.

### Task 12: Whole-branch check

- [ ] **Step 1:** `lune run tests/suite.lua` passes; `make verify` passes with Studio connected; `FrameworkSmokeTest.run()` → OK in Studio.
- [ ] **Step 2:** `git status` shows only the Tiptoe Bandits files (and the ignored ones) as uncommitted; `git log v2 --stat` touches no Tiptoe file.
- [ ] **Step 3:** Fresh reviewer subagent reviews the branch diff against the spec; fix Critical/Important findings, commit.
