@echo off
rem Links the skills into Copilot CLI and Codex CLI on Windows: double-click this file.
rem It runs link-copilot-codex.ps1. Claude Code installs the plugins with /plugin instead.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-copilot-codex.ps1"
echo.
pause
