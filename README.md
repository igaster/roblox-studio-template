# Roblox Studio Template

A project template for building Roblox games with [Claude Code](https://claude.com/claude-code):
source in git, live-synced into Studio with [Rojo](https://rojo.space/), and a set of
conventions, shared modules and skills that let an agent design, build and test a game, from a
one-line idea to a milestone at a time.

## What's included

- **Toolchain:** Rojo and Lune, pinned with Rokit (`rokit.toml`).
- **One entry point per side:** `Main.server.lua` starts `ServerScriptService/Services/`,
  `Main.client.lua` starts `StarterPlayerScripts/Controllers/` (two-phase `init()`/`start()`).
- **Shared framework modules** (`src/shared/` → `ReplicatedStorage.Shared`):

  | Module | Purpose |
  |---|---|
  | `ServiceLoader` | Discovers and starts services/controllers |
  | `Remotes` | The single place RemoteEvents/RemoteFunctions are created and fetched |
  | `ConfigTypes` | Converts plain-Lua `GameConfig` values to Vector3/Color3/UDim2/Enum |
  | `Greybox` | Part helpers for prototype level generators |
  | `TestHooks` | Structured event log, state dump, teleport, Studio-only test commands |
  | `TestAudio` | Studio-only mute for agent test runs |

- **`GameConfig.lua`:** every tunable value, plain Lua only, so it loads headlessly.
- **Asset generators** (`ServerStorage/AssetGenerators/`): models, parts, tools, GUIs and
  greybox levels built by code.
- **Three test tiers:** headless Lune unit tests (`make test`, also in CI), an in-engine smoke
  test, and a playtest checklist (`docs/TESTING.md`).
- **Design docs:** `docs/design/templates/` for a GDD, milestones, feature specs and reference
  teardowns; the game's own docs go next to them in `docs/design/`.
- **Claude Code setup:** `CLAUDE.md` (conventions), skills in `.claude/skills/`, a
  `game-developer` agent, and `.mcp.json` with the Roblox Studio MCP server and
  [context7](https://context7.com) for current Roblox docs.

## Skills

| Skill | Use it for |
|---|---|
| `roblox-initialize` | First-time setup of a fresh clone |
| `roblox-game-design` | A new game idea, a feature, tuning, monetization |
| `roblox-game-modeling` | Optional: a simulation or balance model of the game's numbers |
| `roblox-game-teardown` | Studying an existing game named as inspiration |
| `roblox-lead` | Designing and building whole milestones with little involvement from you |
| `roblox-asset-generators` | Models, tools, parts, levels and GUIs built by code |
| `roblox-test` | Running and writing tests, milestone checks |
| `roblox-studio-mcp` | Driving Studio from the agent (run code, Play, read the console) |
| `roblox-playtest` | Verifying gameplay in a scripted Play session |
| `roblox-capture` | Screenshotting an asset or a scene |

## Prerequisites

1. [Rokit](https://github.com/rojo-rbx/rokit)
2. Roblox Studio
3. [Claude Code](https://claude.com/claude-code) (optional, but the template is built for it)

## Quick start

```bash
# 1. Create a repo from this template
gh repo create my-game --template igaster/roblox-studio-template --clone
cd my-game

# 2. Bootstrap: installs Rojo + Lune and the Studio plugin, runs the headless tests,
#    registers the Studio MCP server with Claude Code
./bootstrap.sh          # macOS/Linux
bootstrap.bat           # Windows

# 3. Rename the project: "name" in default.project.json

# 4. Start syncing
make serve
```

Then in Studio: open your place, connect the Rojo plugin to `localhost:34872`, and turn on
**Enable Studio as MCP server** (Assistant → Manage MCP Servers). `make verify` checks the
setup. In Claude Code, `/roblox-initialize` walks through the same steps.

Then describe the game you want, e.g. "a game like X, but ...", and the design skill takes it
from there.

## Commands

| Command | Description |
|---|---|
| `make serve` | Start the Rojo server |
| `make test` | Run the headless Lune tests (skips slow specs) |
| `make test-all` | Run every Lune test, including slow simulation specs |
| `make verify` | Check the toolchain, Rojo server and Studio connection (macOS) |
| `make balance` | Run the game's balance report against its baseline, if it has one (`tests/sim/eval.lua`) |
| `/kickoff <idea>` | (Claude Code) start a new game through the design pipeline |
| `/milestone <M2>` | (Claude Code) spec, plan, build and verify one milestone |

## Project structure

```
src/
├── game/                      # The game: GameConfig, Classes/, Modules/, Services/ (server),
│                              # Controllers/ (client), AssetGenerators/, SmokeTest
└── shared/                    # Framework modules → ReplicatedStorage.Shared
tests/                         # run.lua (entry), framework.lua, harness.lua; specs/ (the game's)
docs/design/                   # Templates; the game's GDD, milestones and specs
docs/decisions/                # The game's decision records (one file each)
plugins/roblox-trainer/        # Optional, off by default: see below
```

See `CLAUDE.md` for the full conventions.

## Improving the framework (optional)

`plugins/roblox-trainer/` is a Claude Code plugin for the template's maintainers: it plays a
game owner, has a game built through the framework, reviews each milestone and proposes
framework fixes. It is off by default and not needed to make a game; see its
[README](plugins/roblox-trainer/README.md). Its records stay local in `.ledger/`.
