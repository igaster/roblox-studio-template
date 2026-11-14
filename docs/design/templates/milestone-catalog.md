# Milestone catalog

> A menu of milestone types that recur across games, read by `roblox-game-design` in stage 2
> (*Milestone plan*). It is **not** a required sequence: the Lead proposes the entries that fit
> the game, skips the rest with a reason, and invents any milestone the game needs that isn't
> here. Entries are game-agnostic; the specs and plans copy from `milestone.md` and
> `milestone-plan.md`.

## How the Lead uses it

1. Read every entry. Give each a one-line verdict in the milestone proposal: **fits** (becomes a
   milestone, or merges into one), or **skip: <reason>**.
2. Start from the **required** entries, then add the **conditional** ones the game's nature
   calls for, then the **optional** ones that serve its goals (*Kinds*, below). Order them by
   *Typical order*, adjusted for dependencies and the riskiest assumption.
3. Only the next milestone gets a full spec; later ones stay one line each.
4. A game's own milestones can combine, split or rename entries. Keep the catalog ID (`G3`) in
   the GDD's *Milestones* row so the origin is traceable. IDs name the entry, not its place in
   the order: they never change when the order does.

Each entry: **Kind**, **Fits when**, **Question**, **Typical criteria** (with how each is
checked), **Depends on**, **Skip if**, and **Skipping it affects** where other entries rely on it.

## Kinds

| Kind | Meaning | Entries |
|---|---|---|
| **Required** | Never skipped | G1 core loop; G9 platform hardening (required before any external player) |
| **Conditional** | Depends on the game's nature; the Lead decides from the entry's *Skip if* | G2 persistence, G4 progression, G8 multiplayer hardening, G10 settings, G15 tuning |
| **Optional** | Safe to skip; nothing downstream needs it | G3 content, G5 replayability, G6 onboarding, G7a UI polish, G7b world look, G7c sound, G11 retention, G12 monetization, G13 launch readiness, G14 owner-requested feature |

A skipped entry gets a verdict line (`skip: <reason>`), and its *Skipping it affects* line is
checked: skipping G10 means G7c ships silent or at a fixed volume; skipping G2 rules out G11
and G12 and leaves nothing for G9 to verify on the real store.

## Typical order

A starting point, not a sequence: move steps by dependency, risk and the game's nature (a
multiplayer-by-design game does step 2 early; a game with no saves skips steps 3 and 5).

| Step | Entry | Why here |
|---|---|---|
| 1 | **G1** Core loop | Always first |
| 2 | **G8** Multiplayer hardening | Early if players share state: isolation bugs are cheapest right after G1 |
| 3 | **G2** Persistence | On the framework's mock store, unpublished |
| 4 | **G3** Content breadth | Variety once the loop is proven |
| 5 | **G4** Progression | Needs persistence and content |
| 6 | **G5** Replayability | Tiers and modes need something to repeat |
| 7 | **G15** Tuning and balance pass | Content, progression and tiers now exist, so tune them together |
| 8 | **G11** Retention | Adds screens, so it comes before UI polish |
| 9 | **G6** Onboarding | Teaches the final rules and UI, after tuning |
| 10 | **G10** Settings | Before the polish passes that need its controls |
| 11 | **G7a** UI polish | Screens have stopped changing; includes `LayoutCheck` and phone sizes |
| 12 | **G7b** World look | After UI |
| 13 | **G7c** Sound and music | After G10 (mute, volume) and verified ids |
| 14 | **G9** Platform hardening | Publish, close every deferred `[needs-published]` check, touch and real services |
| 15 | **G15** again (short) | Retune on real data if anything moved |
| 16 | **G12** Monetization | Needs a published universe and no open deferred check |
| 17 | **G13** Launch readiness | Last |
| any | **G14** Owner-requested feature | When asked; fold into an existing step if it fits |

Risk to weigh: with G9 at step 14 the real-service checks come late. The mock store and its
contract tests cover most persistence risk, and G7a runs the phone layout check earlier. A game
that wants the real round trip sooner moves G9 (or a one-save throwaway publish) forward and
sets the GDD's `Publishing` field to match.

