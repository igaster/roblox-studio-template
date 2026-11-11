#!/usr/bin/env bash
# Commit framework files only — never game files — in an in-place training tree.
#
#   commit-framework.sh "<message>" [new-file ...]   commit framework changes
#   commit-framework.sh --list                        print the framework path list
#   commit-framework.sh --starters                    print the starter file list
#
# Stages only *tracked* changes under the framework paths (`git add -u`), so untracked game
# files that happen to live in a framework folder (a game plan under docs/superpowers/, a game
# module under src/shared/) are never swept in. A brand-new framework file must be named
# explicitly as an argument; it must lie under a framework path. Refuses if anything else is
# already staged or if nothing framework-owned changed. Commits locally; never pushes.
#
# Starter files are shipped by the template but owned by the game once one exists (the
# working copy holds the game's version). They are never staged automatically: to change the
# template's version, stage it by hand from a separate file, e.g.
#   git update-index --cacheinfo 100644,"$(git hash-object -w <file>)",<starter path>
# A staged deletion of a starter (a rename) is allowed too.

set -euo pipefail

# Single source of truth for "framework files" (the trainer skills use `--list`).
FRAMEWORK_PATHS=(CLAUDE.md README.md .claude .claude-plugin .github plugins scripts src/shared
	src/game/ServerScriptService/FrameworkSmokeTest.lua docs/design/templates
	docs/design/README.md docs/design/references/.gitkeep docs/design/milestones/.gitkeep
	docs/design/features/.gitkeep docs/decisions/README.md docs/superpowers docs/TODO.md Makefile .mcp.json
	default.project.json rokit.toml .gitignore bootstrap.sh bootstrap.bat
	tests/harness.lua tests/framework.lua tests/run.lua tests/lib
	.ledger)

# Template-shipped, game-owned (see above). tests/game.lua and tests/suite.lua are older homes
# of the game's tests, now tests/specs/.
STARTER_PATHS=(tests/specs/ExampleMath.spec.lua tests/game.lua tests/suite.lua
	src/game/ReplicatedStorage/GameConfig.lua
	src/game/ReplicatedStorage/Modules/ExampleMath.lua
	src/game/ServerScriptService/SmokeTest.lua)

if [ "${1:-}" = "--list" ]; then
	printf '%s\n' "${FRAMEWORK_PATHS[@]}"
	exit 0
fi
if [ "${1:-}" = "--starters" ]; then
	printf '%s\n' "${STARTER_PATHS[@]}"
	exit 0
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
MSG="${1:-}"
[ -n "$MSG" ] || { echo "usage: commit-framework.sh \"<message>\" [new-file ...] | --list" >&2; exit 1; }
shift

is_framework() {
	local f="$1" p
	for p in "${FRAMEWORK_PATHS[@]}"; do
		if [ "$f" = "$p" ] || [ "${f#"$p"/}" != "$f" ]; then return 0; fi
	done
	return 1
}

is_starter() {
	local f="$1" p
	for p in "${STARTER_PATHS[@]}"; do [ "$f" = "$p" ] && return 0; done
	return 1
}

while IFS= read -r f; do
	[ -n "$f" ] || continue
	is_framework "$f" || is_starter "$f" || { echo "commit-framework.sh: '$f' is staged but isn't a framework or starter file; unstage it first" >&2; exit 1; }
done < <(git diff --cached --name-only --no-renames)

for f in "$@"; do
	is_framework "$f" || { echo "commit-framework.sh: '$f' isn't under a framework path (see --list)" >&2; exit 1; }
	[ -e "$f" ] || { echo "commit-framework.sh: '$f' doesn't exist" >&2; exit 1; }
done

existing=()
for p in "${FRAMEWORK_PATHS[@]}"; do
	# Only paths with tracked files: `git add -u` errors on a pathspec that matches none.
	if [ -n "$(git ls-files -- "$p" | head -1)" ]; then existing+=("$p"); fi
done
[ "${#existing[@]}" -eq 0 ] || git add -u -- "${existing[@]}"
[ "$#" -eq 0 ] || git add -- "$@"

if git diff --cached --quiet; then
	echo "commit-framework.sh: no framework files changed; nothing committed" >&2
	exit 1
fi

echo "Committing framework files:"
git diff --cached --name-only | sed 's/^/  /'
git commit -q -F - <<EOF
$MSG

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline -1
