# Claude.md - Project Guidelines

## Project Overview
Roblox game developed with Rojo for local development and live-syncing to Roblox Studio.

## Setup
- Rokit manages the toolchain. Install Rokit first: https://github.com/rojo-rbx/rokit
- Run `./bootstrap.sh` after cloning to install Rojo and the Studio plugin automatically.
- Rojo v7.6.1 is pinned in `rokit.toml`.

> **Claude:** On a fresh clone or first conversation in this project, prompt the user to run `/roblox-setup` to complete the environment setup.

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
local gen = require(game.ServerStorage.AssetGenerators.Models.TowerModelGenerator)
gen.createBasicTower().Parent = workspace
```

Assets are organized by type (`GUI/`, `Models/`, `Parts/`, `Tools/`). When Claude generates a new asset type, it should create or update the relevant generator script — never hardcode asset structure in game logic.

## Development Workflow

1. **Setup**: Run `./bootstrap.sh` once after cloning.
2. **Start server**: `make serve`.
3. **Open Studio**: Open the matching place via Asset Manager → Places, then connect the Rojo plugin to `localhost:34872`.
4. **Develop**: Edit Lua files in VS Code → changes sync to Studio automatically → test in Studio's play mode.
5. **Commit**: Commit `src/` changes regularly.

## Key Conventions

- **Model Names = Config Keys**: Tower and enemy model names in Studio must exactly match their keys in `GameConfig.lua`.
- **Runtime State in Attributes**: Store dynamic state (Health, MoveSpeed, Range, etc.) using Roblox attributes, not custom properties.
- **Waypoint Naming**: Number path waypoints in ascending order (`001`, `002`, `003`, ...) for consistent enemy pathing.
- **Server Authority**: All game logic (combat, spawning, economy) runs server-side. Clients handle only UI and input.
- **File Naming**: Server scripts end with `.server.server.lua`, client scripts with `.client.client.lua` for correct Rojo syncing.

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
