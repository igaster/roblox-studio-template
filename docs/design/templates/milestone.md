# M<N>: <Name>

> Copy to `docs/design/milestones/M<N>-<name>.md`. The `roblox-game-design` skill
> proposes milestones for a new game or a large feature. Work on a milestone starts
> only after the creator confirms it, or when the GDD's *Owner involvement* pre-approves it
> (`roblox-lead`).

> GDD design targets touched: DT<n>, … Plan: [M<N>-<name>-plan.md](M<N>-<name>-plan.md)
> (from `milestone-plan.md`; it names the checkpoints).

## Goal

What this milestone proves or delivers, as one sentence a player could notice.
For M1 this is usually: "The core loop is fun", tested with greybox art.

## Question it answers

The riskiest assumption this milestone tests, and how we'll know (a playtest
observation, a `TestHooks` event, a number).

## Scope

| Feature spec | Status |
|---|---|
| [features/<Name>.md](../features/<Name>.md) | planned / in progress / done |

## Out of scope

Things deliberately left for later milestones, and why.

## Depends on

Earlier milestones or systems that must exist first (persistence, a feature, art).

## Done when

All feature specs' acceptance criteria pass, plus these milestone-level checks. Each has an
ID (`M<N>-AC1`) and says how it's verified (Tier 1, Tier 2, `[playtest]`, `[visual]`,
manual; add `[needs-published]` when it can only run on a published place, which defers it to
the GDD's *Publishing* milestone: list it in `STATUS.md` under *Deferred checks*); a test checking it carries the ID in its name. Copy them into `docs/TESTING.md`
under a section for this milestone.

- [ ] M<N>-AC1 `[playtest]` ...
- [ ] M<N>-AC2 Playtested with real players; findings recorded below.

## Result

Filled in when the milestone ends.

- **Outcome:** go / iterate / cut
- **Evidence:** per criterion ID: pass / fail / needs the creator, with the proof (test
  output, TestHooks events, screenshots). A criterion without evidence hasn't passed.
- **What we learned:**
- **Framework friction:** `FRAMEWORK_FEEDBACK.md` entries from this milestone, reviewed.
- **Changes to the GDD or next milestones:**
