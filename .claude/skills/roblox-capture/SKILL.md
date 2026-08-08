---
name: roblox-capture
description: Use when you need to visually inspect an asset generator's output, an instance, or a scene in Studio — e.g. "show me what the sword looks like", "capture the treasure chest model" — by having the agent screenshot it directly instead of asking the user to look.
---

# Roblox Scene/Object Capture

Screenshots a generator's output or an existing instance via the `roblox-studio-mcp`
skill's `screen_capture` tool, so the agent can review visuals without a human
looking at the Studio window. Requires MCP set up and Studio open — see
`roblox-studio-mcp` for preconditions.

## Steps

1. **Get the instance into the scene.** Two cases:
   - **Asset generator** (`ServerStorage/AssetGenerators/**/*Generator.lua`): via
     `execute_luau` (Edit context), require the generator, call its
     `create<Name>()`, and parent the result into a scratch folder, e.g.:
     ```lua
     local scratch = workspace:FindFirstChild("AgentScratch") or Instance.new("Folder", workspace)
     scratch.Name = "AgentScratch"
     local gen = require(game.ServerStorage.AssetGenerators.Tools.SwordGenerator)
     local inst = gen.createSword()
     inst.Parent = scratch
     ```
   - **Existing instance**: use `search_game_tree`/`inspect_instance` to confirm
     the path, no scratch folder needed.
2. **Frame the camera.** Via `execute_luau`, point `workspace.CurrentCamera` at the
   instance (compute a bounding box / use `Model:GetBoundingBox()` or the part's
   `Position`, back the camera off enough to fit it, `CFrame` it to look at the
   target). For a `ScreenGui`, no camera framing is needed — it renders directly.
3. **Capture.** Call `screen_capture`.
4. **Save.** Write the image to a reviewable path — default to the caller's
   scratchpad directory, or `docs/captures/<name>.png` if the user wants it kept
   in the repo for reference (ask if unclear; don't commit binary captures without
   confirmation).
5. **Clean up.** If a scratch instance was created in step 1, destroy it
   (`inst:Destroy()` via `execute_luau`) so repeated captures don't accumulate
   leftover instances in `AgentScratch`.

## When not to use this

For verifying gameplay *behavior* (not a static look), use `roblox-playtest`
instead — this skill is for static visual review only, no Play session involved.