## G1: Core loop, greybox
- **Kind:** required.
- **Fits when:** always; it is M1.
- **Question:** is the riskiest assumption fun? The smallest playable test: greybox, one of each
  thing, no monetization, no persistence unless the loop needs it.
- **Typical criteria:** the full loop works in a Play session (`[playtest]`); the design targets
  hold (Tier 1); the smoke test passes (Tier 2); **everything the player holds is visible on
  screen** (coins, seeds, items, harvested goods: read off the HUD in a Play session, not
  inferred from events), and **a player can never be stuck with no way to earn** (Tier 1: a
  state with nothing left is rescued or impossible).
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
- **Kind:** conditional.
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
- **Skipping it affects:** G4, G11 and G12 (nothing to persist or sell), the settings saved by
  G10, and the real-store checks in G9.

## G3: Content breadth
- **Kind:** optional.
- **Fits when:** the loop is proven and variety is the next risk.
- **Question:** do more items, zones, enemies or crops add real choice without breaking the
  economy?
- **Typical criteria:** each addition is data in `GameConfig`; the design targets and a balance
  run still pass (Tier 1); no addition is strictly dominant (a model or sweep).
- **Depends on:** G1.
- **Skip if:** the base content is already enough for the next milestone's question.

## G4: Progression and meta
- **Kind:** conditional.
- **Fits when:** players need a reason to return across sessions.
- **Question:** do levels, unlocks and goals pace as intended?
- **Typical criteria:** the progression curve hits its targets in a model (Tier 1); unlocks
  persist (G2); early levels arrive inside the first session (`[playtest]`).
- **Depends on:** G1, G2.
- **Skip if:** a single session is the whole game.
- **Skipping it affects:** G11 (streaks and quests need something to progress), and G5's tiers
  lose their usual reward ladder.

## G5: Replayability
- **Kind:** optional.
- **Fits when:** the base content is short and players finish it.
- **Question:** do difficulty tiers, extra stages or modes extend play, and does harder content
  pay more?
- **Typical criteria:** each tier or stage passes the design targets (Tier 1); the choice rule
  for several players is defined and tested (no vote can be griefed).
- **Depends on:** G1, usually G4.
- **Skip if:** content breadth (G3) answers the same need.

## G6: Onboarding
- **Kind:** optional (make it part of the proposal when a first-timer can't reach the first
  reward unaided).
- **Fits when:** a new player has to learn rules before the first reward.
- **Question:** can a first-timer reach the first reward without help?
- **Typical criteria:** first-time-user path timed in a Play session (`[playtest]`); every
  prompt reads at phone size (`[visual]`); a returning player is not shown it again (Tier 2).
- **Depends on:** G1; usually after G15, so it teaches the tuned rules.
- **Skip if:** the loop explains itself in one step.

## G7: Polish passes (a, b, c)

Greybox and placeholders come first (see *Placeholder rules* in G1); each pass improves them
late, after content is stable. The three are separate milestones because their dependencies
differ. Do UI before world, and sound whenever verified ids exist; place them after any
milestone that still changes the screens (content, retention).

### G7a: UI polish
- **Kind:** optional.
- **Fits when:** the screens have stopped changing and plain frames limit readability.
- **Question:** is every screen easy to read and use, on a phone too?
- **Typical criteria:** styled HUD, panels, toasts and prompts come from the GUI generators
  (rebuilt each start, Tier 2); the `LayoutCheck` dev command is wired up and passes at phone
  and desktop window sizes, and captures at both are in `docs/captures/` (`[visual]`: it runs
  unpublished, so it belongs here, not in G9); no game logic changed (Tier 1 unchanged).
- **Depends on:** G1; after the milestones that still change screens (G3, G4, G11).
- **Skip if:** the plain UI is the intended style.

