---
name: game-modeling
description: Use when a game's numbers (economy, pacing, difficulty, progression) are worth reasoning about with formulas or simulation, e.g. "can players afford the second upgrade in time", "what does +20% damage do later on", "balance this curve", or when building, extending, or validating a balance model. Optional: skip it for games whose outcomes don't reduce to numbers.
---

# Game Modeling

An optional tool for answering design questions without a full playtest. It serves the
game. It never decides what the game can be.

## The game comes first
- Never reject, simplify, or delay a mechanic because it's hard to model.
- If a mechanic doesn't fit the model, list it under "Not modeled" in the balance doc,
  say which questions that leaves unanswered, and move on.
- The model doesn't block a milestone, unless the project has recorded a decision that it
  should.
- When a playtest and the model disagree, the playtest wins. Then find out why.

## When it fits
- **Good fit**: outcomes driven by repeated numbers, such as prices, income, health, or
  growth curves.
- **Partial fit**: model just the numeric part (for example the economy of a physics game)
  and leave the rest to playtests.
- **Poor fit**: outcomes driven by player skill, physics, social play, or story. Skip it.

Don't build ahead of need. Start when a real design question appears, or when the user
asks. If it's unclear whether it's wanted, offer it in one line and continue without it.

## Build only what the questions need
Stop at the lowest level that answers them. Many games stop at level 2 or 3.

| Level | What | Answers | Cost |
|---|---|---|---|
| 1 | Numbers in config, formulas in pure modules (already a project convention) | "What does this cost at level 5?" | none |
| 2 | Design targets as Tier 1 tests | "Did a retune break the pacing?" | low |
| 3 | Step-by-step simulation with a scripted player | "How does a whole session go?" | medium |
| 4 | Closed-form model next to the simulation | "Which parameter matters?", instantly | high, and it needs upkeep |

**Simulation and model are different tools.** The simulation plays the session tick by tick
with the game's own rules, so it can match the real code exactly, but it doesn't explain
why. The model estimates each round from averages with formulas, so it's instant and shows
which term decides the outcome, but it can't see timing (where each unit is when). When they
disagree, the simulation wins. A model is worth its upkeep only while it stays responsive to
the parameters you tune. Check that with the sensitivity sweep below, and stop maintaining it
when it isn't.

## Building it
1. **Write down the questions** the model must answer, in the balance doc (template:
   `docs/design/templates/balance-model.md`).
2. **Call the game's own pure modules** from the simulation and the model. Never copy a
   formula.
3. **Move per-tick rules into pure modules too** (cooldowns, movement, status effects), or
   the simulation re-implements them and can drift. Calling the same formulas doesn't
   protect the loop around them.
4. **Express modifiers as config transforms**: a function that takes a config and returns
   a changed copy (difficulty, unlocks, permanent bonuses). The game, simulation, and model
   then share one definition with no special cases.
5. **Share the scripted player's decision rule** between simulation and model, so they play
   by the same choices, **but don't score options with the model being validated.** If the
   rule ranks purchases by the model's own formulas, any change to a formula also changes
   what the simulated player buys, and a model fix can't be checked against an unchanged
   simulation. Score with a separate, fixed function, or pin the simulation's decisions
   (record them once and replay) while you change the model.
6. **Keep more than one scripted player.** An optimizing player (best value per unit spent)
   shows what the numbers allow. A plain one (a fixed build order, simple placement) is
   closer to a typical human. Design targets for typical players belong on the plain one,
   or on both with separate bands.
7. **Name fitted constants as calibration**, and recheck them when the config changes. A
   constant fitted to today's numbers can make a wrong structure look right.

Keep these under `tests/sim/`, with a small command-line tool for each question.

## Validating it
Agreement in one number proves little. Run what the model's use justifies, in this order:

1. **Several measures, with a stated tolerance**: not only the final outcome. Include when
   trouble starts and the state per round, and check the shape of the curve as well as its
   average.
2. **Sensitivity**: change one parameter at a time and compare model and simulation. Count
   the changes where the model doesn't respond, where they move in opposite directions, and
   where the gap exceeds the tolerance.
3. **Replay on the real code**: record the simulated player's decisions and replay them on
   the real classes in the engine, then compare round by round. This checks the engine, not
   the player.
4. **A scripted player in the live game**: a script in a real client (Play session) that
   plays a whole session through the same remotes as the UI, with its own decision rule.
   It needs no human and shows what the live game does with a player that isn't the
   simulation's. When it disagrees with the simulation, replay its recorded decisions in
   the simulation: if the simulation then agrees, the gap is the player, not the engine.
5. **Step size**: run at each step size the live game can use, such as each game speed.
   The result shouldn't depend on it.
6. **Real players**: compare with recorded sessions. Stamp recordings with the config they
   were made under, and don't compare across configs without saying so.

Then write in the balance doc what it's **valid for** and **not valid for**, with the date.
A check that hasn't been run is reported as not run, never as passing.

## Re-evaluating after changes: the balance toolkit
Mechanics change, and balance decisions made today stop holding. Keep the evidence
re-runnable with the framework's toolkit in `tests/lib/balance/` (Lune, game-agnostic):

