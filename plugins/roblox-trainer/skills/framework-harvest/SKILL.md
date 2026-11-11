---
name: framework-harvest
description: Use when the maintainer asks to harvest, curate or triage training learnings across runs — e.g. "harvest the learnings", "what should we change in the framework", "curate findings", "clean up the framework" — to turn the learnings ledger into a few framework changes without cluttering it.
---

# Framework Harvest

## Overview

Second pass over the **learnings ledger** (`.ledger/learnings/`, see its README). `framework-review`
captures raw evidence per run; this skill decides which learnings change the framework, in what
form, and which are discarded. **Default to no change**: a learning has to earn its place
against the cost of every agent reading it in every future session.

**When it runs:** only while no Lead call is running (`lead.py running` says idle): between
runs, or at a milestone close-out. It runs in one of two modes:
- **Asked:** the maintainer invokes it. Present everything and apply what they approve (section 5).
- **Autonomous:** `learnings.py due` says DUE at a close-out (or the SessionStart reminder says
  so). Low-risk changes are applied without asking; risky ones are queued for a human
  (section 6). This never waits for the maintainer: the close-out carries on and the Lead
  goes to its next milestone, whether or not anyone is present.

## 1. Rank

`python3 -I scripts/learnings.py rank` prints every non-closed card with its score:
`impact × distinct runs × scope weight` (universal 2, genre 1, game 0). The score orders
the reading list. It is not the verdict. Read the latest `.ledger/learnings/harvests/NNN.md` first,
so items deferred or declined there aren't re-argued without new evidence.

## 2. Judge each card against the gates

A card is **proposed** only if it passes all of these:

| Gate | Passes when | Otherwise |
|---|---|---|
| **Framework-caused** | The framework missed, misled or slowed the Lead. The Lead's own slip, or a game choice, doesn't count. | Decline |
| **General** | `scope: universal`, or a genre seen in 2 or more runs | Keep `open`. Single-game is never harvested |
| **Evidence** | One of: seen in **2 or more runs**; or **impact 3** and reproducible (a silent engine fact, a blocker); or a `pattern` that **2 or more games invented independently** | Keep `open`, waiting for recurrence |
| **Not already covered** | The framework doesn't already say it. If it does and the Lead didn't follow it, the learning becomes "why wasn't it loaded or read?", which is a different fix | Re-file the card as that |
| **Not declined before** | No earlier decline, or the new evidence is stronger than the reason given then | Add the occurrence, stay declined |

Other signals for ordering and arguing the case:
- **Silent beats loud:** a failure with no error, that the Lead can't self-correct, matters more.
- **Self-recovered fast:** lower priority.
- **Cost of the fix:** lower is better.
- **Confidence:** verified beats suspected.
- **Coverage:** an area no game has exercised yet is a reason to keep watching, not to act.

## 3. Choose the smallest form (anti-clutter)

Use the first rung of this ladder that works. Each rung down is read by more sessions:

1. **Enforce it in code:** a check in `make verify`, `tests/framework.lua` or `FrameworkSmokeTest`,
   a shared-module helper, or a permission. An agent can't skip a failing check.
2. **Fix the tool or template** so the problem can't happen, e.g. markers that make the
   example removable with Edit.
3. **A skill's `references/` file:** read only on demand.
4. **A skill's `SKILL.md`:** read whenever that skill loads.
5. **`CLAUDE.md`:** read by every session. Reserve it for rules every task needs, and keep
   each one to a line or two.

**Budget:** before adding prose, look for an existing rule to merge it into or replace. Run
`scripts/context-budget.sh --total` before and after, and report both. The *always-loaded*
number (`CLAUDE.md` plus skill descriptions) is the one that counts most. A harvest that grows
it needs a stated reason; one that shrinks it is a win in itself.

## 4. Prune (every harvest)

- `working` cards protect their rule. A rule with no `working` card and no card pointing at it,
  in a section untouched by the last several runs, is a **removal candidate**. List these. Don't
  delete them on your own.
