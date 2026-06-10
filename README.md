# Roblox Studio Template

A minimal project template for Roblox games using [Rojo](https://rojo.space/) for local development with VS Code.

## What's Included

- Rojo 7.6.1 pinned via Rokit
- Game place + Lobby place, each with their own Rojo config
- `src/shared/` for modules used by both places
- `ServerStorage/AssetGenerators/` pattern for programmatic asset creation
- `GameConfig.lua` as a single source of truth for all game settings
- `CLAUDE.md` with project rules for AI-assisted development
- `.gitignore` for Roblox artifacts

## Prerequisites

1. Install [Rokit](https://github.com/rojo-rbx/rokit)
2. Have Roblox Studio installed

## Quick Start

```bash
# 1. Use this template or clone it
gh repo create my-game --template your-org/roblox-studio-template
cd my-game

# 2. Bootstrap (installs Rojo + Studio plugin)
./bootstrap.sh

# 3. Rename the project
#    Edit "name" in default.project.json and lobby.project.json

# 4. Start developing
make serve
# Then open Roblox Studio and connect the Rojo plugin to localhost:34872
```

## Commands

| Command | Description |
|---|---|
| `make serve` | Start Rojo server for the game place |
| `make serve-lobby` | Start Rojo server for the lobby place |
| `make build` | Build game place → `game.rbxl` |
| `make build-lobby` | Build lobby place → `lobby.rbxl` |

## Project Structure

```
src/
├── game/          # Game place scripts
├── lobby/         # Lobby place scripts
└── shared/        # Shared modules (synced into both places)
```

See `CLAUDE.md` for full conventions and architecture guidelines.
