#!/usr/bin/env bash
# Bootstrap a fresh clone of this template.
# Prerequisites: Rokit must already be installed on your machine.
# https://github.com/rojo-rbx/rokit

set -e

echo "==> Installing toolchain (Rojo, Lune) via Rokit..."
rokit install

echo "==> Installing Rojo plugin into Roblox Studio..."
rojo plugin install

echo "==> Verifying headless test setup (Lune)..."
lune run tests/suite.lua

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
echo "  1. Rename the project in default.project.json and lobby.project.json"
echo "  2. Run: make serve"
echo "  3. Open Roblox Studio and connect the Rojo plugin to localhost:34872"
echo "  4. In Studio: Assistant -> ... -> Manage MCP Servers -> enable 'Enable Studio as MCP server'"
