# Feature: <Name>

> Copy to `docs/design/features/<Name>.md`. The `roblox-game-design` skill writes this
> before a feature is planned or built.

## Player goal

What the player wants to do, in their words.

## Fit

- **Pillar served:**
- **Loop timescale:** 30 s / session / return visits
- **Milestone:** [M<N>-<name>](../milestones/M<N>-<name>.md)
- **Depends on:** (persistence, other features, minimum player count)

## Player flow

1. Player sees...
2. Player does...
3. Game responds with... (feedback: sound, visual, UI)

## Configuration

| `GameConfig` key | Value | Meaning |
|---|---|---|
| | | |

## State and observability

- **Attributes:** (on `Player` or the entity, e.g. `Coins`, `IsOpen`)
- **Tags:** (`TestHooks.tagInteractable` for anything the player walks up to)
- **TestHooks events:** (`TestHooks.log(category, ...)` at each meaningful transition)

## Acceptance criteria

Each criterion has an ID (`<Feature>-AC1`) and says how it's verified; a test checking it
carries the ID in its name. Copy these into `docs/TESTING.md` under the milestone.

- [ ] <Feature>-AC1 (Tier 1) ...
- [ ] <Feature>-AC2 `[playtest]` ...
- [ ] <Feature>-AC3 `[visual]` ...
- [ ] <Feature>-AC4 (manual, multiplayer) ...

## Out of scope

## Open questions
