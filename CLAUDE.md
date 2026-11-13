# Claude.md - Project Guidelines

## Project Overview
A framework for building Roblox games with Rojo (local development, live-synced to Roblox
Studio). Each game lives in its own folder, `games/<name>/`, which is its own git repo; the
framework is this repo's root and is shared by every game.

## Setup
- Rokit manages the toolchain. Install Rokit first: https://github.com/rojo-rbx/rokit
- Run `./bootstrap.sh` after cloning to install Rojo and the Studio plugin automatically.
- Tool versions (Rojo, Lune) are pinned in `rokit.toml`, the single source of truth. Don't restate version numbers elsewhere.
- `make new-game NAME=<kebab-case>` creates `games/<name>/` from `template/`. After cloning a
  game into `games/`, run `scripts/game-local.sh` (per-clone permissions).

> **Claude:** If the toolchain looks missing (`make verify` fails on rokit/rojo/lune), suggest
> running `/roblox-initialize`. Don't prompt for it on an already set-up clone.

## Key Commands
Run from the game folder (`games/<name>/`):
- `make claude` - Start Claude Code in this game with the framework loaded
- `make serve` - Start Rojo server for this game
- `make test` / `make test-all` / `make balance` / `make verify`
- `rojo plugin install` - Install/update the Rojo plugin in Roblox Studio

## Framework root and game root

A session working on a game runs in the game folder: **every path in this file and in the
skills is relative to the game root** (`src/game/…`, `docs/STATUS.md`, `tests/specs/`), unless
it is marked as a framework path. Framework files are at `../../` from a game:

```
<framework root>/                # this repo: the framework only
├── CLAUDE.md                    # these conventions (loads automatically in every game)
├── plugins/roblox-framework/    # skills, agents, commands, hooks (loaded by `make claude`)
├── src/shared/                  # framework Luau modules → ReplicatedStorage.Shared
├── src/framework/               # FrameworkSmokeTest (→ ServerScriptService)
├── tests/                       # runner.lua, harness.lua, framework.lua, lib/ (balance toolkit)
├── docs/design/templates/       # templates for the game's docs (read in place, never edited)
├── template/                    # the starter game, only ever copied by new-game
├── scripts/                     # verify.sh, new-game.sh, game-local.sh, framework.mk
└── games/<name>/                # one folder per game, each its own git repo (below)
```

A game session may edit framework files when the framework needs a fix. Keep such edits
game-agnostic and commit them in the framework repo, never together with game changes
(see *Framework friction*).

## Project Structure (a game folder)

```
games/<name>/
├── CLAUDE.md                    # this game's engineering notes (loads with this file)
├── FRAMEWORK_FEEDBACK.md        # framework friction log (see *Framework friction*)
├── .local/scratch/              # throwaway scripts (gitignored); docs never depend on them
├── game.json                    # name, title, placeId, universeId, framework commit
├── default.project.json         # Rojo: this game's src/ + the framework's src/shared
├── Makefile                     # includes ../../scripts/framework.mk
├── .luaurc                      # `@framework` alias → ../.. (framework Lua libraries)
├── docs/                        # STATUS, TESTING, design/, decisions/, captures/
├── tests/run.lua, tests/specs/, tests/sim/
└── src/game/                    # Game place
    ├── ReplicatedStorage/       # Downloaded by every client: no server-only logic here
    │   ├── GameConfig.lua       # All game configuration
    │   ├── Classes/             # Shared OOP classes (used by client and server)
    │   └── Modules/             # Pure utilities and *Math formulas (Lune-testable)
    ├── ServerScriptService/
    │   ├── Main.server.lua      # The only server Script: starts Services/
    │   ├── Services/            # Server game logic, one ModuleScript per system
    │   ├── Classes/             # Server-only OOP classes (economy, saving, spawning)
    │   └── SmokeTest.lua        # Tier 2 test (ModuleScript, never auto-runs)
    ├── StarterPlayerScripts/
    │   ├── Main.client.lua      # The only LocalScript: starts Controllers/
    │   └── Controllers/         # Client UI and input, one ModuleScript per concern
    └── ServerStorage/
        └── AssetGenerators/     # Programmatic asset creation scripts
            ├── GUI/
            ├── Models/
            ├── Parts/
            └── Tools/
```

The framework's modules (TestHooks, TestAudio, Remotes, ServiceLoader, ConfigTypes, Greybox,
SessionRecorder, ServerBridge, LayoutCheck, LayoutMath) are in the framework's `src/shared/`
and appear in Studio as `ReplicatedStorage.Shared`; `shared/X.lua` below means that folder.
Game modules go in `ReplicatedStorage/Modules/`.