- `watching` cards: read the `watch` results that `framework-review` recorded for each run
  since adoption. `CLEAR` in at least one run that exercised the area (see
  `.ledger/learnings/coverage.md`) → close as `adopted`. `RECURRED` → the fix failed: reopen with the
  new evidence. A card cleared only by runs that never touched its area stays `watching`.
- Close duplicates as `merged L-NNN`. Retire cards made obsolete by framework changes.

## 5. Propose, then apply

1. Present the proposals ranked, one per card:
   - the card id;
   - the evidence (runs, impact);
   - the form chosen from the ladder;
   - the exact change;
   - the line-count effect.
   
   Also present:
   - the declines with reasons;
   - the removal candidates;
   - the cards still waiting for evidence;
   - the emptiest rows of `.ledger/learnings/coverage.md`, as a suggestion for the next training game.
2. Apply only what the maintainer approves:
   - edit framework files only;
   - set each card's `status` and add a dated line under its *Decisions*;
   - mark adopted cards `watching`, with the symptom to look for in the next run.
3. Write `.ledger/learnings/harvests/NNN.md`, the next number, even when nothing is approved. It holds
   the proposal as presented, the budget before and after, the maintainer's decision on
   each item, and `Milestones at harvest: <rows in .ledger/scorecard.md>`.
4. Commit the framework changes with `scripts/commit-framework.sh "<message>" [new files...]`,
   naming the cards in the message. Cards and the harvest record stay local (`.ledger/` is
   gitignored apart from its READMEs). Never push.

## 6. Autonomous mode: risk tiers

Everything in sections 1–4 still applies: the gates, the smallest form and pruning. Only the
approval step changes. Sort each proposal into a tier:

| Tier | What counts | Done how |
|---|---|---|
| **Low risk** | A skill's `references/` file; a wording or small addition in a skill's `SKILL.md` (net budget growth under ~150 tokens per harvest); a new check or helper with tests that pass, which no existing code depends on; a trainer-only script or skill fix; declining, merging or retiring a card; closing a `watching` card per section 4 | Apply, run `make test` and the trainer tests, commit (one commit per card, `commit-framework.sh`), mark the card `adopted <hash>` / `watching` |
| **Risky** | `CLAUDE.md`; skill descriptions (always loaded); the Lead's permission profile; a changed or removed public API in `src/shared/`; removing a rule; growth of the always-loaded budget; anything a test can't check, or a fix you aren't sure is right | Don't apply. Add it to `.ledger/learnings/pending-decisions.md`; set the card to `proposed` |

When unsure, it's risky. A low-risk change whose tests fail is reverted and queued as risky
with the failure noted.

**`pending-decisions.md`:** one section per item, newest last:

```markdown
## L-NNN <title>
- **Status:** pending
- **Queued:** <date>, harvest NNN
- **Evidence:** runs, impact, digest lines
- **Proposed change:** the exact edit (file, lines), its tier and why it's risky
- **If declined:** what happens to the card
```

Merge items that touch the same file into one. When the maintainer reviews the queue
("review pending decisions"), apply each one they approve as in section 5. Then set its
**Status** to `approved <hash>`, `declined (reason)` or `changed: <what>`, and update its card.

**The report is one block in the close-out:** applied (card, change, commit), queued (card,
one line), the budget before and after, and declined or pruned cards. The harvest record
(`harvests/NNN.md`) says `mode: autonomous` and records `Milestones at harvest: <scorecard
row count>`, which `learnings.py due` counts from.

## Common mistakes

| Mistake | Instead |
|---|---|
| In autonomous mode, waiting for the maintainer before letting the Lead continue | Queue the risky items and carry on; the queue is reviewed whenever they're back |
| Calling a `CLAUDE.md` or permission change low-risk because it's one line | Tier by where it lands, not by size: every session reads `CLAUDE.md` |
| Harvesting the latest run's findings because they're fresh | Rank across the whole ledger; recency is not a signal |
| Adding a CLAUDE.md line for a skill-specific fact | Lowest ladder rung that works |
| Adopting a Lead-invented pattern from one game | Wait for a second game, or the maintainer's explicit opt-in |
| Re-proposing a declined card with no new evidence | Add the occurrence, stay declined |
| Closing a fix as done right after committing it | `watching` until a run shows the symptom gone |
