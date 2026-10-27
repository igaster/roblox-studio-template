---
description: Start a new game — clarifying questions, GDD, and a first-milestone proposal. No game code.
argument-hint: <one-paragraph game idea>
---

Kick off a new game from this idea: $ARGUMENTS

Write **no game code** in this command. The output is design documents plus a proposal,
followed by a stop for the user's approval.

## Steps

1. **Understand the idea.** If it references existing games, ask what specifically the
   user likes about them (mechanics, feel, pacing). We borrow genre conventions only.
   Names, maps, characters, and art are original.
2. **Ask clarifying questions**: at most 5, using `AskUserQuestion`, one round. Only ask
   what changes the design (players per server, saving, monetization, session length,
   platform). Put a recommended option first. For anything not asked, choose a sensible
   default and list it in the GDD's "Open questions" so the user can override it.
3. **Write `docs/design/GDD.md`** from `docs/design/templates/gdd.md`. Keep it short.
   Include numbered, measurable design targets (`DT1`, …), since these become tests.
4. **Record settled answers** as decision records in `docs/decisions/`.
5. **Propose M1**: the smallest playable version that exercises the core loop
   end-to-end. Write it as `docs/design/milestones/M1-<slug>.md` from the template, with
   status `Proposed` and acceptance criteria filled in. Leave Plan/Tasks empty.
6. **Stop.** Summarize the GDD and M1 in a few lines, list the defaults you chose, and
   ask the user to approve or change them. Do not start building.
