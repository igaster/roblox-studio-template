#!/usr/bin/env bash
# SessionStart hook (new chat, /clear, compaction): tells the session whether docs/STATUS.md,
# the handoff page, is older than the work in the tree. A stale page anchors a new chat on
# work that's already done or no longer planned, so the session is asked to check it and
# rewrite it before acting on it (CLAUDE.md, Documentation). Prints nothing when there's
# no game yet or the page is current.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
status="docs/STATUS.md"
[ -f "$status" ] || exit 0

newer=$(find src docs tests -type f -newer "$status" \
	! -name '.DS_Store' ! -path 'docs/captures/*' 2>/dev/null | sort)
[ -n "$newer" ] || exit 0

count=$(printf '%s\n' "$newer" | wc -l | tr -d ' ')
examples=$(printf '%s\n' "$newer" | head -5 | sed 's/^/  - /')
written=$(date -r "$status" '+%Y-%m-%d %H:%M' 2>/dev/null)

cat <<EOF
Handoff check: docs/STATUS.md was last written ${written}, and ${count} file(s) changed after it, e.g.:
${examples}
Its "Where we are" and "Last verified" may be stale. Before acting on them, check them against
the milestone plan's checkboxes and the code. Then rewrite the page to what you confirmed,
deleting what you couldn't confirm, before starting other work (CLAUDE.md, Documentation).
EOF