Anything in `ReplicatedStorage` is readable by exploiters. A class goes in
`ReplicatedStorage/Classes/` only if the client needs it; otherwise in
`ServerScriptService/Classes/`.

### Code Organization

- **One entry point per side.** `Main.server.lua` and `Main.client.lua` are the only
  scripts that run on their own. Don't add more `.server.lua`/`.client.lua` files; add a
  service or controller instead. Startup order is then explicit and debuggable.
- **Services** (`ServerScriptService/Services/<Name>Service.lua`) and **controllers**
  (`StarterPlayerScripts/Controllers/<Name>Controller.lua`) are ModuleScripts with
  optional `init()` and `start()`. `shared/ServiceLoader.lua` runs every module's
  `init()` (synchronous setup, must not yield), then every `start()` (each in its own
  thread). Services may `require` each other directly.
- **Services orchestrate, classes own entities.** A service wires players and events
  to `Classes/` instances; entity state and behavior stay in the class.

### Networking

- All RemoteEvents/RemoteFunctions go through `shared/Remotes.lua` and live in
  `ReplicatedStorage.Remotes`. Never create remotes ad hoc elsewhere.
- **The server creates remotes in a service's `init()`** (`Remotes.event("Name")`);
  clients fetch them the same way and wait for them.
- Name remotes after the player's intent (`RequestUpgrade`, `RequestPickUp`), not the
  effect.
- **The server validates every argument**: `typeof` checks, ranges, ownership,
  cooldowns. It never trusts a client-sent value for state the server owns. A rejected
  request returns or warns, never errors.
- **Clients send intent only** ("buy item X"), never amounts, prices or results: the server
  looks them up in `GameConfig`. Rate-limit what a player can spam (a per-player cooldown,
  its value in `GameConfig`).
- Prefer `RemoteEvent`s. Never call `InvokeClient`: a client can make it hang forever.
- **Client-simulated characters.** The client moves its own character, so the server sees it
  a few frames late: give state checks a short grace window, measure heights from the root
  part (it stands ~3 studs up), and raycast rather than trust `Humanoid.FloorMaterial`.
  Validate outcomes (distance over time, being in the zone) before paying a reward. A state
  that benefits the player (silent, invulnerable, faster) is ended by the server, never left
  for the client to end.

### Persistence (DataStores)

- One server-only module owns all DataStore access; nothing else calls `DataStoreService`.
- Load on `PlayerAdded`; save on `PlayerRemoving`, in `game:BindToClose()`, and on a periodic
  autosave (interval in `GameConfig`).
- Wrap every DataStore call in `pcall` with retry and backoff. A player whose load failed
  never plays on a blank profile that would overwrite their real save on exit: kick them,
  or mark the session read-only. Never pay a reward into a profile that isn't loaded.
- Use `UpdateAsync` rather than `SetAsync`, and store a schema `Version` so saved data can be
  migrated.
- Studio needs "Enable Studio Access to API Services" for DataStores. Without it,
  persistence fails soft (`warn()` and play unsaved). The owner module takes its store as a
  parameter, so Lune tests pass in a small in-memory stand-in.

### What Rojo Syncs vs. What Studio Owns

**Rojo syncs (source-controlled):** All Lua scripts, configuration, class definitions, module code.

**Studio owns:** 3D models, terrain, placed instances, meshes, animations, sounds, lighting.

The rule: **behavior and logic = code (git)**, **visual/3D assets = Studio**.

- **Prototype (greybox) levels and lighting may be built by code**: a level generator builds the
  level (and sets `Lighting`) at every server start (see `roblox-asset-generators`, *Level
  generators*; `shared/Greybox.lua` has part helpers). Once real art and lighting are set up
  in Studio, retire the generator and the place file owns them.
- **Third-party asset ids** (Creator Store sounds, meshes, decals) live in `GameConfig`, come
  from licensed or verified sources, and are checked to load in a Play session; see
  `roblox-asset-generators`, *Third-party assets*.
- **Always rebuild, never "skip if it exists".** Anything code puts in Workspace can be saved
  into the place file; a "build only if missing" check then keeps serving that stale copy
  after the generator is fixed. Decide this when *planning* a task, not only when building it.

### Configuration Files

- **`default.project.json`** (game): Rojo config — maps the game's `src/` and the framework's
  `../../src/shared` to Roblox services.
