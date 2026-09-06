@echo off
setlocal
cd /d "%~dp0"

set GODOT=C:\Godot\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe

echo ============================================
echo  Show me your duck — dedicated server
echo ============================================
echo.

if not exist "%GODOT%" (
    echo Godot not found at:
    echo   %GODOT%
    echo.
    pause
    exit /b 1
)

echo Project: %CD%
echo URL:     ws://127.0.0.1:9080
echo.
echo Keep this window open. In the game, Create room / Join.
echo Close this window to stop the server.
echo.

"%GODOT%" --headless --path "%CD%" -- --server --port 9080

echo.
echo Server stopped. Exit code %ERRORLEVEL%
pause
