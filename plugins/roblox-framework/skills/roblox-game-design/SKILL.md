---
name: roblox-game-design
description: Use when the user pitches a new game idea (including "a game like X"), asks to design or plan a game or feature, asks to change balance or tuning ("make X faster/cheaper/stronger"), proposes monetization (game passes, developer products, crates, daily rewards), or asks "is this fun" / "what should I add next" in a Roblox project.
---

# Roblox Game Design

## Overview

Take the creator from an idea to an **approved implementation plan they can start
building**. Engineering skill is not the gap: you already handle scope, server
authority and policy APIs well. The gaps are **player experience before mechanics**,
**Roblox platform reality**, and **proving the fun before building content**.

Core rule: every design decision traces to a **pillar**, lands as **`GameConfig` keys**,
and ships with **acceptance criteria** that become `docs/TESTING.md` items.

You guide; the creator decides. When they override a recommendation, record it in
`docs/decisions/` (one file per decision, see its README) and move on.

For end-to-end production with little owner involvement, `roblox-lead` runs this pipeline
and decides what to ask. If `superpowers:brainstorming` is active, it owns the conversation (one question at a
time, approval gates). This skill supplies the pipeline, the questions and the templates.

## Which mode?

| Request | Mode |
|---|---|
| New game, or no `docs/design/GDD.md` yet | **A. Design pipeline**, from stage 0 or 1 |
| Large feature (several systems, a new dependency, more than one playtest) | **A. Design pipeline**, from stage 2 |
| Small feature for an existing game | **B. Feature check** |
| "Make X faster/cheaper/more/less" (no target value) | **C. Tuning diagnosis** |
| Concrete change: explicit value ("jump power 60"), typo, bug fix, small feature inside the current milestone | **Don't use this skill**: just do it (`CLAUDE.md`) |

## A. Design pipeline

| Stage | Output | Done when |
|---|---|---|
| **0. Teardown** (a reference game is named) | `docs/design/references/<Game>.md` | Creator's play notes in; selling point **"like X, but Y"** chosen |
| **1. Concept** | `docs/design/GDD.md` (fantasy, pillars, loop, reality check) | Creator approves the GDD |
| **2. Milestone plan** | Milestones table in the GDD | Creator approves the order |
| **3. Milestone spec** | `milestones/M<N>-<name>.md`, `features/*.md`, milestone section in `docs/TESTING.md` | Every feature has config keys, state/events, acceptance criteria |
| **4. Build handoff** | Implementation plan for the milestone | **Creator approves the plan → building starts** |
| **5. Milestone result** | *Result* section of the milestone file | Go / iterate / cut decided |

Stage 4's approved plan is the goal of the pipeline. Don't stop at the GDD.

### 0. Teardown
Run `roblox-game-teardown`. Present its 2–4 "like X, but Y" openings and **stop for the
creator to choose one** (or propose their own). Record it in the GDD's *Inspirations and
selling point* section. If no game is named, identify the genre with `references/genres.md`.

### 1. Concept
Cover these in order, experience first, mechanics last:

1. **Player fantasy** and audience (age, solo vs friends).
2. **Pillars**: 2–4 statements that accept or reject features.
3. **Core loop** at three timescales: ~30 s action, 5–10 min session goal, reason to return.
4. **Roblox reality check**: `references/roblox-platform.md`. Flag any loop that breaks at
   low player counts before discussing mechanics.
5. **Riskiest assumption**, usually "is the core loop fun?" or the selling point itself.
6. **Design targets**: numbered, measurable (`DT1`: "first purchase within 60 s"). They become
   Tier 1 tests, so pacing survives later tuning.

**With a teardown, draft instead of asking.** Write a proposed fantasy, pillars and loop
derived from the chosen Y and the teardown's *Keep* / *Change* columns, and ask the creator
to confirm or edit each. Without a teardown, ask one at a time; offer examples from
`references/player-experience.md` when the creator is unsure.

### 2. Milestone plan
Read `../../docs/design/templates/milestone-catalog.md` first: give every entry a one-line
verdict (fits, merges into M<n>, or skip with a reason) and keep its ID (`G3`) in the GDD's
*Milestones* row. The catalog is a menu; add any milestone the game needs that isn't there.
Order: dependencies first, then the riskiest assumption, then content, then monetization.
**M1 = the smallest playable test of the riskiest assumption**: greybox art, one of each
thing, no monetization, no persistence unless the loop needs it. Present as a short list
(milestone, goal, features); later milestones stay one line each.

### 3. Milestone spec
Only the current milestone gets full specs: the milestone file from
`../../docs/design/templates/milestone.md`, one `features/<Name>.md` per feature from
`templates/feature-spec.md`, and their acceptance criteria copied into `docs/TESTING.md`.