### G7b: World look
- **Kind:** optional.
- **Fits when:** the loop is proven and greybox parts limit how the game reads or feels.
- **Question:** do real models, materials and lighting help the player read the world?
- **Typical criteria:** captures of each scene in `docs/captures/` (`[visual]`); a level
  generator is retired once Studio owns the art (or still rebuilds every start); every
  third-party asset id loads in a Play session (Tier 2); the design targets still pass
  (Tier 1).
- **Depends on:** G1; usually after G7a.
- **Skip if:** greybox is the intended style for the release.

### G7c: Sound and music
- **Kind:** optional.
- **Fits when:** verified or licensed asset ids exist, and the game is otherwise stable.
- **Question:** does audio give feedback the player needs, and can it be turned off?
- **Typical criteria:** every key in the `Sounds` config table has a verified id that loads in
  a Play session (Tier 2); the game still works muted (Tier 2, `TestAudio`); mute and volume
  are saved (see G10).
- **Depends on:** G1; G10 for the controls.
- **Skip if:** the game ships silent by design.

## G8: Multiplayer hardening
- **Kind:** conditional.
- **Fits when:** more than one player shares state, a board or a match.
- **Question:** do two or more players stay isolated where they should, and in sync where they
  should?
- **Typical criteria:** per-player state is cleaned on leave (Tier 2); rules for several players
  are pure `*Rules` modules (Tier 1); a two-client Studio test (manual) until a test bot exists
  (`docs/TODO.md`).
- **Depends on:** G1.
- **Skip if:** players never affect each other or share an object.

## G9: Platform hardening
- **Kind:** required before any external player (a private test bed that never leaves the team
  may defer it, and says so in `STATUS.md`).
- **Fits when:** before showing the game to anyone outside the team.
- **Question:** does it work on touch and on the real services? (The phone layout check is G7a.)
- **Typical criteria:** touch paths work (manual); the game is published (or a throwaway staging
  place is, built with `rojo build`), then every deferred `[needs-published]` check runs: the
  real DataStore round trip (save, leave, rejoin) and `StoreContract.basic` on the real store
  wrapper (manual); Output has no errors in a clean Play session (Tier 2); owner checks left
  open by earlier milestones are closed or recorded; *Deferred checks* in `STATUS.md` is empty.
  If the GDD's `Publishing` field sets a later milestone, this one moves with it.
- **Depends on:** G1; G2 if the game saves; usually after the polish passes, so it verifies
  the game as it will ship.
- **Skip if:** never for a game with outside players; schedule it before launch at the latest.

## G10: Settings and accessibility
- **Kind:** conditional.
- **Fits when:** the game has sound, motion, flashing effects or a dense UI.
- **Question:** can a player tune it to their device and comfort?
- **Typical criteria:** volume or mute, UI size and reduced motion apply at once (Tier 2) and
  are saved (G2).
- **Depends on:** G1; G2 to save.
- **Skip if:** none of those apply.
- **Skipping it affects:** G7c: without mute and volume controls the game ships silent or at a
  fixed volume.

## G11: Retention
- **Kind:** optional.
- **Fits when:** the core is stable and return visits are the goal.
- **Question:** do streaks, quests or earned cosmetics bring players back, without punishing a
  missed day?
- **Typical criteria:** rewards are server-validated and rate-limited (Tier 1); nothing is
  gated behind a real-money purchase unless G12 allows it.
- **Depends on:** G2, G4; before the UI polish (G7a), since it adds screens.
- **Skip if:** the owner wants no daily mechanics.

## G12: Monetization
- **Kind:** optional.
- **Fits when:** the owner has opted in. Always late.
- **Question:** do cosmetic or convenience items sell without hurting fairness?
- **Typical criteria:** every purchase is processed server-side, granted once and survives
  rejoin (Tier 1, Tier 2); a Robux item is a cosmetic variant of something earned, unless the
  GDD says otherwise; the no-monetization test is replaced by a test for the allowed items.
- **Depends on:** G2, G9; needs a published universe, so no deferred check may still be open.
- **Skip if:** the owner says no real-money features.

