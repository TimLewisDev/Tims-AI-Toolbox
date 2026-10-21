#!/usr/bin/env bash
# register.sh <plugin>: SessionStart hook. Points
# <tt-plugins home>/<plugin> at this plugin's installed folder, so the tt
# plugins can find each other's files (tt-common above all) whatever
# version folder the plugin manager put them in. Needs bash only. Never
# fails or delays the session. Every tt plugin ships an identical copy.
#
# Environment:
#   TT_PLUGINS_HOME  the pointer folder (default: ~/.claude/tt-plugins)
#   CLAUDE_PLUGIN_ROOT  set by Claude Code (default: the folder above hooks/)

name=${1:-}
[ -n "$name" ] || exit 0
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)} || exit 0
home=${TT_PLUGINS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-plugins}
mkdir -p "$home" 2>/dev/null || exit 0
link=$home/$name

# Git Bash's cd -P doesn't follow Windows junctions, but readlink -f does.
resolve() { readlink -f "$1" 2>/dev/null || (cd -P "$1" 2>/dev/null && pwd -P); }

if [ -e "$link" ] || [ -L "$link" ]; then
	[ "$(resolve "$link")" = "$(resolve "$root")" ] && exit 0
	# rmdir removes a junction or symlink without touching what it points at;
	# it fails on a real folder, which is left alone.
	rmdir "$link" 2>/dev/null || rm -f "$link" 2>/dev/null || exit 0
fi

case ${OSTYPE:-} in
msys* | cygwin* | win32*)
	if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
		TT_LINK_PATH=$(cygpath -w "$link") TT_TARGET_PATH=$(cygpath -w "$root") \
			powershell.exe -NoProfile -NonInteractive -Command \
			'$ErrorActionPreference = "Stop"; New-Item -ItemType Junction -Path $env:TT_LINK_PATH -Target $env:TT_TARGET_PATH | Out-Null' \
			>/dev/null 2>&1 || true
		exit 0
	fi ;;
esac
ln -s "$root" "$link" 2>/dev/null
exit 0
