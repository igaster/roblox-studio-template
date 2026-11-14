# Milestone catalog

> A menu of milestone types that recur across games, read by `roblox-game-design` in stage 2
> (*Milestone plan*). It is **not** a required sequence: the Lead proposes the entries that fit
> the game, skips the rest with a reason, and invents any milestone the game needs that isn't
> here. Entries are game-agnostic; the specs and plans copy from `milestone.md` and
> `milestone-plan.md`.

## How the Lead uses it

1. Read every entry. Give each a one-line verdict in the milestone proposal: **fits** (becomes a
   milestone, or merges into one), or **skip: <reason>**.
2. Order the ones that fit as the skill says: dependencies first, then the riskiest assumption,
   then content, then monetization.
3. Only the next milestone gets a full spec; later ones stay one line each.
4. A game's own milestones can combine, split or rename entries. Keep the catalog ID (`G3`) in
   the GDD's *Milestones* row so the origin is traceable.

Each entry: **Fits when**, **Question**, **Typical criteria** (with how each is checked),
**Depends on**, **Skip if**.

## G1: Core loop, greybox
- **Fits when:** always; it is M1.
- **Question:** is the riskiest assumption fun? The smallest playable test: greybox, one of each
  thing, no monetization, no persistence unless the loop needs it.
- **Typical criteria:** the full loop works in a Play session (`[playtest]`); the design targets
  hold (Tier 1); the smoke test passes (Tier 2).
- **Depends on:** nothing.
- **Skip if:** never.
- **Placeholder rules (every milestone until its G7 pass):** build so that polish later changes
  data and generators, not game logic.
  - UI: functional and readable; plain frames and text, one shared layout helper, no
    hardcoded sizes.
  - Looks: greybox parts (`shared/Greybox.lua`); colors in `GameConfig` as plain tables.
  - Sound: a `Sounds` table in `GameConfig` with every key present and the id empty, played
    through one helper; a missing id means silence, and the game works muted.

## G2: Persistence and return
- **Fits when:** progress must survive leaving, or the selling point is about coming back.
- **Question:** does saving and loading follow the Persistence rules, and does the return feel
  right? Built and checked on the framework's mock store (`MockDataStore`, `StoreContract`),
  unpublished: the real round trip is deferred to G9 (`[needs-published]`).
- **Typical criteria:** a loaded profile gates every reward (Tier 1, on the mock store);
  a failed load never overwrites a real save (Tier 1, `failNext`); retry and throttling
  (Tier 1, `throttle`); schema version and a migration (Tier 1); a lost update from another
  server is handled (Tier 1, `interleave`); a cross-server session lock, designed and tested
  with `interleave` (a library such as ProfileStore is an option, see `docs/TODO.md`); the
  contract run on the game's real store wrapper at G9 (`[needs-published]`).
- **Depends on:** G1.
- **Skip if:** the game is session-only by design.

## G3: Content breadth
- **Fits when:** the loop is proven and variety is the next risk.
- **Question:** do more items, zones, enemies or crops add real choice without breaking the
  economy?
- **Typical criteria:** each addition is data in `GameConfig`; the design targets and a balance
  run still pass (Tier 1); no addition is strictly dominant (a model or sweep).
- **Depends on:** G1.
- **Skip if:** the base content is already enough for the next milestone's question.

## G4: Progression and meta
- **Fits when:** players need a reason to return across sessions.
- **Question:** do levels, unlocks and goals pace as intended?
- **Typical criteria:** the progression curve hits its targets in a model (Tier 1); unlocks
  persist (G2); early levels arrive inside the first session (`[playtest]`).
- **Depends on:** G1, G2.
- **Skip if:** a single session is the whole game.

## G5: Replayability
- **Fits when:** the base content is short and players finish it.
- **Question:** do difficulty tiers, extra stages or modes extend play, and does harder content
  pay more?
- **Typical criteria:** each tier or stage passes the design targets (Tier 1); the choice rule
  for several players is defined and tested (no vote can be griefed).
- **Depends on:** G1, usually G4.
- **Skip if:** content breadth (G3) answers the same need.

## G6: Onboarding
- **Fits when:** a new player has to learn rules before the first reward.
- **Question:** can a first-timer reach the first reward without help?
- **Typical criteria:** first-time-user path timed in a Play session (`[playtest]`); every
  prompt reads at phone size (`[visual]`); a returning player is not shown it again (Tier 2).
- **Depends on:** G1.
- **Skip if:** the loop explains itself in one step.

## G7: Polish passes (a, b, c)

Greybox and placeholders come first (see *Placeholder rules* in G1); each pass improves them
late, after content is stable. The three are separate milestones because their dependencies
differ. Do UI before world, and sound whenever verified ids exist; place them after any
milestone that still changes the screens (content, retention).