- **`game.json`** (game): the game's name, title, place and universe ids, framework commit.
- **`Makefile`** (game): build and serve commands, from `../../scripts/framework.mk`.
- **`rokit.toml`** (framework): Rokit toolchain configuration (pins Rojo and Lune versions).
- **`bootstrap.sh`** (framework): one-time setup script for a fresh clone of the framework.

### Asset Generation Pattern

Visual content (models, tools, parts, levels, UI) is built by generator modules in
`ServerStorage/AssetGenerators/{GUI,Models,Parts,Tools}/`, never inline in game logic. The
`roblox-asset-generators` skill has the patterns (reusable asset, level, GUI).

## Skills to load

Skills hold the detailed procedures. Load the one that matches the work **before** you start
it, including mid-build, when a plan task names it:

| Work | Skill |
|---|---|
| A model, tool, part, level or GUI (anything under `AssetGenerators/`) | `roblox-asset-generators` |
| Running tests, writing Tier 1/2 tests, a milestone's checks | `roblox-test` |
| Anything through the Studio MCP (`execute_luau`, Play, console) | `roblox-studio-mcp` |
| Verifying gameplay in a Play session | `roblox-playtest` |
| Looking at an asset or scene | `roblox-capture` |
| A new game, a large feature, tuning, monetization | `roblox-game-design` |
| A simulation or balance model of the game's numbers (optional) | `roblox-game-modeling` |

## Development Workflow

1. **Setup**: Run `./bootstrap.sh` once after cloning the framework; `make new-game NAME=<name>`
   for a new game (or clone a game into `games/` and run `scripts/game-local.sh`).
2. **Start server**: `make serve` in the game folder (one game's Rojo server at a time).
3. **Open Studio**: Open the matching place via Asset Manager → Places, then connect the Rojo plugin to `localhost:34872`.
4. **Develop**: Edit Lua files in VS Code → changes sync to Studio automatically → test in Studio's play mode.
5. **Commit**: only when the user asks; never push unless asked. Game changes go in the game's
   repo, framework changes in the framework repo.

### Working economically

Every step of a chat re-sends everything the chat has done so far, so a step costs more the
longer the chat runs, and usage limits run out fast.
- **Fewer steps:** batch related edits into one, make independent tool calls in parallel,
  and filter long command output (`tail`, `grep`) before it lands in the chat.
- **One sweep, one table:** for tuning, write one script that runs the variants and prints a
  compact table, rather than many separate runs.
- **Cheapest tool first:** answer number questions (balance, pacing, economy) with the
  simulation or model and Tier 1. Use Studio only for what they can't show (UI, replication,
  saves, real code paths), and verify there once per checkpoint rather than after every change.
- **Start a new chat at a boundary:** after a checkpoint or milestone, once `docs/STATUS.md`
  and the plan's boxes are current, a new chat continues from the repo for a fraction of the
  cost.

## Key Conventions

- **Model Names = Config Keys**: Entity model names in Studio must exactly match their keys in `GameConfig.lua`.
- **Runtime State in Attributes**: Store dynamic state (Health, MoveSpeed, etc.) using Roblox attributes, not custom properties. This isn't just a style rule — it's what makes state generically inspectable from outside the script that owns it (via `GetAttribute`/`GetAttributes()`), with no per-game debug code required. Any state a tester or another system would plausibly need to read live (current phase/round, a value at risk, whether an entity is active/occupied, health) belongs in an attribute on a well-known instance (the `Player`, or the entity itself) — not buried in a private table inside a script, which is invisible from outside it. An end state clients must see (killed, collected): set it, then remove the instance a few frames later (`Debris`), or fire an event; a change made just before `Destroy()` may never replicate.
- **Interactable entities get a `CollectionService` tag**: anything a player can walk up to and interact with (enter, pick up, activate) should be tagged (e.g. `"Interactable"`) via `CollectionService:AddTag()` when it's created. This costs one line per entity and enables generic tooling — e.g. "teleport the player next to the nearest tagged interactable" — that works across any game without game-specific glue, since it doesn't need to know what the entity actually is.
- **Server Authority**: All game logic (combat, spawning, economy) runs server-side. Clients handle only UI and input.
- **File Naming**: `.server.lua` → `Script`, `.client.lua` → `LocalScript`, plain `.lua` → `ModuleScript` — verify with `rojo sourcemap default.project.json` if unsure. Only the two `Main` entry points use the script suffixes (see *Code Organization*).

