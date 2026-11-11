---
name: framework-review
description: Use at the end of a training milestone or run to review how the framework performed for the Lead and turn friction into proposed framework fixes.
---

# Framework Review

Review the **framework**, not the game. The question is always: where did CLAUDE.md, the
skills, the templates or the shared modules fail, mislead, or slow the Lead down?

## Inputs (collect all)

1. **Lead transcript:** never load it whole.
   - `python3 -I scripts/transcript.py digest [--since <ISO time>] > <scratch file>` prints one
     line per tool call, skill load, error, denial and Lead text. It finds the transcript from
     `leadSessionId` in `TRAINING_STATE.json`.
   - `python3 -I scripts/transcript.py metrics` prints a per-turn table (minutes, tool calls,
     Studio calls, denials, errors, subagents, skill loads, usage-limit pauses) for the run
     record.
2. **`FRAMEWORK_FEEDBACK.md`** at the repo root (the Lead's own friction log; older runs
   used `FEEDBACK.md`, read it too if present).
3. **Framework files the Lead edited:** `git diff <frameworkCommit> -- $(bash
   plugins/roblox-trainer/scripts/commit-framework.sh --list)` plus `git status` for new
   files under those paths (frameworkCommit from `TRAINING_STATE.json` history). Any edit there is a strong signal: the Lead worked around the framework.
4. **Artifacts:** the milestone file's *Result*, `docs/decisions/`, `docs/STATUS.md`, `docs/TESTING.md`.
5. **Your own notes** from `owner-proxy`: uncovered questions, and the permission denials
   `lead.py` printed.
6. **Owner messages:** `.training/messages/<game>/` (every brief and message `lead.py` sent).
7. **Scorecard numbers:** `python3 -I scripts/scorecard.py record <run> <M> --since <ISO of the
   milestone's first owner message> --reviewer-fixes N --human-blockers N` appends the
   milestone's row to `.ledger/scorecard.md` (Lead minutes, tools, denials, errors, owner
   messages, agent-verified vs open human checks). Put the row in the run record too.

## Blind review (independent second opinion)

You took part in the run, so your review is anchored on your own account of it. Before
writing findings, get one that isn't:

1. Write the digest to a scratch file, and the framework diff (input 3) to another.
2. Spawn a **fresh** general-purpose subagent (not a fork) with the prompt in
   `skills/framework-review/blind-reviewer.md`, its placeholders filled in. Give it nothing
   else: no summary, no hypotheses, no ledger.
3. Write your own findings without reading its report first, then compare:
   - **both found it:** keep it, with more confidence;
   - **only the reviewer found it:** add it, or record in the run record why you rejected it;
   - **only you found it:** keep it; note that the reviewer missed it.
4. **Owner-proxy audit:** every issue the reviewer raised about your messages to the Lead
   (leaks, invented preferences, overreach, under-answering) goes to the maintainer as is,
   with your response. Don't drop any. A confirmed issue becomes a `[trainer]` finding.
5. The run record gets a *Blind review* section: agreements, reviewer-only findings (kept or
   rejected, with why), and the audit result.

## What to look for

- Skills that should have loaded and didn't (check the transcript's skill loads against the
  work done), or loaded late.
- Rules the Lead broke without knowing (it never read them), or followed and still failed.
- Retries, loops, long stalls, human-only blockers that could have been detected earlier.
- Invented conventions (a folder, a pattern) the framework should have defined.
- Questions to the owner the involvement contract should have settled.

## Also review the trainer itself

The training process is under test too. From the same run, note where the **trainer plugin**
(its skills, scripts, permission profile, scenario format) caused friction for you: a step
that was unclear or in the wrong order, a script that failed or needed a workaround, a
permission the Lead lacked, an owner question the policy format couldn't express. List these
as separate findings tagged **[trainer]** with a proposed fix in `plugins/roblox-trainer/`.
Fixes follow the same rule: propose, get the maintainer's approval, commit with
`commit-framework.sh`, only while the Lead is idle.

Also note what **worked**: a framework rule the Lead leaned on that saved it time or a bug.
These become `working` cards, the evidence that keeps a rule from being pruned.

## Output

1. **Findings** (framework and **[trainer]**), ranked High / Medium / Low, each with evidence (transcript line, feedback
   entry, diff hunk) and the proposed fix (which framework file, what change).
   Before ranking a finding, look it up in the ledger (`.ledger/learnings/`, match by symptom).
2. **Fix now, or ledger only.** One run is one game's evidence. Propose a fix *at this boundary*
   only when it is a reproducible impact-3 universal problem (a silent engine fact, a
   blocker), or a [trainer] fix the next milestone needs. Everything else goes to the ledger
   for `framework-harvest`, even when the fix looks obvious. Say which findings went where.
3. **Ledger capture** (at run end, after the Lead has stopped), per `.ledger/learnings/README.md`:
   - A known symptom: add an occurrence. If this run is new for the card, add it to `seen`.
     If the card was `watching`, record whether the symptom recurred.
   - A new symptom: open a card with id from `scripts/learnings.py next-id`.
   - A declined card that recurred: add the occurrence, and leave the status alone.
   - `watching` cards: `scripts/learnings.py watch <digest>`. Record each result as an
     occurrence, e.g. `- 003: watch CLEAR`. Judge the `MANUAL` cards by reading.
   - Recurring bug classes: group the reviewer subagent's fixes by kind. A kind seen in an
     earlier game goes on its `bug-class` card.
   - Add this run's column to `.ledger/learnings/coverage.md` (copy it from
     `coverage.template.md` if it doesn't exist yet).
   - Then `scripts/learnings.py check`.
4. **Run record** `.ledger/runs/<NNN>-<game>.md` (NNN = next number in `.ledger/runs/`). Give the card id for each
   finding. Use this structure:

```markdown
# Run <NNN>: <game>
- Date · scenario · involvement level · stop point
- Framework commits: <start> → <after each milestone>
- Context budget: <`scripts/context-budget.sh --total` at the run's framework commit>
## Metrics
<`scripts/transcript.py metrics` table>
## Milestones
- M<N>: outcome (go/iterate/cut, agent-verified or human), duration, notable events
## Scorecard
<the milestone's `scripts/scorecard.py` row>
## Findings
| Card | Severity | Finding | Evidence | Fix (file) | Status (ledger / proposed / committed <sha> / declined) |
## Blind review
- Agreed: … · Reviewer only: … (kept / rejected, why) · Trainer only: …
- Owner-proxy audit: issues (or none), and what was done about each
## Owner-proxy
- Questions asked: N (covered N, uncovered N, escalated N)
```

Write the run record and the ledger cards only after the Lead has stopped. Both live in the
plugin, which the Lead could read while running. Under auto mode these writes to `plugins/` may
get no classifier verdict; ask the maintainer to switch to manual mode for them.
