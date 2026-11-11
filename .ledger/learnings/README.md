# Learnings ledger

`.ledger/` at the repo root holds the `roblox-trainer` plugin's data (this ledger, `runs/`,
`scorecard.md`), kept apart from the plugin's definition in `plugins/roblox-trainer/`. Only
its structure and instructions are committed; the records stay local and gitignored
(`../README.md`). The headless Lead is denied reading it.

The training memory. **Level 1 (capture):** every training run adds raw evidence here, one
card per learning, deduplicated by symptom. **Level 2 (harvest):** the `framework-harvest`
skill reads all cards, ranks them, and turns the few that earn it into framework changes.

A run's decisions (the Lead's `(assumed)` calls, a fix the trainer liked) are evidence from
*one* game. The ledger exists so the framework changes on what recurs across games, not on what
the latest run happened to do.

## Who writes what

| Step | Who | When |
|---|---|---|
| Add occurrences, open new cards | `framework-review` | Run end, after the Lead has stopped (the Lead must not read this folder mid-run) |
| Rank, propose, adopt / decline / retire | `framework-harvest` | On the maintainer's request, between runs |
| Approve | the maintainer | Every status change past `open` |

Cards stay in the maintainer's clone (gitignored), so the history of why the framework looks
the way it does is kept without shipping one game's evidence in the template. A framework
commit that adopts a card names it in its message. Also in this folder:
- `coverage.md`: which framework areas each run exercised (created from
  `coverage.template.md` on first use).
- `pending-decisions.md`: risky harvest items waiting for the maintainer.
- `harvests/NNN.md`: each harvest's proposal and the maintainer's decisions on it.

## Card format

One file per learning: `L-NNN-<slug>.md` (`plugins/roblox-trainer/scripts/learnings.py next-id` gives the number).

```markdown
---
id: L-012
title: Attribute set just before Destroy() never reaches clients
kind: engine-fact
scope: universal
area: CLAUDE.md#runtime-state
impact: 3
seen: 002
status: open
---
**Symptom:** what went wrong, in a sentence a future run would recognise.

## Occurrences
- 002 M2: kill FX never fired; Lead found it by playtest (FRAMEWORK_FEEDBACK). ~15 min.

## Fix (proposed)
Where it would go and the smallest form it could take.

## Decisions
- (harvest dates, approvals, declines with reasons)
```

**Title the symptom, not the fix.** A future run hits the symptom; matching by symptom is how
the same learning gets a second occurrence instead of a duplicate card.

### Fields

- **kind**:
  - `friction`: a step was slow, retried, or blocked.
  - `gap`: guidance was missing.
  - `wrong`: guidance was wrong or outdated.
  - `engine-fact`: Roblox/Rojo/Luau behaviour that isn't obvious.
  - `pattern`: a convention the Lead invented that might belong in the framework.
  - `bug-class`: a kind of bug that reviews keep finding.
  - `working`: a framework rule that demonstrably helped. It protects that rule from removal.
    These cards stay `open` and are never proposed. `rank` shows them only with `--all`.
  - `trainer`: friction in the trainer plugin itself.
- **scope**:
  - `universal`: any game.
  - `genre:<name>`: one genre, e.g. `genre:tower-defense`.
  - `game`: this game only. Kept as a record, never harvested.
- **area**: the framework file or skill it touches, e.g. `skill:roblox-capture`,
  `shared/TestHooks`, `trainer:lead.py`.
- **impact**, the cost when it happens:
  - `3`: silent wrong behaviour (nothing errored), or it blocked the run or needed a human.
  - `2`: rework, a wrong rule followed, or more than ~10 minutes or several retries lost.
  - `1`: one retry or a nuisance.
- **seen**: the distinct run numbers it occurred in, comma-separated. Several hits in one run
  still count once here; list them all under *Occurrences*.
- **status**:
  - `open`: raw evidence, not yet judged.
  - `proposed`: in a harvest proposal awaiting the maintainer.
  - `adopted <sha>`: fixed in the framework.
  - `watching`: adopted, and the next runs check that the symptom is gone.
  - `declined`: with a reason under *Decisions*.
  - `retired`: no longer relevant: the framework changed, or no recurrence in many runs.
  - `merged L-NNN`: a duplicate of another card.
- **watch** (optional, `watching` cards): an extended regex for the symptom in a run's digest.
  - Prefix it with `!` when the symptom is something missing, e.g. a skill that never loaded.
  - `plugins/roblox-trainer/scripts/learnings.py watch <digest>` reports `RECURRED` or `CLEAR` for each card, and
    `MANUAL` for cards without a regex.

## What the memory covers

Problems alone aren't enough. The ledger also keeps four kinds of memory that stop the
framework drifting or re-litigating:

1. **What worked** (`kind: working`). Evidence a rule earns its place, so pruning doesn't
   remove it.
2. **Declined decisions, with reasons** (`status: declined` plus *Decisions*), so a later run
   doesn't re-propose them without new evidence.
3. **Fixes under watch** (`status: watching` plus `watch:`). An adopted fix stays open until a
   later run shows the symptom gone. If it recurs, the fix failed: reopen the card.
4. **Recurring bug classes** (`kind: bug-class`). Kinds of bugs that milestone reviews keep
   finding across games, e.g. state that outlives a leave or reset. Two games with the same
   class earn a review-checklist line.

Run numbers (minutes, tool calls, denials, errors) come from `plugins/roblox-trainer/scripts/transcript.py metrics`
and go in the run record, not in cards.

## What to capture, what to drop

Capture anything where **the framework** (not the game) shaped the outcome:

- friction, gaps, wrong guidance, engine facts;
- Lead-invented patterns;
- the four kinds of memory above.

Drop at capture time:

- the Lead's own bugs that its review or tests caught, unless they are a recurring class;
- one-off environment noise, e.g. a Studio plugin warning;
- game design choices.

When unsure, capture it with `scope: game`. Capture is cheap; the harvest decides.
