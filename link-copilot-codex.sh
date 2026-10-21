#!/usr/bin/env bash
# link-copilot-codex.sh: for a clone used with GitHub Copilot CLI or Codex CLI
# (Claude Code installs the plugins with /plugin instead). Shows what will be
# pulled and linked, asks, then links every tt-* skill into the personal skill
# locations of Copilot CLI and Codex CLI. Safe to re-run.
# The linking itself lives in plugins/core/skills/tt-guide/scripts/guide.sh (update check|apply).
set -u

cd "$(dirname "$0")" || exit 1
guide="plugins/core/skills/tt-guide/scripts/guide.sh"
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
echo "Done. Restart Copilot CLI or Codex CLI. (Claude Code installs the plugins with /plugin; see README.md.)"
