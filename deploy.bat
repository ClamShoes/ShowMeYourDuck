@echo off
REM Deploy main to the live server. "deploy.bat apk" also publishes a new Android APK at /download/.
setlocal
set FLAG=
if /i "%~1"=="apk" set FLAG=-Apk
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %FLAG%
pause
