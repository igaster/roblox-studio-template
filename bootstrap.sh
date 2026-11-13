#!/usr/bin/env bash
# Bootstrap a fresh clone of the framework (games are created afterwards with make new-game).
# Prerequisites: Rokit must already be installed on your machine.
# https://github.com/rojo-rbx/rokit

set -e

echo "==> Installing toolchain (Rojo, Lune) via Rokit..."
rokit install

echo "==> Installing Rojo plugin into Roblox Studio..."
rojo plugin install

echo "==> Checking Lune..."
lune --version

echo "==> Registering the Roblox Studio MCP server with Claude Code..."
MCP_COMMAND="/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
if command -v claude >/dev/null 2>&1; then
    if claude mcp get Roblox_Studio >/dev/null 2>&1; then
        echo "    Already registered."
    elif claude mcp add Roblox_Studio -- "$MCP_COMMAND"; then
        echo "    Registered."
    else
        echo "    WARN: registration failed; add manually (see roblox-studio-mcp skill)."
    fi
else
    echo "    WARN: 'claude' CLI not found on PATH; skipping. Install Claude Code, then run:"
    echo "      claude mcp add Roblox_Studio -- $MCP_COMMAND"
fi

echo ""
echo "Done. Next steps:"
echo "  1. Create your first game: make new-game NAME=<kebab-case-name>, then cd games/<name>"
echo "  2. In the game folder: make serve (and make claude to work on it with Claude Code)"
echo "  3. Open Roblox Studio and connect the Rojo plugin to localhost:34872"
echo "  4. In Studio: Assistant -> ... -> Manage MCP Servers -> enable 'Enable Studio as MCP server'"
