#!/usr/bin/env bash
# Start a new game: copy template/ into games/<name>/ and make that folder its own git repo
# (nothing committed). The template is only ever copied, never edited in place.
#
# Usage: scripts/new-game.sh <name>      (or: make new-game NAME=<name>)
#        <name> is kebab-case, e.g. clockwork-keep
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:-}"
if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
	echo "usage: new-game.sh <kebab-case-name>" >&2
	exit 1
fi
dest="$root/games/$name"
if [ -e "$dest" ]; then
	echo "new-game.sh: games/$name already exists" >&2
	exit 1
fi

mkdir -p "$root/games"
cp -R "$root/template" "$dest"
commit="$(git -C "$root" rev-parse HEAD)"
sed -i '' -e "s/__NAME__/$name/" -e "s/__COMMIT__/$commit/" "$dest/game.json" 2>/dev/null ||
	sed -i -e "s/__NAME__/$name/" -e "s/__COMMIT__/$commit/" "$dest/game.json"
git -C "$dest" init -q
bash "$root/scripts/game-local.sh"

echo "Created games/$name (its own git repo, nothing committed)."
echo "Next: cd games/$name && make claude"
