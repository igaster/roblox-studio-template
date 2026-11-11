# Framework coverage

Which framework areas each training run actually exercised. Use it two ways:
- **Choosing the next game:** suggest a scenario that hits the emptiest rows. A framework only
  tested on what games happened to need has untested advice everywhere else.
- **Harvesting:** an area with no runs is a reason to keep watching, not proof the guidance is
  fine.

`framework-review` copies this template to `coverage.md` on first use (local only, like the
rest of the ledger) and adds one column per run, e.g. `001 <game>`.

**Marks:**
- `●`: built and verified in the run.
- `◐`: touched, but verified only partly or by reading.
- blank: not exercised.

| Area |
|---|
| Greybox level generator, lighting |
| Model/part generators |
| HUD (ScreenGui) |
| World-space UI (BillboardGui/SurfaceGui) |
| ProximityPrompt interactions |
| Tools (equip, activate) |
| Character movement abilities |
| NPC / enemy AI, pathing |
| Waves, spawning, many entities |
| Projectiles, server hit detection |
| Economy (cash, buy, sell, upgrade) |
| Persistence (DataStore, migration) |
| Multiplayer verified with 2 or more clients |
| Match loop, rounds, reset |
| Late join, leave and rejoin |
| Audio (third-party assets) |
| Client-only effects (particles, flashes) |
| Balance simulation (headless) |
| Mobile and touch layout verified |
| Monetization (game passes, products) |
| Teleports, multiple places |
| Physics, vehicles, constraints |
| Animations |
| Chat, social features |
| Real art pass (Studio-owned assets) |
| Live-ops (events, timed content) |
