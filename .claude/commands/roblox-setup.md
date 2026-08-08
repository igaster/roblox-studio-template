Set up this Roblox game project from scratch. Follow these steps in order, reporting progress after each one.

## Step 1 — Check toolchain (Rojo, Lune)

Run `rojo --version` and `lune --version` in PowerShell.

- If both are already installed (any version): note the versions, skip to Step 3.
- If either is missing: proceed to Step 2.

## Step 2 — Install Rokit + toolchain

Rokit is only needed if Rojo or Lune is not already installed.

1. Pause and tell the user: "Rojo/Lune is not installed. Please install Rokit from https://github.com/rojo-rbx/rokit/releases/latest, then run `! rokit --version` to confirm it works."
2. Wait for user confirmation.
3. Run `rokit install` to install Rojo and Lune via `rokit.toml`.

## Step 3 — Install Rojo Studio Plugin

Run: `rojo plugin install`

This installs the Rojo plugin into Roblox Studio.

## Step 4 — Verify headless tests run

Run: `lune run tests/suite.lua`

This confirms Lune resolved correctly and the Tier 1 test harness works out of the
box. Report the pass/fail summary; if it fails, stop and debug before continuing.

## Step 5 — Name the game

Ask the user: "What should the game be named?"

Wait for their answer, then update `default.project.json` — replace the value of the top-level `"name"` field with the user's answer.

## Step 6 — Start the Rojo server

Run the server in a new window so the terminal stays free:

```powershell
Start-Process -FilePath "rojo" -ArgumentList "serve", "default.project.json" -WindowStyle Normal
```

The server listens on `localhost:34872`.

## Step 7 — Connect Studio (user action required)

Pause and give the user these instructions:

> 1. Open Roblox Studio and open your place.
> 2. Go to the **Plugins** tab → click **Rojo**.
> 3. Click **Connect** — it auto-connects to `localhost:34872`.

Wait for the user to confirm they are connected before proceeding.

## Step 8 — Done

Report that setup is complete. Remind the user:
- Edit Lua files in VS Code — changes sync to Studio automatically.
- Server scripts must end in `.server.lua`, client scripts in `.client.lua`.
- All game constants go in `src/game/ReplicatedStorage/GameConfig.lua`.
