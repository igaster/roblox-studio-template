# Training ledger

Data of the optional `roblox-trainer` plugin (`plugins/roblox-trainer/`). A game built from
this template doesn't use it.

Only the structure and the instructions are committed. The records a training run writes stay
in the maintainer's clone, gitignored (`.ledger/.gitignore`), so no game's runs, decisions or
learnings ship with the template:

| Path | What | Written by |
|---|---|---|
| `scorecard.md` | One row per milestone: minutes, tool calls, denials, human blockers | `scripts/scorecard.py record` (creates it) |
| `runs/NNN-<game>.md` | One record per training run | `framework-review` ([runs/README.md](runs/README.md)) |
| `learnings/L-NNN-<slug>.md` | One card per learning, across runs | `framework-review`, `framework-harvest` ([format](learnings/README.md)) |
| `learnings/coverage.md` | Framework areas each run exercised | `framework-review`, copied from `coverage.template.md` on first use |
| `learnings/pending-decisions.md` | Risky harvest items waiting for the maintainer | `framework-harvest` (autonomous mode) |
| `learnings/harvests/NNN.md` | Each harvest's proposal and decisions | `framework-harvest` ([harvests/README.md](learnings/harvests/README.md)) |

Back the folder up yourself if you train on more than one machine: git doesn't carry it.