## Coding Standards

- **Architecture**: Follow SOLID principles. Server-side = authoritative logic. Client-side = UI/input. Shared = utilities and config.
- **Class Design**: Represent all game entities as OOP classes (the `Classes/` folders
  above). Classes own state and behavior; models are visual. State others need to read is
  mirrored into attributes (see *Runtime State in Attributes*), not kept in model properties
  or scripts. Formulas (prices, rates, scaling) live in dependency-free `Modules/*Math.lua`
  that classes call, so they run under Lune.
- **Player lifecycle**: everything made for a player (a plot, connections, state) is
  cleaned up on `PlayerRemoving`. Assume several players per server unless the GDD says
  otherwise.
- **Configuration**: All tunable values go in `GameConfig.lua`. Never hardcode game constants in logic scripts.
  `GameConfig` holds **plain Lua values only** (numbers, strings, booleans, tables), never
  `Vector3`/`Color3`/`UDim2`/`CFrame`/`Enum`, so it loads under Lune and Tier 1 tests can use
  real config values. Store engine types as tables (`{ X = 1, Y = 4, Z = 1 }`,
  `{ R = 255, G = 200, B = 0 }`, `"Neon"`) and convert at the point of use with
  `shared/ConfigTypes.lua`. The framework's `../../tests/framework.lua` fails if this rule is
  broken.
- **Editing files**: change files with the Edit tool (several Edit calls are fine) and create
  them with Write. Don't splice code with Python, `sed` or heredoc scripts: an anchor that
  matches twice, or misses on whitespace, silently edits the wrong place, and the shell guard
  refuses many such commands. Throwaway scripts (a sweep, a probe) go in the game's
  `.local/scratch/`, not `/tmp`; a script the docs or tests rely on goes in `tests/sim/`.
- **Code Quality**: Clear names, small focused functions (under 50 lines), consistent formatting, no deep nesting. Start new modules with `--!strict` where practical.
- **DRY**: Extract common functionality into reusable modules. Avoid copy-paste.
- **Comments**: Add comments for non-obvious logic, algorithms, or workarounds. Skip comments that just restate what the code does.
- **Error Handling**: Use `warn()` for recoverable issues, `error()` for fatal ones. Handle edge cases to prevent crashes.
- **Performance**: Avoid unnecessary work in frequently called code (e.g., per-frame loops, `Heartbeat`).
- **Commits**: only when the user asks, with meaningful messages; never push unless asked.

## Documentation

- Game design docs (GDD, feature specs, lore, milestone notes) live in `docs/design/`.
- For new game ideas, open-ended feature proposals, tuning without a target value, or
  monetization, use the `roblox-game-design` skill before planning code.
- **Just do it** (no design process) when the request is concrete: an explicit value ("jump
  power 60"), a typo, a bug fix, or a small feature inside the current milestone's scope.
  Put new numbers in `GameConfig`, run the tests, done.
- Settled decisions go in `docs/decisions/`, one file each (see its README). Don't
  relitigate a recorded decision unless the creator reopens it.
- `CLAUDE.md` is engineering conventions only; `docs/TESTING.md` is the testing
  checklist only. Game design content never goes in either — new design docs go in
  `docs/design/`, and this file is not the place to record them.
- **The docs are the handoff between chats**: a new chat must be able to continue from the
  repo alone. At the start of work, read `docs/STATUS.md` (create it from
  `../../docs/design/templates/status.md` if missing). Before ending a turn that changed
  something, update it and the affected docs: what was decided, built or found, and what
  waits on the creator. Fix a stale doc when you notice it; finished milestone files are a
  historical record, so note renames in `STATUS.md` instead.
- **A new chat that reads `STATUS.md` cleans it up before acting on it.** A turn can end
  early (a usage limit, a crash), so the page may describe a state that's already past. A
  session-start hook says when files changed after the page was written. Check *Where we
  are* against the plan's checkboxes and the code, then rewrite the page to what you
  confirmed: delete claims you can't confirm, and set *Last updated*. Only then start other
  work. A stale page left in place anchors the next chat too.
- **Keep it current while building, not only at the end of a turn:** update `STATUS.md`
  when a plan is approved and at each checkpoint. Tick a plan task's boxes when the task is
  done, and tick a box only for work that exists (a capture's box once the file is in
  `docs/captures/`).

## API Docs (context7)

The project's `.mcp.json` registers the [context7](https://context7.com) MCP server,
which serves current Roblox, Rojo and Luau docs on demand. **Before using a Roblox
API you're not certain of** (a service, an event's firing conditions, replication or
thread-safety behavior), look it up rather than relying on memory — Roblox APIs get
deprecated and replaced, and the reference pages carry warnings that matter
(replication, security context, thread safety).

