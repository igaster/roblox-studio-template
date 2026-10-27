# Decision Records

One short file per settled decision, so neither humans nor agents relitigate it.
Name files `NNNN-short-slug.md` (e.g. `0001-players-per-server.md`).

```markdown
# NNNN — <Decision title>

- Date: YYYY-MM-DD
- Status: Accepted | Superseded by NNNN
- Decided by: <user / user + Claude>

## Context
Why this came up.

## Decision
What we chose.

## Consequences
What this rules in or out; what we'd need to revisit it.
```

A decision is reopened only when the user explicitly asks. Superseding it means
writing a new record and marking the old one `Superseded`.