| Module | What it does |
|---|---|
| `Scenario` | Builds a matrix from axes in data (level × difficulty × players × persona) and runs it |
| `Metrics` | Outcome metrics: cliff length (first trouble → loss), pick rates, ablation loss, best option per probe |
| `Probe` | Probes from unit properties in config (armored, fast, clustered, …): a new property adds probes without code |
| `Baseline` | Flat metric snapshot in the repo, and a diff against it |
| `Claims` | Every design target and balance decision as a checkable claim with its source; known gaps are reported, not failed |

`Parallel.lune(worker, jobs, limit, cost)` runs each job in its own Lune process (one per
core, most expensive first), so a matrix of simulations takes about as long as its slowest
runs. Name long simulation specs `*.slow.spec.lua`: `make test` skips them, `make test-all`
runs them, and `make balance` runs the game's report (`tests/sim/eval.lua --check`).

The game writes only an **adapter**: how to run a scenario in its simulation, which unit
properties define probes, and its claims. Guidelines:
- **Define metrics on outcomes, not mechanics** (loss round, first trouble, cliff, pick
  rate, ablation), so they survive new mechanics.
- **Let personas act through a generic option list** built from config, so new content is
  measured without code changes.
- **Measure situational value with probes plus ablation**: in rounds that stress one unit
  property (the normal mix with that property weighted up), how much is lost without each
  option. Ablation, not damage per cost, so support options (slows, buffs) get credit for
  what they enable. Rounds made of only one property can be degenerate (a pure crowd round
  multiplies the unit count) and end every run at once.
- **Negative ablation means the persona misplays**: if removing an option makes the
  optimizer last longer, its evaluation overrates that option, and role measurements show
  the persona's mistakes, not the option's value. Fix the persona before tuning.
- **Write each balance decision as a claim** that cites where it's recorded. After a change,
  failing claims list the decisions to revisit; the baseline diff shows everything else that
  moved.
- **Check the toolkit itself**: a replay of a run's own decisions must reproduce it exactly,
  and a plain persona should reproduce a live scripted player's runs when given the same
  decision rule.

## Lessons from real projects

| What happened | Do this |
|---|---|
| The model predicted the final round well, but when trouble started was 3–5 rounds off. | Validate each measure separately, and only trust the ones that passed. |
| All specs passed with a tolerance of ±3 rounds, yet a sweep showed the model unresponsive to about a quarter of parameter changes and moving the wrong way on a few. | Add a sensitivity sweep. A wide tolerance on outcomes can't detect this. |
| The simulation's fixed step hid a timing bug: resetting a cooldown dropped the remainder, so fire rate rounded to whole steps and game speed changed the outcome. | Replay at the live step sizes, and carry remainders in time-based rules. |
| The scripted player never chose some of the content, so sweeps on it agreed trivially, and prices for it rested on no evidence. | Report which config entries the scripted player never exercised. Mark their value as unmeasured. |
| Tuning checked average pacing only, so "too easy, then a cliff" reached the playtest. | Add targets for the shape of the curve, not just its timing. |
| A failing design target sat behind a fully passing test suite. | Show known gaps in the test summary, so that passing doesn't read as on target. |
| Rapid failed purchases in a recording looked like a UI bug. The player was just impatient. | Recordings show what happened, not why. Ask the player before acting on them. |
| A session tool compared an old recording with today's model without warning. | Check that a recording's config matches before comparing. |
| The simulation matched the real code exactly, yet a live run with a plain scripted player lost far earlier on one level. The simulated player was an optimizer, and on a cramped level its choices were worth many rounds. | Validate with a plain player too, and say which player a measurement used. |
| A model fix for a new mechanic also changed the simulated player's purchases, because they were scored with the model, and it broke unrelated agreement specs. | Keep the decision rule's scoring independent of the model under test. |
| A plain persona lost 11 rounds earlier than the live scripted player it was meant to copy. Its build order differed: it cycled through every option, the live script favoured the generalist. With the same order the simulation matched live runs within one round on every level. | Share the exact decision rule (or its data) between a simulated persona and the live script, and check they agree. |
| All smoke tests passed while ablation showed two of four options were worth nothing to the optimizer. | Run ablation and probes before tuning numbers; they find dead options that outcome targets miss. |
| A recorded session's metadata was written before the players chose the level, so a replay used the wrong level. | Record setting changes as events in the session, and read the last one when replaying. |
| During tuning, a small config change moved a greedy persona's result by about 3 rounds, and roles flipped between variants. | Compare at least two personas (e.g. formula-scored and simulation-scored) before trusting a reading; treat changes within their spread as noise. |
| After tuning, every persona reached every placement limit with the same build, so "every option is bought" held trivially. | Check whether limits bind before reading pick rates as choice; when they do, choices are about order, spots, and upgrades, and ablation is the better measure. |
| The model saturated: once a unit's coverage exceeded one spawn gap it was assumed busy all round, so range, unit speed, and level shape stopped mattering, and it predicted the same result for every level. | Run the sensitivity sweep on geometry and speed parameters, and list saturating terms under "Not modeled". |
