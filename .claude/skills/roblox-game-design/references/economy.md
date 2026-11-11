# Economy, Progression and Monetization

## Sources and sinks

Every currency or resource needs both:

- **Sources**: where it comes from (clicks, drops, rewards, daily login).
- **Sinks**: where it goes (upgrades, consumables, rebirths, cosmetics).

Keep a table in the GDD, with each row a `GameConfig` key:

| Resource | Source (`GameConfig` key) | Rate | Sink (`GameConfig` key) | Cost curve |
|---|---|---|---|---|

Sources without enough sinks cause inflation: prices stop mattering and progression
feels meaningless. Adding a source (daily reward, a boost) without a matching sink is
the usual cause.

## Diagnosing tuning requests

"Make coins drop faster so people level faster" is a symptom. Ask:

1. **Where do players stall or quit?** A specific upgrade, a time, a stage?
2. **Is it pace or clarity?** Players sometimes stall because they don't know what to
   do next, not because it's slow. That needs a UI or goal fix, not a rate fix.
3. **What's the cost?** Faster progression uses content up faster. If the game has
   2 hours of content and you double the pace, it now has 1.
4. **Smallest change**: one multiplier in `GameConfig.Economy`, applied in one place,
   so it can be reverted and A/B-reasoned about.
5. **Measure**: log the relevant transition with `TestHooks.log` (e.g. `"Upgrade"`,
   `{tier=3, elapsed=...}`) so a playtest shows whether pacing changed.

## Progression curves

- Costs usually grow faster than income (e.g. a multiplier per tier), so each tier takes
  a bit longer. Keep the formula in a pure `*Math` module so Tier 1 tests can check it.
- Put the curve's constants in `GameConfig`, never inline.
- Rebirth/prestige resets work when replaying is fast and still fun. They hurt games
  where progress *is* the content (obbies, story).

## Monetization

Only after the core loop is proven (M1 passed). Before designing any paid item:

- **No pay-to-win against other players.** Selling power that beats other players in
  PvP damages the game for everyone who doesn't pay. Prefer cosmetics, convenience
  (extra slots, auto-collect), and boosts that only affect your own solo progress.
- **Game pass** (one-time, permanent) vs **developer product** (repeatable). Pick by
  whether the purchase can happen more than once.
- **Paid random items** (crates, loot boxes for Robux) have specific policy requirements:
  odds disclosure before purchase and region restrictions checked via `PolicyService`.
  **Look up the current rules via context7 (`/roblox/creator-docs`)** before designing one.
  Consider a non-random alternative (a direct purchase) first.
- Assume a young audience: no pressure tactics (fake timers, misleading "free" prompts).
- Purchases must be granted and saved server-side before confirming the receipt.
  Route the implementation through the engineering conventions in `CLAUDE.md`.
