#!/usr/bin/env bash
# Readiness check for working with Studio (macOS). Prints one line per check and exits 0 only if
# all pass. Covers what a shell can see; the Studio MCP side (MCP reachable, the DataModel
# actually synced) is checked by the agent via the roblox-studio-mcp skill.
#
# Usage: scripts/verify.sh        (or: make verify)
#        PORT=34999 scripts/verify.sh

set -u
PORT="${PORT:-34872}"
FAILED=0

ok()   { echo "OK   $1: $2"; }
fail() { echo "FAIL $1: $2"; FAILED=1; }

find_tool() {
	command -v "$1" 2>/dev/null || { [ -x "$HOME/.rokit/bin/$1" ] && echo "$HOME/.rokit/bin/$1"; }
}

for tool in rokit rojo lune; do
	path="$(find_tool "$tool")"
	if [ -n "$path" ]; then ok "$tool" "$path"; else fail "$tool" "not found on PATH or in ~/.rokit/bin (run ./bootstrap.sh)"; fi
done

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | grep -q rojo; then
	ok "rojo serve" "listening on $PORT"
else
	fail "rojo serve" "nothing listening on $PORT (run: make serve)"
fi

if lsof -nP -iTCP:"$PORT" -sTCP:ESTABLISHED 2>/dev/null | grep -q RobloxStu; then
	ok "studio" "Roblox Studio connected to Rojo on $PORT"
else
	fail "studio" "no Studio connection on $PORT (in Studio: Plugins > Rojo > Connect)"
fi

echo "NOTE Studio MCP and DataModel sync are checked by the agent (roblox-studio-mcp skill)."
exit "$FAILED"
