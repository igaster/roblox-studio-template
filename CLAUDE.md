# Claude.md - Project Guidelines

## Project Overview
Roblox game developed with Rojo for local development and live-syncing to Roblox Studio.

## Setup
- Rokit manages the toolchain. Install Rokit first: https://github.com/rojo-rbx/rokit
- Run `./bootstrap.sh` after cloning to install Rojo and the Studio plugin automatically.
- Rojo v7.6.1 is pinned in `rokit.toml`.

> **Claude:** On a fresh clone or first conversation in this project, prompt the user to run `/roblox-initialize` to complete the environment setup.

## Key Commands
- `make serve` - Start Rojo server
- `rojo plugin install` - Install/update the Rojo plugin in Roblox Studio

## Project Structure

```
src/
├── game/                        # Game place
│   ├── ReplicatedStorage/
│   │   ├── GameConfig.lua       # All game configuration
│   │   ├── Classes/             # OOP entities (one file per class)
│   │   └── Modules/             # Utilities
│   ├── ServerScriptService/     # Server-authoritative game logic
│   ├── StarterPlayerScripts/    # Client UI and input
│   └── ServerStorage/
│       └── AssetGenerators/     # Programmatic asset creation scripts
│           ├── GUI/
│           ├── Models/
│           ├── Parts/
│           └── Tools/
└── shared/                      # Modules synced into ReplicatedStorage.Shared
```

### What Rojo Syncs vs. What Studio Owns

**Rojo syncs (source-controlled):** All Lua scripts, configuration, class definitions, module code.

**Studio owns:** 3D models, terrain, placed instances, meshes, animations, sounds, lighting.

The rule: **behavior and logic = code (git)**, **visual/3D assets = Studio**.

### Configuration Files

- **`default.project.json`**: Rojo config — maps `src/` paths to Roblox services.
- **`rokit.toml`**: Rokit toolchain configuration (pins Rojo version).
- **`Makefile`**: Build and serve commands.
- **`bootstrap.sh`**: One-time setup script for fresh clones.

### Asset Generation Pattern

Scripts in `ServerStorage/AssetGenerators/` create game assets programmatically. Run them from Roblox Studio's command bar or Execute panel to generate assets without manual Studio work.

```lua
-- Execute in Roblox command bar:
local gen = require(game.ServerStorage.AssetGenerators.Models.CharacterModelGenerator)
gen.createCharacter().Parent = workspace
```

Assets are organized by type (`GUI/`, `Models/`, `Parts/`, `Tools/`). When Claude generates a new asset type, it should create or update the relevant generator script — never hardcode asset structure in game logic.

## Development Workflow

1. **Setup**: Run `./bootstrap.sh` once after cloning.
2. **Start server**: `make serve`.
3. **Open Studio**: Open the matching place via Asset Manager → Places, then connect the Rojo plugin to `localhost:34872`.
4. **Develop**: Edit Lua files in VS Code → changes sync to Studio automatically → test in Studio's play mode.
5. **Commit**: Commit `src/` changes regularly.

## Key Conventions

- **Model Names = Config Keys**: Entity model names in Studio must exactly match their keys in `GameConfig.lua`.
- **Runtime State in Attributes**: Store dynamic state (Health, MoveSpeed, etc.) using Roblox attributes, not custom properties.
- **Server Authority**: All game logic (combat, spawning, economy) runs server-side. Clients handle only UI and input.
- **File Naming**: Server scripts end with `.server.lua` (→ `Script`), client scripts with `.client.lua` (→ `LocalScript`) for correct Rojo syncing — verify with `rojo sourcemap default.project.json` if unsure.

## Coding Standards

- **Architecture**: Follow SOLID principles. Server-side = authoritative logic. Client-side = UI/input. Shared = utilities and config.
- **Class Design**: Represent all game entities as OOP classes in `Classes/`. No game state inside Roblox models.
- **State Management**: Models are purely visual. Use classes to own all state and behavior.
- **Configuration**: All tunable values go in `GameConfig.lua`. Never hardcode game constants in logic scripts.
- **Code Quality**: Clear names, small focused functions (under 50 lines), consistent formatting, no deep nesting.
- **DRY**: Extract common functionality into reusable modules. Avoid copy-paste.
- **Comments**: Add comments for non-obvious logic, algorithms, or workarounds. Skip comments that just restate what the code does.
- **Error Handling**: Use `warn()` for recoverable issues, `error()` for fatal ones. Handle edge cases to prevent crashes.
- **Performance**: Avoid unnecessary work in frequently called code (e.g., per-frame loops, `Heartbeat`).
- **Commits**: Meaningful messages, commit frequently, focus on `src/` changes.

## Documentation

- Game design docs (GDD, feature specs, lore, milestone notes) live in `docs/design/`.
- `CLAUDE.md` is engineering conventions only; `docs/TESTING.md` is the testing
  checklist only. Game design content never goes in either — new design docs go in
  `docs/design/`, and this file is not the place to record them.

## Testing

Three complementary tiers — headless Lune unit tests, an in-engine smoke test, and a
manual playtest checklist. See the `roblox-test` skill for the full pipeline and how
to run each tier (also invokable manually with `/roblox-test`).

**Workflow rule:** run Tier 1 after every logic change; request Tier 2 when
classes/generators change; keep Tier 3 (`docs/TESTING.md`) updated per milestone.
Never start a new milestone without explicit user confirmation.

## Agent-driven Studio tools

When Studio is open with the Rojo plugin connected, the agent can drive it directly
instead of asking the user to click things — see the `roblox-studio-mcp` skill for
setup/conventions, `roblox-capture` for screenshotting an asset or scene, and
`roblox-playtest` for scripted gameplay verification. All three require a human to
already have Studio open with the place loaded; the agent cannot launch Studio
itself from a cold start.
