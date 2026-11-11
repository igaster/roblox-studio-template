# <Game Name>: Game Design Document

> Copy to `docs/design/GDD.md` and fill in. Keep it short; link out to
> `docs/design/features/*.md` for detail. The `roblox-game-design` skill fills this in
> during a design session.

## Owner involvement

How much the owner wants to be asked. The `roblox-lead` skill reads this; the owner can change
it any time.

- **Level:** milestones
- **Stop after:** M1

| Level | The Lead asks the owner… | The Lead decides alone, marked `(assumed)` |
|---|---|---|
| `full` | at every pipeline stage and design choice | nothing material |
| `milestones` | the selling point, GDD approval, each milestone plan | everything inside an approved milestone |
| `none` | nothing; reports at milestone ends | everything, logged in the Decisions log |

**Stop after:** `M<N>` (stop and report after that milestone) or `never`.

## Pitch

One sentence: who the player is and what they get to do.

## Inspirations and selling point

**Like <reference>, but <what's different>.** Why would a player of the reference play this?

| Reference | Teardown | What we keep | What we change, and why |
|---|---|---|---|
| | [references/<Game>.md](references/<Game>.md) | | |

## Player fantasy and audience

- **Fantasy:** what the player gets to be or feel.
- **Audience:** age range, solo vs with friends, session length.

## Pillars

| Pillar | So we will… | So we won't… |
|---|---|---|
| | | |

## Core loop

| Timescale | Player does | Reward / feedback |
|---|---|---|
| ~30 s | | |
| 5–10 min session | | |
| Return visits | | |

## Roblox reality check

- **1 player in the server:** what happens?
- **Devices / controls:** core action on touch?
- **First 60 seconds:** what does a new player do and earn?
- **Social:** what does a friend add? Late joiners?
- **Persistence:** what state survives leaving?

## Economy

| Resource | Source (`GameConfig` key) | Sink (`GameConfig` key) | Notes |
|---|---|---|---|
| | | | |

## Monetization

Not before M1 passes. Planned items, type (game pass / developer product), and why
each is not pay-to-win.

## Riskiest assumptions

1. The core loop is fun. (Tested by M1.)
2.

## Milestones

One line per milestone; details live in `docs/design/milestones/`.

| Milestone | Goal | File |
|---|---|---|
| M1 | Prove the core loop, greybox | [M1-<name>.md](milestones/M1-<name>.md) |
| M2 | | |

## Backlog

Ideas parked for later, with the reason they're not in the current milestone.

## Decisions log

| Date | Decision | Why / who decided |
|---|---|---|
| | | |
