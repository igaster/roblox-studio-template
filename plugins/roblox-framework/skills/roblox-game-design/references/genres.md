# Common Roblox Genres

Genre conventions are shared territory: players expect them, and using them is not
copying. Use this to recognise a genre, ask the right questions, and spot pitfalls.
For a specific reference game, run `roblox-game-teardown` instead.

| Genre | Core loop | Players expect | Typical pitfalls |
|---|---|---|---|
| **Obby** | Jump a section → checkpoint → next stage | Checkpoints, stage counter, skip-stage purchase, timer | Unfair jumps; long walk back after failing; content runs out fast |
| **Tycoon** | Collect income → buy the next dropper/upgrade → base grows | A personal plot, visible base growth, rebirth | Long dead waits between purchases; no reason to return once complete |
| **Simulator** (click/collect) | Collect → sell → upgrade capacity/speed → new area | Pets/helpers, areas gated by currency, rebirths | Pure number inflation; the 30-second action isn't fun on its own |
| **Grow / idle** | Plant/start → wait → harvest → sell → better seeds/upgrades | Offline progress, timers, rare variants | Waiting with nothing to do; persistence bugs lose progress |
| **Tower defense** | Place/upgrade units → survive waves → earn → unlock units | Unit collection, waves, co-op | Balance breaks with paid units; needs several players or good solo scaling |
| **Round-based / party** | Lobby → round with roles or a challenge → results → lobby | Short rounds, varied maps/modes, spectating | Empty servers can't start a round; mid-round joiners wait too long |
| **Fighting / battlegrounds** | Fight → earn → unlock moves/characters | Responsive combat, combos, ranking | Latency feel; paid power ruins PvP; balance load |
| **Roleplay / life sim** | Pick a role → socialise → customise home/vehicle | Houses, jobs, vehicles, avatar items | Little structured goal; depends on populated servers |
| **Horror / story** | Explore → solve → survive → chapter end | Atmosphere, chapters, co-op with friends | Content consumed once; needs regular chapter updates |

## Questions to ask per genre

- **Loop-first genres** (obby, simulator, tower defense, fighting): is the 30-second action
  fun with greybox art and no progression?
- **Wait-based genres** (tycoon, grow/idle): what does the player do *while* waiting?
- **Population-based genres** (round-based, roleplay, PvP): what happens with 1–2 players
  in the server? (See `roblox-platform.md`.)
- **Content-consumed genres** (obby, horror/story): how fast can new content be made,
  and does it need the generator pattern to scale?
- **Wave-based genres** (tower defense, survival): track each wave on its own from the start
  (enemies carry their wave number; each wave clears, pays and counts separately). A loop that
  blocks until a wave is cleared bakes in "one wave at a time", and "call the next wave early",
  which players expect, then means reworking the payouts, the victory check, the sim and the
  tests.
