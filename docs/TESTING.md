# Testing Guide

Three tiers of checks, from automatic → manual. See the **Testing** section of
`CLAUDE.md` and the `roblox-test` skill for Tier 1 (headless Lune unit tests) and
Tier 2 (in-engine smoke test) — how to run them and when. This doc covers Tier 3,
the manual playtest checklist, which lives only here.

---

## Tier 3 — Manual playtest checklist

Inside Studio (`make serve` → Rojo connect → **Play**). For everything Tier 1/2
automation can't catch. Not every item here needs a human, though — split by what
the `roblox-playtest` skill (MCP-driven) can cover:

- **Single-player UI/input items** — delegate to `roblox-playtest`. Mark these
  `[playtest]` below; the agent can run them via a real MCP-driven Play session
  instead of asking you to click through them.
- **Visual review items** — `roblox-playtest`/`roblox-capture` can pull a
  screenshot for the agent to judge, but there's no baseline-diff tooling here,
  so treat it as a judgment call, not a hard pass/fail. Mark these `[visual]`;
  still worth a human glance for anything subjective.
- **Multiplayer isolation items** — **stay fully manual**, unmarked. MCP drives
  one Studio session with one input stream; it cannot spin up a second real
  client. Don't mark these `[playtest]`.

Add one section per milestone as it completes. Example structure:

### M1 — <milestone name> (single player)
- [ ] `[playtest]` ...
- [ ] `[visual]` ...

### M1 — Multiplayer isolation (Play → 2 players)
- [ ] Each player gets their **own** isolated state.
- [ ] Player A **cannot** affect player B's state.
- [ ] Leaving cleans up that player's instances (no orphans in the workspace).

### General (every playtest)
- [ ] `[playtest]` **Output panel: zero errors/warnings** during normal gameplay.
- [ ] No stalls/lag under load.

> Add new sections (M2, M3, ...) as milestones complete.
