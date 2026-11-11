#!/usr/bin/env bash
# How much framework text agents read: the budget framework-harvest checks before and after.
#   context-budget.sh            table: CLAUDE.md, each project skill's SKILL.md, totals
#   context-budget.sh --total    one line: always-loaded and all-skills token estimates
# "Always loaded" = CLAUDE.md + every skill's description (the listing each session sees).
# Tokens are estimated as characters / 4.

set -euo pipefail
ROOT="${BUDGET_ROOT:-$(git rev-parse --show-toplevel)}"
cd "$ROOT"

tokens() { echo $(( $(wc -c < "$1") / 4 )); }
desc_tokens() { echo $(( $(sed -n 's/^description: //p' "$1" | wc -c) / 4 )); }

claude_tokens="$(tokens CLAUDE.md)"
always="$claude_tokens"
skills=0
rows=""
for f in .claude/skills/*/SKILL.md; do
	[ -e "$f" ] || continue
	t="$(tokens "$f")"
	skills=$((skills + t))
	always=$((always + $(desc_tokens "$f")))
	rows+="$(printf '| %s | %s | %s |' "$(basename "$(dirname "$f")")" "$(wc -l < "$f" | tr -d ' ')" "$t")"$'\n'
done

if [ "${1:-}" = "--total" ]; then
	echo "always-loaded ~${always} tokens · all skill bodies ~${skills} tokens · CLAUDE.md $(wc -l < CLAUDE.md | tr -d ' ') lines"
	exit 0
fi

echo "| File | Lines | ~Tokens |"
echo "|---|---|---|"
echo "| CLAUDE.md | $(wc -l < CLAUDE.md | tr -d ' ') | $claude_tokens |"
printf '%s' "$rows"
echo "| **always loaded** (CLAUDE.md + skill descriptions) | | $always |"
echo "| **all skill bodies** | | $skills |"
