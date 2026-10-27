# Claude.md - Project Guidelines

## Project Overview
Roblox game developed with Rojo for local development and live-syncing to Roblox Studio.

This repo is two things at once: **the game** and **the framework** it was cloned from
(`.claude/`, this file, `docs/TESTING.md`, `docs/design/templates/`, `tests/`,
`src/shared/TestHooks.lua`, tooling files). See "Game vs. Framework Changes" below.

## Setup
- Rokit manages the toolchain. Install Rokit first: https://github.com/rojo-rbx/rokit
- Run `./bootstrap.sh` after cloning to install Rojo and the Studio plugin automatically.
- Rojo and Lune versions are pinned in `rokit.toml` (the source of truth — don't repeat
  version numbers in docs).

> **Claude:** On a fresh clone or first conversation in this project, prompt the user to run `/roblox-initialize` to complete the environment setup.

## Key Commands
- `make serve` - Start Rojo server
- `make test` - Run headless Lune unit tests
- `rojo plugin install` - Install/update the Rojo plugin in Roblox Studio
- `/kickoff` - Start a new game: questions → GDD → first milestone proposal
- `/milestone` - Spec, plan, build, and verify one milestone

## Project Structure

```
src/
├── game/                        # Game place
│   ├── ReplicatedStorage/       # Visible to clients — never put server-only logic here
│   │   ├── GameConfig.lua       # All game configuration
│   │   ├── Classes/             # Shared OOP classes (used by client and server)
│   │   └── Modules/             # Pure utilities and math (Lune-testable)
│   ├── ServerScriptService/     # Server-authoritative game logic
│   │   └── Classes/             # Server-only OOP classes (economy, saving, spawning)
│   ├── StarterPlayerScripts/    # Client UI and input
│   └── ServerStorage/
│       └── AssetGenerators/     # Programmatic asset creation scripts
│           ├── GUI/
│           ├── Models/
│           ├── Parts/
│           └── Tools/
└── shared/                      # Modules synced into ReplicatedStorage.Shared
```

Anything in `ReplicatedStorage` is downloaded by every client and readable by
exploiters. Server-only classes go in `ServerScriptService/Classes/`; only put a class
in `ReplicatedStorage/Classes/` if the client genuinely needs it.

### What Rojo Syncs vs. What Studio Owns

**Rojo syncs (source-controlled):** All Lua scripts, configuration, class definitions, module code.

**Studio owns:** 3D models, terrain, placed instances, meshes, animations, sounds, lighting.

The rule: **behavior and logic = code (git)**, **visual/3D assets = Studio**.

### Configuration Files

- **`default.project.json`**: Rojo config — maps `src/` paths to Roblox services.
- **`rokit.toml`**: Rokit toolchain configuration (pins Rojo and Lune versions).
- **`Makefile`**: Build, serve, and test commands.
- **`bootstrap.sh`**: One-time setup script for fresh clones.

### Asset Generation Pattern

Scripts in `ServerStorage/AssetGenerators/` create game assets programmatically. Run them from Roblox Studio's command bar or Execute panel to generate assets without manual Studio work.

```lua
-- Execute in Roblox command bar:
local gen = require(game.ServerStorage.AssetGenerators.Models.CharacterModelGenerator)
gen.createCharacter().Parent = workspace
```

Assets are organized by type (`GUI/`, `Models/`, `Parts/`, `Tools/`). When Claude generates a new asset type, it should create or update the relevant generator script — never hardcode asset structure in game logic. See the `roblox-asset-generators` skill.

## Development Workflow

Spec-driven: **design → milestone spec → plan → build → verify → retro.** Each step
produces a file, and the user approves the spec before any code is written.

1. **Kickoff** (`/kickoff`, once per game): clarifying questions → `docs/design/GDD.md`
   → first milestone proposal. Stop for approval.
2. **Milestone** (`/milestone`, once per milestone): write
   `docs/design/milestones/M<n>-<slug>.md` from the template, with numbered acceptance
   criteria (`AC1`, `AC2`, …). Stop for approval. Then plan → build → verify each
   criterion → retro.
