---
name: framework-training
description: Use when the maintainer asks to train or improve the framework by having a game built through it — e.g. "start a training session", "train the framework on a game like X", "continue training on <game>", "run the next training milestone".
---

# Framework Training (in-place)

## Overview

You are the **owner** of a game that the framework's Lead (`roblox-lead`, running headless)
designs and builds in this repo's working tree. You give it a brief, answer its questions
from a policy (`owner-proxy`), and at each milestone end review the run for framework friction
(`framework-review`) and propose framework fixes. **You never make a game decision yourself,
and you never tell the Lead it's being trained.**

Scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/` (when run from the repo:
`plugins/roblox-trainer/scripts/`). The `.py` ones run as `python3 -I <path>/<name>.py …`
(e.g. `python3 -I plugins/roblox-trainer/scripts/lead.py say <file>`); the `.sh` ones with
`bash`.

## 1. Set up the session

1. **Scenario:** get the brief and owner policy from the maintainer (their message, or a file
   they point to). Keep it in **`.training/scenarios/<NNN>-<name>.md`**: `.training/` at the
   repo root is gitignored and the Lead's profile denies reading it. A game's scenario stays
   there whether the game is live or archived; games switched out of the tree go to
   `.training/archive/<NNN>-<name>/`. Never put scenario answers anywhere else in the repo:
   the Lead could read them. Start from `scenarios/like-a-game.md` as the format.
   If the maintainer asks what to train on next, suggest a game that covers the emptiest rows
   of `.ledger/learnings/coverage.md`.
2. **Framework committed** (before anything else, so the run is tied to a known commit):
   `git status --porcelain -- $(bash plugins/roblox-trainer/scripts/commit-framework.sh --list)`
   must be empty. If not, ask the
   maintainer to commit or discard those framework changes first.
3. **Readiness** (before starting the session, so an aborted setup leaves no lock):
   - `make verify` passes.
   - Ask the maintainer once for the exact Studio place name for this game (as shown in
     Studio's title bar), unless you already know it from an earlier session.
   - Via the Studio MCP (yours, or a headless `claude -p --mcp-config .mcp.json`):
     `list_roblox_studios` shows exactly one Studio, **named exactly that place**; and
     `ServerScriptService.FrameworkSmokeTest` exists and its `Source` matches the file on
     disk (proves Rojo syncs *this* repo into *that* place).
   - Any mismatch or stale tree → ask the maintainer for the human step (open the right place;
     Rojo **Disconnect → Connect**), per `roblox-studio-mcp`. Don't start until it passes.
4. **Start the session** (tree check): if `docs/design/GDD.md` exists:
   - it's the game the maintainer wants to continue →
     `session.py start <kebab-name> --continue --place "<place>"`;
   - otherwise another game occupies the tree → stop and ask the maintainer what to do with
     it. Don't move or delete game files yourself.
   No GDD → `session.py start <kebab-name> --place "<place>"`, using a working name from the
   scenario (e.g. `like-grow-a-garden`); the game's real title comes later from the Lead's GDD.

## 2. Run the Lead

1. Write the brief to a temp file in `.training/` or your scratchpad, never elsewhere in the
   repo, and run `lead.py start <file>`. The brief
   is written as an owner would write it: the game, the involvement ("involve me only for…"),
   and the stop point. Nothing about training, the framework, or friction logs.
2. Read the Lead's reply. If it ends with questions, answer via `owner-proxy`, write the answer
   to a temp file and `lead.py say <file>`. Repeat until the Lead reports it stopped at the
   milestone boundary.
3. A human-only blocker (Studio, Rojo) → ask the maintainer, then `lead.py say` "done, carry on".
4. Watch for permission denials in the output: they mean the Lead tried something the profile
   doesn't allow. Note them for the review; never widen `permissions/lead-profile.json`
   without the maintainer's approval.
5. **Visibility while it works:** `python3 -I scripts/status.py` shows whether the Lead is
   running, its current task, its last tool call and the minutes since its last event (from
   the live log `.training/live/<game>.jsonl` that `lead.py` writes). Nothing for 15+ minutes
   with a call running → look at the live log; a usage limit or a stuck wait shows there.
6. **Messages from the maintainer mid-call** (a feature request, a hint): a call can't take
   messages. Queue it as a file and `lead.py say` it after the call ends, worded as the
   owner's own request.
7. **Pausing** (the maintainer leaves, the laptop sleeps): `lead.py stop` stops the call,
   and the session and the Lead's conversation are kept. Then check Studio is in Edit mode.
   Later, `lead.py resume` tells the Lead to check where it left off and carry on.

## 3. At each milestone end (the Lead is idle)

1. **Debrief:** before closing, `lead.py say` the standard wrap-up line, as an owner would:
   "Thanks for the report. Before we close <M>: note anything that slowed you down or that
   you had to work out yourself, wherever you keep those notes." (No verdict on the work:
   see `owner-proxy`.) Don't name the file or the framework; the Lead
   knows from `CLAUDE.md` where friction goes.
2. `session.py milestone <M>`.
3. Run `framework-review` for this milestone. It includes the blind reviewer, the owner-proxy
   audit and the scorecard row.
4. **Harvest if due:** `python3 -I scripts/learnings.py due`. On DUE, run `framework-harvest`
   in autonomous mode now, with the Lead still idle: low-risk fixes are applied and committed,
   risky ones are queued in `.ledger/learnings/pending-decisions.md`. It never waits for the
   maintainer. Put its report block in the close-out report.
5. `python3 -I scripts/human_checks.py --write` → `.training/human-checks-<game>.md`. Give
   the maintainer the count and the new items, so human checks don't pile up unseen.
6. Present the findings and proposed fixes to the maintainer. On approval, implement them
   (framework files only) and `commit-framework.sh "<message>" [new files...]` (new framework
   files must be named; untracked files are never swept in). Never push. **If the maintainer
   isn't there** (no answer, or they said they're away), don't wait: sort the fixes by
   `framework-harvest`'s risk tiers, apply the low-risk ones, queue the risky ones in
   `pending-decisions.md`, and go on to step 7.
7. If the run continues: `lead.py say` the owner's go-ahead for the next milestone (per the
   scenario policy), together with any queued maintainer requests. Fixes now in the tree are
   what the next milestone tests.

To change which game is in the tree, use `game-switch`.

## 4. End

`session.py end`. Then `framework-review` writes the run record and the ledger cards
(`.ledger/learnings/`). Report to the maintainer:
- milestones done;
- findings, and whether each was fixed now or sent to the ledger;
- fixes committed;
- anything left open.

**Last, always offer a harvest.** Run `scripts/learnings.py rank`. End the report with
one line that gives:
- how many open cards are ready: seen in two or more runs, or impact 3;
- the top three, by id and title;
- the offer itself: "Run `framework-harvest` now?"

If none are ready, say so and suggest waiting for another run. Don't start the harvest
yourself. The maintainer invokes it, and it only runs with no active session.

## Common mistakes

| Mistake | Instead |
|---|---|
| Answering a design question the policy doesn't cover | `owner-proxy`: "your call, mark it `(assumed)`" |
| Telling the Lead it's being trained, or naming the friction log or the framework | The framework already asks it to log friction (`CLAUDE.md`); the milestone debrief line is worded as an owner's wrap-up |
| Editing framework files while the Lead is working | Only at milestone boundaries |
| Committing with plain `git add` | `commit-framework.sh`, framework paths only |
| Moving another game out of the tree on your own | Ask the maintainer |
| Ending a run without mentioning the ledger | Close with the harvest offer (section 4) |
