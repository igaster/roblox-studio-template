# Claude.md - Project Guidelines

## Project Overview
Roblox game developed with Rojo for local development and live-syncing to Roblox Studio.

## Setup
- Rokit manages the toolchain. Install Rokit first: https://github.com/rojo-rbx/rokit
- Run `./bootstrap.sh` after cloning to install Rojo and the Studio plugin automatically.
- Rojo v7.6.1 is pinned in `rokit.toml`.

## Key Commands
- `make serve` - Start Rojo server for the game place
- `make serve-lobby` - Start Rojo server for the lobby place
- `make build` - Build the game place to `game.rbxl`
- `make build-lobby` - Build the lobby place to `lobby.rbxl`
- `rojo plugin install` - Install/update the Rojo plugin in Roblox Studio

## Project Structure

The project contains two Roblox places in the same game universe, each with its own Rojo config:

| Place | Rojo config | Source directory |
|---|---|---|
| Game | `default.project.json` | `src/game/` |
| Lobby | `lobby.project.json` | `src/lobby/` |

Modules shared by both places live in `src/shared/` and are synced into `ReplicatedStorage.Shared` in both places.

```
src/
├── game/                        # Game place
│   ├── ReplicatedStorage/
│   │   ├── GameConfig.lua       # All game configuration (towers, enemies, waves)
│   │   ├── Classes/             # OOP entities (one file per class)
│   │   └── Modules/             # Game-specific utilities
│   ├── ServerScriptService/     # Server-authoritative game logic
│   ├── StarterPlayerScripts/    # Client UI and input
│   └── ServerStorage/
│       └── AssetGenerators/     # Programmatic asset creation scripts
│           ├── GUI/
│           ├── Models/
│           ├── Parts/
│           └── Tools/
├── lobby/                       # Lobby place
│   ├── ReplicatedStorage/       # Lobby-specific modules
│   ├── ServerScriptService/     # Party and teleport logic
│   └── StarterPlayerScripts/    # Lobby UI
└── shared/                      # Modules used by both places
```

### What Rojo Syncs vs. What Studio Owns

**Rojo syncs (source-controlled):** All Lua scripts, configuration, class definitions, module code.

**Studio owns:** 3D models, terrain, placed instances, meshes, animations, sounds, lighting.

The rule: **behavior and logic = code (git)**, **visual/3D assets = Studio**.

### Configuration Files

- **`default.project.json`**: Rojo config for the game place — maps `src/` paths to Roblox services.
- **`lobby.project.json`**: Rojo config for the lobby place.
- **`rokit.toml`**: Rokit toolchain configuration (pins Rojo version).
- **`Makefile`**: Build and serve commands for both places.
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
2. **Start server**: `make serve` (game) or `make serve-lobby` (lobby).
3. **Open Studio**: Open the matching place via Asset Manager → Places, then connect the Rojo plugin to `localhost:34872`.
4. **Develop**: Edit Lua files in VS Code → changes sync to Studio automatically → test in Studio's play mode.
5. **Commit**: Commit `src/` changes regularly. Ignore `.rbxl` build artifacts.
6. **Build**: `make build` to produce `.rbxl` files for upload to Roblox.

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

## OOP Patterns

Classes use the Lua metatable pattern consistently:

```lua
local MyClass = {}
MyClass.__index = MyClass

function MyClass.new(...)
    local self = setmetatable({}, MyClass)
    -- init
    return self
end
```

- **Private methods** are prefixed with underscore: `function MyClass:_helperMethod()`
- **Static registries** map Roblox models to their Lua instances: `MyClass._registry[model] = self`
- **Lookup**: `MyClass.getFromModel(model)` retrieves the Lua instance for a given model
- **Singletons** use `MyClass._instance`, created via `MyClass.initialize()` (server only), retrieved via `MyClass.get()`
- **File structure**: divide each class file into sections with comment headers:
  ```lua
  -- Constructor
  -- Public Methods
  -- Private Methods
  ```

## Circular Dependency Handling

Use deferred `require()` inside methods (not at the top of the file) to break circular dependencies between classes:

```lua
local Game = nil  -- forward declaration at top

function MyClass:someMethod()
    if not Game then Game = require(script.Parent.Game) end
    -- use Game
end
```

## Client-Server Communication

- **RemoteEvents** live in a `RemoteEvents` folder inside `ReplicatedStorage`. Always use `WaitForChild()` on the client to access them.
- **Server → client** broadcasts use `FireAllClients()`. Wrap in `pcall` for safety:
  ```lua
  pcall(function() myEvent:FireAllClients(...) end)
  ```
- **Server-only initialization** must be gated with `RunService:IsServer()`.
- **Per-frame logic**: use `RunService.Heartbeat` on the server, `RunService.RenderStepped` on the client.
- **Async**: use `task.spawn()` for fire-and-forget work, `task.wait()` for delays, `WaitForChild()` when waiting for instances to load.

## State Replication

- **Scalar game state** (e.g., current score, game phase, speed multiplier) is replicated by storing it in a `StringValue`/`IntValue`/`NumberValue` instance inside `ReplicatedStorage`. Both server and client read from the same Value object — no RemoteEvent needed.
- **Per-object state** (e.g., tower upgrade levels) is replicated via Roblox **Attributes** on the model instance. Use consistent attribute naming, e.g. `Level_<StatName>` and `TowerType`. Clients read attributes directly off the model.

## Logging Convention

Prefix all `print` and `warn` calls with the class or script name in brackets:

```lua
print("[Enemy] Spawned:", self.model.Name)
warn("[Tower] Config not found for:", towerType)
```

## Upgradable Config Stats

Stats that can be upgraded are stored as arrays (one value per level). Non-upgradable stats are scalars:

```lua
TowerName = {
    Cost = 100,                    -- scalar, not upgradable
    Damage = {10, 20, 35},         -- array = upgradable (3 levels)
    FireRate = {1.0, 1.5, 2.0},
    UpgradeCosts = {50, 100},      -- [i] = cost to go from level i → i+1
}
```
