@echo off
rem First-time setup on Windows: double-click this file.
rem It runs initial-setup.ps1, which links the skills into Claude Code,
rem Copilot CLI and Codex CLI.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0initial-setup.ps1"
echo.
pause