### 4. Build handoff
Write the implementation plan to `docs/design/milestones/M<N>-<name>-plan.md`, starting from
`../../docs/design/templates/milestone-plan.md` (checkpoints, rules for every task, the task
skeleton), with
`superpowers:writing-plans` if available (tell it that path: game plans never go under
`docs/superpowers/`, which belongs to the framework) or yourself. Either way, each task names:
the feature spec it implements, the files it touches (`GameConfig` keys, generator, class,
service, client script), its Tier 1 tests, and the acceptance criteria it satisfies.
Each task also names the **skill to load** before starting it (`CLAUDE.md`, *Skills to load*):
`roblox-asset-generators` for world or UI content (and the generator kind: asset, level or
GUI; levels are rebuilt on every server start, never "built if missing"), `roblox-test` for
tests (Tier 1, the smoke test, a balance simulator), `roblox-studio-mcp` for anything run in
Studio (`execute_luau`, Play), `roblox-playtest` for in-Studio verification, `roblox-capture`
for screenshots. A task that does several kinds of work names every skill it needs, and its
files are a checklist ticked as each is done, so an interrupted task can be resumed from the
plan rather than reconstructed. **Size each task to fit one chat:** a task likely to need
more than about 150 tool calls (several systems, a long tuning sweep, art for every tower) is
split, because a chat's cost per step grows with everything it has done so far. Order tasks so something is playable early. Building starts only after the creator
approves the plan (`CLAUDE.md`: never start a milestone without confirmation), or the
GDD's *Owner involvement* pre-approves it (`roblox-lead`).

### 5. Milestone result
After building: run the milestone's checks (`roblox-test`, `roblox-playtest`) and ask the
creator to playtest. Fill in the milestone's *Result* (go / iterate / cut, what we
learned, evidence per criterion, the framework friction from `FRAMEWORK_FEEDBACK.md`), update
the GDD, then propose the next milestone's spec (back to stage 3).

### End every stage the same way

Close each stage with these four parts, in order:

1. **Decided:** the decisions made, one line each.
2. **Files:** paths written or updated.
3. **Progress:** `Teardown ✓ → Concept ✓ → Milestones ▶ → Spec → Build plan`
4. **Next:** the recommended next step as a question, plus 1–2 alternatives.

### Fast track

If the creator asks to skip the questions ("just draft it all"), run stages 0–4 in one
pass: pick the recommended Y, draft the concept, milestone plan, M1 spec and M1
implementation plan, and mark every decision you made for them `(assumed)`. Present it
all for a single review, listing the `(assumed)` decisions first. Building still waits
for the creator's approval of the plan.

## B. Feature check

Before planning a feature, answer, and show the answers:

- Which pillar does it serve? Which loop timescale does it feed?
- What must exist first (persistence, an item worth trading, enough players)?
- Is it in the current milestone? If not, offer the backlog or a later milestone.

Then write `docs/design/features/<Name>.md` from `../../docs/design/templates/feature-spec.md`,
link it from the milestone's Scope table, and copy its acceptance criteria into
`docs/TESTING.md` under that milestone.

## C. Tuning diagnosis

Treat a tuning request as a symptom. Before changing a number:

1. **What player problem is this fixing?** (drop-off point, a boring stretch, a wall)
2. **Where in the economy?** Name the source and the sink it affects (`references/economy.md`).
3. **What does it cost?** Faster progression uses content up faster. More income inflates prices.
4. **One knob, in `GameConfig`**, plus a way to know it worked (a `TestHooks.log` event, a playtest check).
5. **If the question is about consequences** ("what does +20 % damage do later on", "can
   players afford the second upgrade in time"), or the game keeps a balance model, use
   `roblox-game-modeling`: a simulation answers in seconds what a playtest answers in an hour.

Monetization requests also go through `references/economy.md` → *Monetization*: no
pay-to-win against other players, and look up current policy via context7 (`/roblox/creator-docs`).

## Common mistakes

| Mistake | Instead |
|---|---|
| Stopping at the GDD | Continue to stage 4: an approved implementation plan |
| A stage ends without a next step | Close with Decided / Files / Progress / Next |
| First question is about mechanics (turn-based vs real-time) | Fantasy → pillars → loop first |
| Asking concept questions the teardown already answers | Draft from Keep/Change, ask to confirm |
| Plan or backlog mirrors the reference game's features | Keep conventions, change the selling point, never copy identity |
| "Like X" with no "but Y" | Creator picks Y before the concept |
| Live PvP/co-op loop with no answer for an empty server | Async (vs saved teams/ghosts), bots, or solo fallback |
| M1 = "build the feature list" | M1 = prove the riskiest assumption, greybox |
| Full specs for every future milestone | Spec only the current milestone |
| Changing a rate because the user asked | Diagnose the problem, name the sink, then one config knob |
| Paid power that wins PvP | Sell cosmetics, convenience, or solo boosts |
| Monetization or daily rewards before the loop is proven | Backlog them until M1 passes |
