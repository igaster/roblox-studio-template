---
name: roblox-initialize
description: Use on a fresh clone of this project, when a user asks to set up or initialize the dev environment, or when invoked directly as /roblox-initialize. Runs the bootstrap script and walks through the manual Studio steps it can't automate.
---

# Roblox Project Initialization

One-time environment setup for a fresh clone. Root `CLAUDE.md` prompts for this on
the first conversation in the project — don't wait to be asked a second time.

## Steps

1. **Prerequisite check:** confirm [Rokit](https://github.com/rojo-rbx/rokit) is
   installed (`rokit --version`). If missing, point the user to the install docs —
   this can't be scripted around.
2. **Run the bootstrap script** for the user's platform from the repo root:
   - macOS/Linux: `./bootstrap.sh`
   - Windows: `bootstrap.bat`

   This installs Rojo/Lune via Rokit, installs the Rojo Studio plugin, runs the
   Tier 1 test suite, and best-effort registers the Roblox Studio MCP server with
   the `claude` CLI (skipped with a warning if `claude` isn't on PATH — not fatal).
3. **Manual Studio steps** (GUI-only, same precondition as `roblox-studio-mcp` —
   the agent cannot do these from a cold start):
   - Open Roblox Studio, open the project's place.
   - Run `make serve`, then connect the Rojo plugin toolbar to `localhost:34872`.
   - Assistant → "… ⟩ Manage MCP Servers" → toggle "Enable Studio as MCP server".
4. **Rename placeholders:** update the project name in `default.project.json` and
   `lobby.project.json`.
5. **Verify:** confirm Rojo shows connected in Studio. Optionally verify MCP via
   `roblox-studio-mcp`'s trivial `execute_luau` call.

## After setup

Once this is done, `roblox-test`, `roblox-asset-generators`, `roblox-capture`, and
`roblox-playtest` all become usable — they all assume Studio is open and connected.