Call `query-docs` directly with these IDs — no need to `resolve-library-id` first:

| Topic | context7 ID |
|---|---|
| Engine API reference (classes, events, properties, enums) | `/websites/create_roblox_reference_engine` |
| Guides and tutorials (scripting patterns, data stores, Open Cloud) | `/roblox/creator-docs` |
| Rojo (project files, sync rules) | `/websites/rojo_space_v7` |
| Luau language server (types, sourcemaps) | `/johnnymorganz/luau-lsp` |

Keep queries to one concept each (e.g. "RemoteEvent OnServerEvent rate limiting",
not "networking"). If context7 is unavailable (offline, rate-limited), say so
rather than guessing at API behavior.

## Testing

Three complementary tiers — headless Lune unit tests, an in-engine smoke test, and a
manual playtest checklist. See the `roblox-test` skill for the full pipeline and how
to run each tier (also invokable manually with `/roblox-test`).

**Workflow rule:** run Tier 1 after every logic change; request Tier 2 when
classes/generators change, batched once per checkpoint or before a report (not after each edit); keep Tier 3 (`docs/TESTING.md`) updated per milestone.
Every acceptance criterion and design target maps to at least one check, named by its ID
(`DT1`, `M1-AC2`). Never start a new milestone without explicit user confirmation, unless the GDD's
*Owner involvement* setting pre-approves it (see `roblox-lead`).

## Observability (TestHooks)

`shared/TestHooks.lua` (synced to `ReplicatedStorage.Shared.TestHooks`) gives every game
state dumps, structured events, teleport-to-entity and Studio-only test commands for live
verification, with no per-game debug code. `require()` it in server-side services and
classes (not in pure `*Math` modules, which must stay Lune-testable). Two conventions make
it work:

1. `TestHooks.tagInteractable(instance)`: once, wherever you create anything a player can
   walk up to and enter/use/collect (a vehicle, a chest, an NPC).
2. `TestHooks.log(category, message, data)`: at meaningful state transitions (destroyed,
   collected, phase changed, scored). Use it *instead of* a plain `warn()`/`print()` for
   anything a tester would care about: it still prints, and the event can be filtered and
   read back afterwards, as ground truth instead of guesswork. For high-volume events (one
   per kill), call `TestHooks.setQuiet(category)` once so they're recorded without flooding
   Output.

When a test needs state only a service owns (currency, timers, saves), register a
Studio-only command in that service's `init()` (`TestHooks.registerCommand`) instead of a
debug remote. Call these from server-side code, and read results back via `execute_luau`
on the **Server** datamodel. The full API and calling patterns, including the attribute
route that works when MCP code is sandboxed, are in the `roblox-playtest` skill.

`shared/SessionRecorder.lua` complements it for play sessions: it records the players'
decisions and per-round milestones so a session can be analysed afterwards (see
`roblox-playtest`, *Recording sessions*).

## Framework friction

This game is built on a framework (everything at `../../` except `games/`): `CLAUDE.md`, the
skills in `plugins/roblox-framework/`, `docs/design/templates/`, `template/`, the shared
modules in `src/shared/` and the test runner in `tests/`. When the framework is missing
something you needed, is unclear, gives wrong or outdated guidance, or gets in your way,
append one entry to `FRAMEWORK_FEEDBACK.md` at the game root (tracked with the game) and
carry on.
Don't go looking for problems; log friction when you actually hit it.

```markdown
## <short title>
- **When:** what you were doing
- **Framework said / lacked:** the file or skill involved, and what was missing or wrong
- **Workaround:** what you did instead
- **Suggestion:** (optional) how the framework could fix it
```

A fix to the framework itself is committed in the framework repo (the root, not the game's
repo), touching only framework files, game-agnostic (no game names or game-specific
examples), with its message prefixed `framework:`.

## Agent-driven Studio tools

When Studio is open with the Rojo plugin connected, the agent can drive it directly
instead of asking the user to click things — see the `roblox-studio-mcp` skill for
setup/conventions, `roblox-capture` for screenshotting an asset or scene, and
`roblox-playtest` for scripted gameplay verification. All three require a human to
already have Studio open with the place loaded; the agent cannot launch Studio
itself from a cold start.
