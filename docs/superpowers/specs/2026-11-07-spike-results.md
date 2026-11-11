# Spike results: mechanisms for Lead mode + Trainer plugin

Date: 2026-11-07 · Claude Code CLI on macOS · run in scratch projects and a local clone of
this repo (branch `v2`). Throwaway code deleted; only these results are kept.

| Mechanism | Result | Exact command / note |
|---|---|---|
| Load a plugin for one session | ✅ works | `claude --plugin-dir <plugin-folder>` (also with `-p`). Skills appear namespaced: `<plugin-name>:<skill-name>`. |
| Enable a plugin persistently | ✅ works via CLI | `claude plugin marketplace add <repo-or-path> --scope local` then `claude plugin install <plugin>@<marketplace> --scope local`. Writes `extraKnownMarketplaces` + `enabledPlugins` to `.claude/settings.local.json` **and** installs a cached copy. Writing those settings by hand **without** the install step does **not** load the plugin. Edits to the source then need `claude plugin update <plugin>@<marketplace>` (or use `--plugin-dir` while developing). |
| Headless session | ✅ works | `claude -p "<prompt>" --output-format json` → JSON with `session_id`, `result`, `permission_denials`. |
| Resume a headless session | ✅ works | `claude -p "<prompt>" --resume <session_id> --output-format json` → same `session_id`, prior context retained. |
| Extra instructions | ✅ works | `--append-system-prompt "<text>"` is honored in `-p` mode. (Lead gets none; kept for the Trainer's own use.) |
| Studio MCP without approval prompt | ✅ works | In a fresh local clone (no `settings.local.json`): `--mcp-config .mcp.json --strict-mcp-config` + `--allowedTools "mcp__Roblox_Studio__<tool>"` → `list_roblox_studios` returned the open place ("Place1"). |
| Allow some tools, block commits | ✅ works | `--permission-mode acceptEdits --allowedTools "Bash(git status:*)" … --disallowedTools "Bash(git commit:*)" "Bash(git push:*)"` → `git status` ran; `git add … && git commit …` denied (listed in `permission_denials`), nothing committed. |
| Local `git clone` of this repo | ✅ works | `git clone --branch v2 <repo-path> <dest>` then `git remote remove origin`. (Multi-game mode, later.) |

## Consequences for the plan

- Task 9: README documents both `--plugin-dir plugins/roblox-trainer` (development, or one
  session) and the CLI install at local scope (persistent). The framework-awareness line
  points to the README; an agent may run the two CLI commands when the user asked it to
  enable the trainer.
- Task 10: `lead.sh` launches `claude -p … --output-format json --mcp-config .mcp.json
  --strict-mcp-config --permission-mode acceptEdits --allowedTools … --disallowedTools
  "Bash(git commit:*)" "Bash(git push:*)"`, storing `session_id`; `say` uses `--resume`.
  The allowed-tool list lives in `permissions/lead-profile.json`.
- `--strict-mcp-config` means the Lead sees only `.mcp.json` servers (context7, Roblox
  Studio), not the user's claude.ai connectors — desirable for reproducible runs.
- Not tested (deferred with multi-game mode): switching `rojo serve` between project
  folders with Studio connected.
