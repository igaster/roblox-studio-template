Set up this Roblox game project from scratch. Follow these steps in order, reporting progress after each one.

## Step 1 — Check Rojo

Run `rojo --version` in PowerShell.

- If Rojo is already installed (any version): note the version, skip to Step 3.
- If not found: proceed to Step 2.

## Step 2 — Install Rokit + Rojo

Rokit is only needed if Rojo is not already installed.

1. Pause and tell the user: "Rojo is not installed. Please install Rokit from https://github.com/rojo-rbx/rokit/releases/latest, then run `! rokit --version` to confirm it works."
2. Wait for user confirmation.
3. Run `rokit install` to install Rojo via `rokit.toml`.

## Step 3 — Install Rojo Studio Plugin

Run: `rojo plugin install`

This installs the Rojo plugin into Roblox Studio.

## Step 4 — Name the game

Ask the user: "What should the game be named?"

Wait for their answer, then update `default.project.json` — replace the value of the top-level `"name"` field with the user's answer.

## Step 5 — Start the Rojo server

Run the server in a new window so the terminal stays free:

```powershell
Start-Process -FilePath "rojo" -ArgumentList "serve", "default.project.json" -WindowStyle Normal
```

The server listens on `localhost:34872`.

## Step 6 — Connect Studio (user action required)

Pause and give the user these instructions:

> 1. Open Roblox Studio and open your place.
> 2. Go to the **Plugins** tab → click **Rojo**.
> 3. Click **Connect** — it auto-connects to `localhost:34872`.

Wait for the user to confirm they are connected before proceeding.

## Step 7 — Done

Report that setup is complete. Remind the user:
- Edit Lua files in VS Code — changes sync to Studio automatically.
- Server scripts must end in `.server.lua`, client scripts in `.client.lua`.
- All game constants go in `src/game/ReplicatedStorage/GameConfig.lua`.
