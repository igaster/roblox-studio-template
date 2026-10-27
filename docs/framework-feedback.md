# Framework Feedback Log

Friction found while building the game with this framework. Append entries as they
happen. They're reviewed at each milestone retro and turned into `framework:` commits.

Format: `- YYYY-MM-DD [area] what happened → suggested fix (status: open | fixed in <sha>)`

## Entries
- 2026-10-27 [testing] `tests/suite.lua` and `SmokeTest.lua` told games to edit them in place, so every game's tests conflicted with framework updates → auto-discover `tests/specs/*.spec.lua` and `ServerScriptService/SmokeTests/*` (status: fixed in M1 T0)
- 2026-10-27 [workflow] Empty `.gitkeep` folders (e.g. `ServerScriptService/Classes/`) don't appear in `rojo sourcemap`, so a sourcemap check can't confirm a new folder is wired up until it has a module → note in CLAUDE.md "verify with sourcemap" tip (status: open)
- 2026-10-27 [testing] In Edit mode, `require()` from `execute_luau` returns the cached copy of a module that was required earlier in the session, even after Rojo synced new source, so Tier 2 silently ran the old `SmokeTest` → roblox-test skill should say: run Tier 2 in a fresh Play session (Server datamodel), or require a `:Clone()` of the module (status: fixed in M1, roblox-test skill)
- 2026-10-27 [observability] `TestHooks.getEvents()` called via `execute_luau` (Server) only saw events logged by that same execute_luau context, never the running game's: MCP code gets a separate require cache, so it has its own module copy and buffer. The documented "read back via execute_luau" pattern silently returned nothing from the game → the first server copy now owns the buffer and shares it through a non-archivable `ServerStorage.TestHooksBridge` BindableFunction (status: fixed in M1)
- 2026-10-27 [observability] Following the convention "log every meaningful transition" with `TestHooks.log` floods the Output window (one line per enemy kill), drowning the signal it's meant to surface → add a quiet option (record without printing) or per-category print filtering to `TestHooks.log` (status: fixed in M2 T0, `TestHooks.setQuiet`)
- 2026-10-27 [observability] TestHooks' single 500-event ring buffer is shared by all categories, so quiet high-volume events (kills) evict the rare important ones (player decisions) within a few waves. Also, nothing survives Play stopping, so a session that ends before the agent reads it is lost → per-category caps (or never evict non-quiet categories first), plus a session recorder for decisions (decision 0008, M3) (status: open)
- 2026-10-27 [observability] Saving a recorded session means the agent re-emits the exported JSON (returned in the `execute_luau` result) into a file: fine at ~15 KB per 29-wave session, but costly for long or multi-player sessions → look for a channel that doesn't round-trip through the agent (e.g. a Studio plugin writing files, or chunked export plus a local receiver) (status: open)
