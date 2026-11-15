# Level design: suggestions for generated levels

Read when building or changing a level generator. **All of this is suggestion, not rule.** It is
the best current advice from level-design writing and Roblox's own greybox tutorials, and a game
whose design calls for something else should do that and note why in the feature spec. The one
firm rule that applies to levels (rebuild on every server start, never "build if missing") is in
`SKILL.md`.

Sources are named so you can judge them; most are practitioner writing, and the Roblox pages are
the strongest.

## A suggested order

1. **Write the assumptions down.** What should the player do here, what should they feel, what
   will they find hard? Writing it first makes a playtest mean something: you log where players
   did something else.
2. **Fix the metrics.** Player size, door and corridor widths, jump reach, in
   `GameConfig.Metrics` (below). Game scale isn't real-world scale; a level built from real
   architecture feels too big and confusing ([Level Design Book, metrics](https://book.leveldesignbook.com/process/blockout/metrics)).
3. **Block out large to small.** Masses first (rooms, the route, the big shapes), details last,
   since changing a blockout is cheap and changing a detailed level is not ([Lemnis Gate write-up](https://ratloopgamescanada.com/dev-blog/greyboxing)).
4. **Check that it reads.** Capture the spawn view and the main routes (`roblox-capture`). A
   readable level uses simple shapes in distinct, memorable groups. Walk it once without
   thinking: is the way forward obvious within about 30 seconds?
5. **Playtest, then dress.** Add art and detail only once the blockout works. Roblox's own
   curriculum greyboxes first for this reason, and ends with deleting the greybox and Baseplate
   when final art replaces them ([Greybox your environment](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/greybox-your-environment)).

## Metrics

`GameConfig.Metrics` holds the sizes; `Shared.LevelMetrics` derives from them. The template ships
starting values for the default R15 avatar (approximate: measure your own avatar and movement).

```lua
local LevelMetrics = require(ReplicatedStorage.Shared.LevelMetrics)
local M = GameConfig.Metrics

local gap = LevelMetrics.snap(M, LevelMetrics.maxGap(M)) -- the widest gap worth building
local door = Vector3.new(M.DoorWidth, M.DoorHeight, 1)
local wall = LevelMetrics.snap(M, 37) -- pieces sized and placed in multiples of GridSize
```

- **Fair gaps and ledges.** `maxGap` is the running-jump distance minus `SafetyMargin`, so a player
  who isn't perfect still clears it; `maxLedge` is the same for a jump up. A level that needs more is
  asking for a pixel-perfect jump, which may be what you want (say so).
- **A grid.** `GridSize` (the template uses 5 studs, the snapping Roblox's laser-tag tutorial
  uses) keeps pieces lining up. Code places things exactly, so a generator that snaps its sizes
  needs no snapping tool.
- **Check the numbers hold together.** The template's `WorldRules.spec.lua` runs
  `LevelMetrics.validate` (a door shorter than the player, a step as tall as a jump). If your game
  changes gravity or movement, change the metrics, not the level.

## Helping the player find the way

- **Landmarks and sightlines do the work.** A landmark the player actually notices while
  playing orients them; decoration that doesn't, doesn't ([Level Design Book, composition](https://book.leveldesignbook.com/process/blockout/massing/composition)).
  One landmark visible from each decision point goes a long way.
- **Leading lines are overrated on their own.** The same book is skeptical of them, and Unity's
  level-design guide says a line guides only when the player has a real choice to make ([Unity](https://unity.com/blog/level-design-basics)).
  Use them where the player must choose.
- **Fix confusion with the world, not text.** A platformer team whose players kept getting lost
  fixed it with brightly coloured flags along the route ([PocketGamer.biz](https://www.pocketgamer.biz/next-level-game-dev-analytics-using-heatmaps-in-midcore-games)).
  An accent colour from `World.Palette` on the way forward is the same idea.
- **Show, don't tell.** Direct instruction tends to work worse than cues in the level, and long
  tutorials cost players ([Wayline](https://www.wayline.io/blog/tutorials-as-onboarding-level-design)).

## Pacing and difficulty

- **Teach, then test.** Introduce a mechanic where failing is cheap, then use it where failing
  costs something ([obby design guide](https://www.creation.dev/blog/roblox-obby-design-guide)).
- **Start easy.** Keeping the first few stages nearly flat lets most players reach the first
  checkpoint and want to continue.
- **Checkpoints set the stakes.** Too dense and the tension goes; too sparse and a fall is
  punishing. Place them after a hard section, not inside one.
- **Vary the intensity.** A run of equally hard sections tires players; a breather before and
  after a peak makes the peak land.

## Spawns and checkpoints (Roblox)

- Roblox's default spawn behavior can fight a checkpoint system. A dedicated spawn per section,
  with the player's `RespawnLocation` set from their progress, is the usual approach
  ([DevForum](https://devforum.roblox.com/t/how-do-i-make-obby-spawn-points/1742814)). `Greybox.spawn`
  builds the level's first spawn and disables any other, such as the place file's.
- Give a spawn more than one exit and keep it out of a line of fire.

## Multiplayer maps

Only if the game is competitive; skip for solo or cooperative levels. Treat as information.

- **Lanes and chokepoints** control flow and pacing; two or three routes between the sides is a
  common starting point ([Mind Studios](https://themindstudios.com/blog/multiplayer-level-design-techniques)).
- **Symmetry guarantees fair starts but reduces variety.** A mirrored objective with different
  routes keeps some of both.
- **Exposed rewards create risk and reward;** a safe placement can carry its own cost, such as
  lost momentum ([forum post](https://sm.mania.exchange/s/ft/402)).
- **Spawn safety** is server logic: pick a spawn away from enemies at the time of spawning.

## Looking at the result

An agent can't feel flow, so measure what it can:

- **Look.** Capture from the spawn view, along the main route, and from above. Ask: can I see
  where to go? Which shapes read, and which vanish?
- **Measure.** Every gap at or under `LevelMetrics.maxGap`, every doorway at `DoorWidth` or wider,
  every ledge at or under `maxLedge`, unless the level means to demand more.
- **Walk it.** In a Play session, move the character along the route (`roblox-playtest`) and
  confirm each objective is reachable.

Two ideas that need more machinery, worth building only when a game has the problem they solve,
and not verified here: a pathfinding check (`PathfindingService` from the spawn to each objective),
and recording where players die and stall with `SessionRecorder` (a "death map" shows hard spots;
players rarely say a section is too hard, they keep dying there).

## Writing the generator

- One `build()` with a fixed home; rebuild every server start (firm).
- Read sizes from `GameConfig.Metrics`, colours from `GameConfig.World.Palette`; no raw numbers.
- Make the landmark and the route accent obvious in the code, so a later edit keeps them.
- Retire the generator when real art takes over: delete the greybox and the Baseplate.
