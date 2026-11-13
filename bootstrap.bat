@echo off
:: Bootstrap a fresh clone of this template.
:: Prerequisites: Rokit must already be installed on your machine.
:: https://github.com/rojo-rbx/rokit

echo =^> Installing toolchain (Rojo, Lune) via Rokit...
rokit install
if %ERRORLEVEL% neq 0 (
    echo ERROR: rokit install failed. Is Rokit installed?
    exit /b %ERRORLEVEL%
)

echo =^> Installing Rojo plugin into Roblox Studio...
rojo plugin install
if %ERRORLEVEL% neq 0 (
    echo ERROR: rojo plugin install failed.
    exit /b %ERRORLEVEL%
)

echo =^> Checking Lune...
lune --version
if %ERRORLEVEL% neq 0 (
    echo ERROR: lune --version failed.
    exit /b %ERRORLEVEL%
)

echo =^> Registering the Roblox Studio MCP server with Claude Code...
where claude >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo    WARN: 'claude' CLI not found on PATH; skipping. Install Claude Code, then run:
    echo      claude mcp add Roblox_Studio -- cmd.exe /c %%LOCALAPPDATA%%\Roblox\mcp.bat
) else (
    claude mcp get Roblox_Studio >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo    Already registered.
    ) else (
        claude mcp add Roblox_Studio -- cmd.exe /c %%LOCALAPPDATA%%\Roblox\mcp.bat
        if %ERRORLEVEL% neq 0 (
            echo    WARN: registration failed; add manually ^(see roblox-studio-mcp skill^).
        ) else (
            echo    Registered.
        )
    )
)

echo.
echo Done. Next steps:
echo   1. Create your first game: make new-game NAME=^<kebab-case-name^>, then cd games\^<name^>
echo   2. In the game folder: make serve (and make claude to work on it with Claude Code)
echo   3. Open Roblox Studio and connect the Rojo plugin to localhost:34872
echo   4. In Studio: Assistant -^> ... -^> Manage MCP Servers -^> enable 'Enable Studio as MCP server'
