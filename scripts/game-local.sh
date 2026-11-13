#!/usr/bin/env bash
# Writes each game's per-clone permissions (.claude/settings.local.json, gitignored), which
# need absolute paths: a game session may edit framework files, but never reads the trainer's
# folder (.training/) or another game. Run after creating or cloning a game (new-game.sh
# runs it). Keeps any other settings already in the file (e.g. MCP approvals).
#
# Usage: scripts/game-local.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$root/games" ] || exit 0
python3 -I - "$root" <<'PY'
import json, os, re, sys
root = sys.argv[1]
games = sorted(g for g in os.listdir(os.path.join(root, "games"))
               if os.path.isdir(os.path.join(root, "games", g)))
for game in games:
    path = os.path.join(root, "games", game, ".claude", "settings.local.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = json.load(open(path)) if os.path.exists(path) else {}
    perms = data.setdefault("permissions", {})
    # Drop the rules this script wrote last time (they name the framework root), then re-add.
    deny = [r for r in perms.get("deny", []) if "/" + root not in r]
    targets = [os.path.join(root, ".training")] + [
        os.path.join(root, "games", other) for other in games if other != game]
    for target in targets:
        for tool in ("Read", "Edit"):
            deny.append(f"{tool}(/{target}/**)")
    perms["deny"] = deny
    # The framework root is outside the game's project folder: without this, every read or
    # edit of a framework file asks first. The deny rules above still win.
    # The game's project folder in the Claude config holds its sessions' tool-results/, where
    # Studio captures land; as a working directory a capture can be cp'd into docs/captures/
    # (an allow rule can't do it: cp's source must be inside a working directory).
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    game_path = os.path.realpath(os.path.join(root, "games", game))
    captures = os.path.join(config, "projects", re.sub(r"[^A-Za-z0-9]", "-", game_path))
    os.makedirs(captures, exist_ok=True)
    ours = (root, captures)
    dirs = [d for d in perms.get("additionalDirectories", [])
            if d not in ours and "/projects/" not in d]  # drop what this script wrote before
    perms["additionalDirectories"] = dirs + list(ours)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
print(f"game-local.sh: wrote permissions for {len(games)} game(s)")
PY
