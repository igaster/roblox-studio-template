@echo off
:: Bootstrap a fresh clone of this template.
:: Prerequisites: Rokit must already be installed on your machine.
:: https://github.com/rojo-rbx/rokit

echo =^> Installing toolchain (Rojo) via Rokit...
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

echo.
echo Done. Next steps:
echo   1. Rename the project in default.project.json and lobby.project.json
echo   2. Run: make serve
echo   3. Open Roblox Studio and connect the Rojo plugin to localhost:34872
