---
description: Run one milestone — spec, approval, plan, build, verify, retro.
argument-hint: <milestone number or name, e.g. M2>
---

Run milestone $ARGUMENTS following the spec-driven workflow in `CLAUDE.md`.

Never start a milestone the user hasn't explicitly confirmed.

## 1. Spec (approval checkpoint)
- If `docs/design/milestones/M<n>-*.md` doesn't exist, create it from
  `docs/design/templates/milestone.md`, based on the GDD roadmap and the previous
  milestone's retro.
- Every acceptance criterion must be observable and name its verification tier.
- **Stop and get the user's approval** of the spec (they may edit it). Set status `Approved`.

## 2. Plan
- Fill in the spec's Plan (exact file paths, new `GameConfig` keys, remotes, attributes,
  TestHooks events) and Tasks (`T1…`). Each task should be small enough to verify on
  its own.
- If the plan surfaces a real design choice, ask before you build. Record the answer in
  `docs/decisions/`.

## 3. Build
- Work through the tasks in order, ticking them off in the spec as you go.
- Follow `CLAUDE.md` conventions: config in `GameConfig`, pure math in `Modules/`,
  server authority, validated remotes, `TestHooks` tags and logs.
- Run Tier 1 (`make test`) after every logic change.
- Log framework friction to `docs/framework-feedback.md` when it happens.

## 4. Verify
- Run Tier 2 (smoke test via MCP), and use `roblox-playtest` for `[playtest]` criteria.
- Fill in "Verification results" with evidence per AC (test output, TestHooks events,
  screenshots).
- Add this milestone's section to `docs/TESTING.md` (Tier 3), marking `[playtest]`,
  `[visual]`, and manual items.
- Report which ACs pass, which fail, and which **need the user** (feel, fun, visuals,
  multiplayer). Don't claim a criterion passed without evidence.

## 5. Retro (approval checkpoint)
- After the user has playtested, fill in the Retro: their feedback, what carries over,
  and the framework friction to fix.
- Propose `framework:` fixes for the logged friction as separate commits.
- Mark the milestone `Done`, update the GDD roadmap, and propose the next milestone.
  **Stop** and wait for confirmation before starting it.
