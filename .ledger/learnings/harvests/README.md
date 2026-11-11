# Harvest records

One file per harvest, `NNN.md` (001, 002, ...), written by the `framework-harvest` skill even
when nothing is approved. Local only (see `../../README.md`). `scripts/learnings.py due` reads
the latest one: the date in the title and the *Milestones at harvest* number must keep this
form.

```markdown
# Harvest NNN (YYYY-MM-DD)

- **Mode:** maintainer | autonomous (and when: e.g. close-out after M3, Lead idle).
- **Milestones at harvest:** <rows in .ledger/scorecard.md>
- **Trigger:** what made it due (`learnings.py due` output).
- **Budget:** always-loaded tokens before → after; skill bodies before → after.

## Applied (low risk)
| Card | Change | Commit |
|---|---|---|

## Card housekeeping
- Closed, reopened or merged cards, with the reason.

## Queued for the maintainer (risky)
- L-NNN: what, and why it's risky (also in `../pending-decisions.md`).

## Waiting for evidence
- Cards ranked high but not yet proposed, and what would change that.
```