## G13: Launch readiness
- **Kind:** optional.
- **Fits when:** before publishing publicly.
- **Question:** is the game safe to release and easy to roll back?
- **Typical criteria:** icon, thumbnail and description ready; Roblox policy and rating checks
  done (manual); every asset licensed or owned; a known-problems list reviewed; `STATUS.md`
  current; no game file other than `DataService.lua` and `SmokeTest.lua` mentions the mock
  store (`tests/framework.lua` checks); no external players before G9 passed.
- **Depends on:** G9.
- **Skip if:** the game is a private test bed.

## G14: Owner-requested feature or quality-of-life change
- **Kind:** optional (only when asked).
- **Fits when:** the loop is proven and the owner (or a playtest) asks for something that is
  not a new content type or polish pass: speed controls, free placement, a results report, a
  new upgrade sink. These come one at a time and make up a large share of a long-running game.
- **Question:** does this change what the player does, in the way the owner expects, without
  breaking the numbers other systems rely on?
- **Typical criteria:** the request is restated as one or two acceptance criteria the owner
  confirms (`[playtest]`); no gameplay number moves unless the spec says so (a balance run
  reports zero changed values, Tier 1); the HUD shows anything new the player holds or can do
  (see G1); a feature spec exists even when the milestone is small.
- **Depends on:** G1; whatever the request touches.
- **Skip if:** the request fits an existing milestone: fold it in instead of adding one.

## G15: Tuning and balance pass
- **Kind:** conditional.
- **Fits when:** numbers drive the experience (difficulty, progression, economy, pacing) and
  content has stopped growing for now. Schedule it after content milestones (G3, G4, G5) and
  before polish (G7) and monetization (G12), once more (short) after G9 if real data moved
  anything, and again whenever a later milestone moves numbers a lot. A small retune inside another milestone uses the same ladder as a task
  (`milestone-plan.md`, *Tuning task*).
- **Question:** do the design targets hold, and does a player at each stage meet the intended
  pacing and difficulty, in the model and with real players?
- **The ladder** (cheapest first; stop climbing when the answer is clear):
  1. **Diagnose:** the player problem, the source and sink in the economy, the cost, one knob
     in `GameConfig` (`roblox-game-design`, section C).
  2. **Targets as claims:** every design target (DT ID) is a Tier 1 check over the `*Math`
     modules and `GameConfig`, and every balance decision is a checkable claim citing where it
     is recorded (`roblox-test`; `tests/lib/balance/Claims`).
  3. **Model or simulation:** run scenarios over the matrix (level × difficulty × players ×
     persona), read the outcome metrics, diff against the baseline (`roblox-game-modeling`;
     `make balance`). Check the persona first if an option's ablation is negative.
  4. **Recorded sessions:** play it, export `SessionRecorder` sessions stamped with the config,
     and compare their pacing with the simulation's. Recordings show what happened, not why:
     ask the player (`roblox-playtest`, *Recording sessions*).
  5. **Owner playtest** for feel (`[playtest]`): the one thing the first four can't answer.
  6. **Record it:** each decision as a claim and in `docs/decisions/`; baseline refreshed;
     *Deferred checks* updated if a check needs a published place.
- **Typical criteria:** every DT passes (Tier 1); `make balance` reports no failing claims and
  the baseline diff is reviewed line by line (Tier 1); a table of before and after values for
  each knob changed, with the reason; recorded sessions at each stage within the model's
  tolerance, or the gap explained (`[playtest]`); the owner confirmed the feel at the
  extremes (first session, a late stage, the hardest setting).
- **Depends on:** G1; the content it tunes (G3, G4, G5).
- **Skip if:** the game has no numbers to balance (outcomes don't reduce to numbers: say so in
  the proposal), or the balance model's tools aren't built yet and one playtest answers it.

## Adding to the catalog

Add an entry when a second game needs the same milestone type. Keep it generic: no game names
in the entry. Review the catalog together with the milestone and plan templates after each
game's first milestone planned from it (`docs/TODO.md`).