3. **Decisions**: when a choice is settled (by the user or in a spec review), record it
   in `docs/decisions/`. Don't relitigate a recorded decision unless the user reopens it.
4. **Local loop**: `make serve` → connect the Rojo plugin in Studio to `localhost:34872`
   → edit Lua → changes sync → test in Studio's play mode.
5. **Commit**: commit `src/` changes regularly, keeping framework and game changes in
   separate commits (see below).

Never start a new milestone without explicit user confirmation.

## Game vs. Framework Changes

The framework is improved by building real games with it.

- **Framework commits** touch only framework files and are prefixed `framework:` so
  they can be cherry-picked back to the template unchanged. Keep them game-agnostic:
  no game names or game-specific examples in framework files.
- **Game commits** touch `src/` (except `src/shared/TestHooks.lua`), `docs/design/`
  (except `templates/`), and `docs/decisions/`.
- **Friction log**: whenever the framework gets in the way (a skill was wrong, a
  convention was missing, a step needed a manual workaround), append a dated entry to
  `docs/framework-feedback.md`. Do this when it happens, not from memory later. Review
  the log at each milestone retro and propose framework fixes.

## Key Conventions

- **Model Names = Config Keys**: Entity model names in Studio must exactly match their keys in `GameConfig.lua`.
- **State is owned by classes, mirrored to attributes**: The class instance is the
  source of truth for an entity's state. Any state a tester or another system would
  plausibly need to read live (current phase/round, cash, a value at risk, whether an
  entity is active/occupied, health) is mirrored onto attributes of a well-known
  instance (the `Player`, or the entity's model) whenever it changes. That makes it
  inspectable from outside via `GetAttribute`/`GetAttributes()` with no per-game debug
  code. Never keep such state only in a private table inside a `.server.lua` script,
  and never read game state back *from* a model as if it were the source.
- **Interactable entities get a `CollectionService` tag**: anything a player can walk up to and interact with (enter, pick up, activate, buy) is tagged via `TestHooks.tagInteractable()` when it's created. One line per entity, and it enables generic tooling such as "teleport the player next to the nearest interactable".
- **Server Authority**: All game logic (combat, spawning, economy, purchases) runs server-side. Clients handle only UI and input.
- **File Naming**: Server scripts end with `.server.lua` (→ `Script`), client scripts with `.client.lua` (→ `LocalScript`) for correct Rojo syncing — verify with `rojo sourcemap default.project.json` if unsure.

## Networking (RemoteEvents / RemoteFunctions)

- All remotes live in one `ReplicatedStorage.Remotes` folder, created by the server at
  startup from a single list of names. Never create remotes ad hoc in feature scripts.
- **Treat every client argument as hostile.** Check `typeof()` for each argument, check
  ranges and that referenced instances belong to the calling player, then re-check
  preconditions (owns the plot? can afford it? not already bought?) on the server. The
  client only *requests*; the server decides.
- Clients never send amounts, prices, or results — only intent ("buy item X"). The
  server looks up the price in `GameConfig`.
- Rate-limit remotes a player can spam (per-player cooldown, value in `GameConfig`).
- Prefer `RemoteEvent` over server-invoked `RemoteFunction`: never call
  `InvokeClient`, since a client can hang it forever.

## Persistence (DataStores)

- One server-only module owns all DataStore access; no other script calls
  `DataStoreService` directly.
- Load on `PlayerAdded`, save on `PlayerRemoving` **and** in `game:BindToClose()`, plus a
  periodic autosave (interval in `GameConfig`).
- Wrap every DataStore call in `pcall` with retry and backoff. If a load fails, don't
  let the player play on a blank profile that will overwrite their real save on exit.
  Kick them or mark the session read-only.
- Prefer `UpdateAsync` over `SetAsync`, and store a schema `Version` field in the saved
  data so it can be migrated later.
- Studio needs "Enable Studio Access to API Services" for DataStores to work. Make
  persistence fail soft (`warn()` and continue unsaved) when access is off.

## Coding Standards

- **Architecture**: Follow SOLID principles. Server-side = authoritative logic. Client-side = UI/input. Shared = utilities and config.
- **Class Design**: Represent all game entities as OOP classes (`Classes/` folders above). Models are purely visual.
- **Pure logic is separate**: Formulas (prices, income rates, scaling, progression)
  live in dependency-free `Modules/*Math.lua` modules so they run under Lune. Classes
  delegate to them.
- **Configuration**: All tunable values go in `GameConfig.lua`. Never hardcode game constants in logic scripts.
- **Player lifecycle**: Everything created for a player (plot, connections, state) is
  cleaned up on `PlayerRemoving`. Assume several players per server unless the GDD says
  otherwise.
- **Code Quality**: Clear names, small focused functions (under 50 lines), consistent formatting, no deep nesting. Start new modules with `--!strict` where practical.
- **DRY**: Extract common functionality into reusable modules. Avoid copy-paste.
- **Comments**: Add comments for non-obvious logic, algorithms, or workarounds. Skip comments that just restate what the code does.
- **Error Handling**: Use `warn()` for recoverable issues, `error()` for fatal ones. Handle edge cases to prevent crashes.
- **Performance**: Avoid unnecessary work in frequently called code (e.g., per-frame loops, `Heartbeat`).
- **Commits**: Meaningful messages, commit frequently, focus on `src/` changes.

## Documentation

- `docs/design/`: game design: `GDD.md`, `milestones/`, lore, art direction. Templates
  for these live in `docs/design/templates/` (framework-owned).
- `docs/decisions/`: short decision records (one file per decision).
- `docs/TESTING.md`: Tier 3 testing checklist only.
- `docs/framework-feedback.md`: framework friction log (see above).
- `CLAUDE.md` is engineering conventions only. Game design content never goes here.

## Testing

Three complementary tiers: headless Lune unit tests, an in-engine smoke test, and a
manual playtest checklist. See the `roblox-test` skill for the full pipeline and how
to run each tier (also invokable manually with `/roblox-test`).

**Workflow rule:** run Tier 1 after every logic change; request Tier 2 when
classes/generators change; keep Tier 3 (`docs/TESTING.md`) updated per milestone.
Every milestone acceptance criterion maps to at least one check in one of the tiers.

**Design targets are tests.** When the GDD states a measurable target ("first purchase
within 60 s", "reach business #3 in a 15-minute session"), encode it as a Tier 1
simulation test over the pure `*Math` modules and `GameConfig`. Re-tuning config then
can't silently break the intended pacing.

**Keep the game modelable.** For games with an economy or difficulty curve, keep a
closed-form balance model (`tests/sim/BalanceModel.lua`) next to a step-by-step
simulation (`tests/sim/MatchSim.lua`). Both call the same pure modules as the game, and
a spec checks they agree across several config variants. When a mechanic adds numbers,
it also adds its parameters and terms to the model and to `docs/design/balance-model.md`.
Then "what does +20 % damage do to wave 30?" takes seconds to answer, not a playtest.

## Observability (TestHooks)

`shared/TestHooks.lua` (synced to `ReplicatedStorage.Shared.TestHooks`) gives every
game state dumps, structured events, and teleport-to-entity for live verification, with
no per-game debug code. Two conventions make it work:

1. `TestHooks.tagInteractable(instance)`: once, wherever you create anything a player
   can walk up to and use.
2. `TestHooks.log(category, message, data)`: at meaningful state transitions
   (purchased, collected, phase changed, destroyed). Use it *instead of* a plain
   `print()`/`warn()` for anything a tester would care about. It still prints, and the
   event can be filtered and read back afterward. For high-volume events (one per kill),
   call `TestHooks.setQuiet(category)` once so they're recorded without flooding Output.

Call these from server-side code, and read results back via `execute_luau` on the
**Server** datamodel. The full API and calling patterns are in the `roblox-playtest`
skill.

## Agent-driven Studio tools

When Studio is open with the Rojo plugin connected, the agent can drive it directly
instead of asking the user to click things. See the `roblox-studio-mcp` skill for
setup/conventions, `roblox-capture` for screenshotting an asset or scene, and
`roblox-playtest` for scripted gameplay verification. All three require a human to
already have Studio open with the place loaded; the agent cannot launch Studio
itself from a cold start.