### G7a: UI polish
- **Fits when:** the screens have stopped changing and plain frames limit readability.
- **Question:** is every screen easy to read and use, on a phone too?
- **Typical criteria:** styled HUD, panels, toasts and prompts come from the GUI generators
  (rebuilt each start, Tier 2); captures at phone and desktop sizes in `docs/captures/`
  (`[visual]`); `LayoutCheck` passes; no game logic changed (Tier 1 unchanged).
- **Depends on:** G1; G9 for the layout check.
- **Skip if:** the plain UI is the intended style.

### G7b: World look
- **Fits when:** the loop is proven and greybox parts limit how the game reads or feels.
- **Question:** do real models, materials and lighting help the player read the world?
- **Typical criteria:** captures of each scene in `docs/captures/` (`[visual]`); a level
  generator is retired once Studio owns the art (or still rebuilds every start); every
  third-party asset id loads in a Play session (Tier 2); the design targets still pass
  (Tier 1).
- **Depends on:** G1; usually after G7a.
- **Skip if:** greybox is the intended style for the release.

### G7c: Sound and music
- **Fits when:** verified or licensed asset ids exist, and the game is otherwise stable.
- **Question:** does audio give feedback the player needs, and can it be turned off?
- **Typical criteria:** every key in the `Sounds` config table has a verified id that loads in
  a Play session (Tier 2); the game still works muted (Tier 2, `TestAudio`); mute and volume
  are saved (see G10).
- **Depends on:** G1; G10 for the controls.
- **Skip if:** the game ships silent by design.

## G8: Multiplayer hardening
- **Fits when:** more than one player shares state, a board or a match.
- **Question:** do two or more players stay isolated where they should, and in sync where they
  should?
- **Typical criteria:** per-player state is cleaned on leave (Tier 2); rules for several players
  are pure `*Rules` modules (Tier 1); a two-client Studio test (manual) until a test bot exists
  (`docs/TODO.md`).
- **Depends on:** G1.
- **Skip if:** players never affect each other or share an object.

## G9: Platform hardening
- **Fits when:** before showing the game to anyone outside the team.
- **Question:** does it work on a phone, on touch, and on the real services?
- **Typical criteria:** layout checked at phone and desktop sizes with `LayoutCheck`
  (`[visual]`); touch paths work (manual); the game is published (or a throwaway staging
  place is, built with `rojo build`), then every deferred `[needs-published]` check runs: the
  real DataStore round trip (save, leave, rejoin) and `StoreContract.basic` on the real store
  wrapper (manual); Output has no errors in a clean Play session (Tier 2); owner checks left
  open by earlier milestones are closed or recorded; *Deferred checks* in `STATUS.md` is empty.
  If the GDD's `Publishing` field sets a later milestone, this one moves with it.
- **Depends on:** G1; G2 if the game saves.
- **Skip if:** never; schedule it before launch at the latest.

## G10: Settings and accessibility
- **Fits when:** the game has sound, motion, flashing effects or a dense UI.
- **Question:** can a player tune it to their device and comfort?
- **Typical criteria:** volume or mute, UI size and reduced motion apply at once (Tier 2) and
  are saved (G2).
- **Depends on:** G1; G2 to save.
- **Skip if:** none of those apply.

## G11: Retention
- **Fits when:** the core is stable and return visits are the goal.
- **Question:** do streaks, quests or earned cosmetics bring players back, without punishing a
  missed day?
- **Typical criteria:** rewards are server-validated and rate-limited (Tier 1); nothing is
  gated behind a real-money purchase unless G12 allows it.
- **Depends on:** G2, G4.
- **Skip if:** the owner wants no daily mechanics.

## G12: Monetization
- **Fits when:** the owner has opted in. Always late.
- **Question:** do cosmetic or convenience items sell without hurting fairness?
- **Typical criteria:** every purchase is processed server-side, granted once and survives
  rejoin (Tier 1, Tier 2); a Robux item is a cosmetic variant of something earned, unless the
  GDD says otherwise; the no-monetization test is replaced by a test for the allowed items.
- **Depends on:** G2, G9; needs a published universe, so no deferred check may still be open.
- **Skip if:** the owner says no real-money features.

## G13: Launch readiness
- **Fits when:** before publishing publicly.
- **Question:** is the game safe to release and easy to roll back?
- **Typical criteria:** icon, thumbnail and description ready; Roblox policy and rating checks
  done (manual); every asset licensed or owned; a known-problems list reviewed; `STATUS.md`
  current; no game file other than `DataService.lua` and `SmokeTest.lua` mentions the mock
  store (`tests/framework.lua` checks); no external players before G9 passed.
- **Depends on:** G9.
- **Skip if:** the game is a private test bed.

## Adding to the catalog

Add an entry when a second game needs the same milestone type. Keep it generic: no game names
in the entry. Review the catalog together with the milestone and plan templates after each
game's first milestone planned from it (`docs/TODO.md`).
