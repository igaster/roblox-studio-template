# Decision records

One short file per settled decision, so neither people nor agents relitigate it. Name files
`NNNN-short-slug.md` (e.g. `0001-players-per-server.md`). This README is part of the framework;
the records belong to the game.

```markdown
# NNNN: <Decision title>

- Date: YYYY-MM-DD
- Status: Accepted | Superseded by NNNN
- Decided by: <creator / creator + Claude / Lead (assumed)>

## Context
Why this came up.

## Decision
What we chose.

## Consequences
What this rules in or out; what would make us revisit it.
```

- Record a decision when it's settled: the creator chose, overrode a recommendation, or
  approved something in advance, or the Lead decided alone (`(assumed)`).
- Small related decisions from one stage or milestone (several `(assumed)` defaults) can share
  one record, one line each under *Decision*.
- A decision is reopened only when the creator asks. Superseding one means writing a new record
  and marking the old one `Superseded by NNNN`.
