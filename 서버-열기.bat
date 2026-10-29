@echo off
cd /d "%~dp0server"

set "NODE_EXE=C:\Users\cycos\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"

if not exist "%NODE_EXE%" goto node_missing
if not exist "node_modules\ws" goto module_missing

echo Game server starting...
echo Enter http://127.0.0.1:8000 in the Windows game's Online screen.
echo You can also open that address in a browser for the web build.
echo Keep this window open while playing.
echo.
"%NODE_EXE%" room_server.js
echo.
echo The server has stopped.
pause
exit /b 0

:node_missing
echo Node runtime was not found.
echo Open this project in Codex and ask it to repair the server launcher.
pause
exit /b 1

:module_missing
echo The WebSocket server module is missing.
echo Open this project in Codex and ask it to install the server module.
pause
exit /b 1
