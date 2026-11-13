---
name: game-switch
description: Use when the maintainer wants to train on a different game — e.g. "switch to Tiptoe Bandits", "start a new game", "go back to the tower defense" — switching the training session between games in games/ while the framework stays shared.
---

# Game Switch

Each game lives in its own folder, `games/<name>/` (its own git repo, made from `template/` by
`make new-game NAME=<name>`). Nothing moves when you switch: the training session points at
another folder (`gameDir` in `TRAINING_STATE.json`), and Rojo serves that game. The
**framework is never moved**: it stays shared and always the latest, so a fix made while
building game A is what game B is built with.

Scenarios stay in `.training/scenarios/`, live logs and messages in `.training/` by game name.

## Steps

1. **Ask the maintainer first.** Switching is their call, never yours. Agree which game comes
   in (an existing folder, or a new one: `make new-game NAME=<kebab-name>`).
2. **Close out the game leaving:**
   - Its friction is captured: `framework-review` ran for its last milestone, so its
     `FRAMEWORK_FEEDBACK.md` (tracked in the game's folder) is in the ledger.
   - `session.py end`. The Lead is idle (`lead.py running` says idle).
   - Framework changes are committed or set aside: `status.py` lists them.
3. **Human step:** stop Rojo for the leaving game (its `make serve`), and close its place in
   Studio.
4. **Coming back to a game is a framework test.** Its `game.json` has the framework commit it
   last ran on. Run `make test` in its folder at once:
   - passing → note "loads clean on <sha>" in the run record;
   - failing → the framework broke an existing game. That's a ledger card (`kind: wrong` or
     `friction`, the failing check as evidence), and the Lead's first task in the next
     milestone is the fix.
5. **Human step:** `make serve` in the incoming game's folder; open its place in Studio,
   connect Rojo, click **Accept**.
6. Set up the session as `framework-training` section 1 says (`--continue` for a game with a
   GDD), with the scenario from `.training/scenarios/`.

Games from before `games/` (archived in `.training/archive/<NNN>-<name>/` by the old
`game.py park`) are moved into `games/<name>/` once, the way the game factory plan's
*Moving Clockwork Keep* section did it (`docs/superpowers/plans/2026-11-13-game-factory-layout.md`).

## Common mistakes

| Mistake | Instead |
|---|---|
| Switching on your own initiative | The maintainer decides |
| Ending the session before the review captured the friction log | Review first |
| Two games' Rojo servers at once | One `make serve` at a time (same port) |
| "Resetting" the framework to an older commit for an old game | Never: the old game meets the current framework, and that's the test |
