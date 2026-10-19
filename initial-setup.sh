#!/usr/bin/env bash
# initial-setup.sh: first-time setup for macOS and Linux. Shows what will be
# pulled and linked, asks, then links every tt-* skill into the personal skill
# locations of Claude Code, Copilot CLI and Codex CLI. Safe to re-run.
# The linking itself lives in tt-guide/scripts/guide.sh (update check|apply).
set -u

cd "$(dirname "$0")" || exit 1
guide="tt-guide/scripts/guide.sh"
[ -f "$guide" ] || { echo "Can't find $guide. Run this from the toolbox folder." >&2; exit 1; }

bash "$guide" update check || exit 1

printf '\nGo ahead and pull and link the skills? [y/N] '
read -r answer
case $answer in
y | Y | yes | YES | Yes) ;;
*)
	echo "Nothing was changed."
	exit 0
	;;
esac

echo
bash "$guide" update apply || exit 1
echo
echo "Setup done. Restart Claude Code, then type /tt-guide."
