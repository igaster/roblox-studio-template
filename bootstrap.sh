#!/usr/bin/env bash
# Bootstrap a fresh clone of this template.
# Prerequisites: Rokit must already be installed on your machine.
# https://github.com/rojo-rbx/rokit

set -e

echo "==> Installing toolchain (Rojo) via Rokit..."
rokit install

echo "==> Installing Rojo plugin into Roblox Studio..."
rojo plugin install

echo ""
echo "Done. Next steps:"
echo "  1. Rename the project in default.project.json and lobby.project.json"
echo "  2. Run: make serve"
echo "  3. Open Roblox Studio and connect the Rojo plugin to localhost:34872"
