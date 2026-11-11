---
name: game-switch
description: Use when the maintainer wants a different game in the working tree for training — e.g. "switch to Tiptoe Bandits", "park this game", "start a new game", "go back to the tower defense" — moving games in and out of .training/archive/ while the framework stays shared.
---

# Game Switch

One game is in the working tree at a time. The **framework is never moved**: it stays shared
and always the latest, so a fix made while building game A is what game B is built with.
Only the game's own files move, with `scripts/game.py` (run with `python3 -I`):

| Command | Does |
|---|---|
| `game.py list` | archived games in `.training/archive/` |
| `game.py park <NNN-name>` | current game → `.training/archive/<NNN-name>/`; tree back to the template |
| `game.py load <NNN-name>` | archived game → the clean tree (the archive copy is removed) |
| `game.py switch <park-as> <load>` | both |

A game's files are worked out from git: untracked files, starter files it changed or deleted
(`commit-framework.sh --starters`), and its `FRAMEWORK_FEEDBACK.md`, `TRAINING_STATE.json` and
place `.rbxl`. Its scenario stays in `.training/scenarios/` either way. Old archives (full
clones with their own `.git`) load the same way.

## Steps

1. **Ask the maintainer first.** Switching is their call, never yours. Agree the archive name
   (`<NNN>-<kebab-name>`, NNN from the game's run) and which game comes in (or "template" for
   a new game).
2. **Close out the game leaving:**
   - Its friction is captured: `framework-review` ran for its last milestone, so
     `FRAMEWORK_FEEDBACK.md` is in the ledger. The file moves with the game, so anything not
     yet in the ledger leaves with it.
   - `session.py end`. The Lead is idle (`lead.py running` says idle).
   - Framework changes are committed or set aside: `status.py` lists them. They stay in the
     tree either way, but committing first keeps the switch easy to follow.
3. **Human step:** ask the maintainer to close the place in Studio. `game.py` refuses while
   Studio holds the `.rbxl` open (a `.rbxl.lock` exists).
4. Run `game.py switch <park-as> <load>`, or `park` alone for a new game.
5. **Coming back to a game is a framework test.** `game.py load` prints the framework commit
   the game last ran on. Run `make test` at once:
   - passing → note "loads clean on <sha>" in the run record;
   - failing → the framework broke an existing game. That's a ledger card (`kind: wrong` or
     `friction`, the failing check as evidence), and the Lead's first task in the next
     milestone is the fix.
6. **Human step:** open the game's place in Studio, connect Rojo, click **Accept**.
7. Set up the session as `framework-training` section 1 says (`--continue` for a loaded game),
   with the scenario from `.training/scenarios/`.

## Common mistakes

| Mistake | Instead |
|---|---|
| Switching on your own initiative | The maintainer decides |
| Parking before the review captured the friction log | Review first; the log moves with the game |
| Moving framework files, or "resetting" the framework to an older commit for an old game | Never: the old game meets the current framework, and that's the test |
| Copying game files by hand | `game.py`: it handles starters, deletions and per-game files |
