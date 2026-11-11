# Roblox Platform Reality Check

Run this checklist during a design session (mode A, step 4) and for any feature that
depends on other players. Each item is a question to put to the creator, not a rule.

Platform facts change. For anything policy- or number-related, look it up with
context7 (`/roblox/creator-docs`) instead of quoting from memory.

## Population: does the loop survive an empty server?

Most experiences spend most of their life with few concurrent players, and servers
fill unevenly. A loop that *needs* N live players is the most common design trap.

- What happens with **1 player** in the server? With 2?
- Live PvP/co-op → offer a fallback: **async play** (fight saved teams, race ghost
  replays, leaderboards), **bots/NPCs**, or a solo mode that is fun on its own.
- Matchmaking across servers (TeleportService, reserved servers) adds real complexity.
  Treat it as a later milestone, not M1.

## Devices: mobile first

A large share of players are on phones and tablets, and many on gamepads.

- Can the core action be done with **one thumb** and large touch targets?
- Does the UI fit a small landscape screen without covering the play area?
- No mechanic that needs hover, right-click, or many hotkeys.

## First 60 seconds

Players decide almost instantly whether to stay.

- The player **does the core action within seconds** of spawning: no menus, no text walls.
- Teach by doing (an arrow, a glowing target), not by explaining.
- The first reward lands in the first minute.

## Social

Players often arrive with friends, and joining a friend is a main way people find games.

- What does playing **with a friend** add? Can friends see and help each other?
- How does a **late joiner** catch up or contribute immediately?
- Is there something worth showing off (cosmetics, titles, leaderboards)?

## Sessions and servers

- Sessions are short and interrupted. Can a meaningful goal fit in 5–10 minutes?
- Progress that should survive leaving needs persistence (DataStores) from the start.
  Plan which state persists.
- Round-based vs. persistent-world: what happens to someone who joins mid-round?

## Audience and safety

- Assume a young audience unless the experience targets older players.
- Chat, trading and user-generated text have safety and policy implications. Flag them early.
