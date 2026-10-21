#!/usr/bin/env bash
# tt-path.sh: find tt-* skill folders wherever they are installed. Source it:
#   . "$here/tt-path.sh"; wf=$(tt_find tt-workflow)
# The tt plugins sit in separate folders, so a skill can't reach another
# plugin's files by "..". Each plugin's SessionStart hook (hooks/register.sh)
# points <tt-plugins home>/<plugin> at its installed folder; that pointer is
# the way across. tt_find looks first beside tt-common (the other skills of the
# plugin that holds it, and, for skills linked into one folder for another
# client, the folder they were reached through), then through the pointers.
# Needs bash only.
#
# Environment:
#   TT_PLUGINS_HOME  the pointer folder (default: ~/.claude/tt-plugins)

tt_plugins_home() { printf '%s\n' "${TT_PLUGINS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-plugins}"; }

# The folders that may hold tt-common's siblings (this script is
# tt-common/scripts/tt-path.sh): where it really is, and where it was reached
# through, which differ when the skill is a link. readlink -f follows Windows
# junctions; cd -P does not.
_tt_src=$(dirname "${BASH_SOURCE[0]}")
TT_SKILLS_DIRS=()
_tt_add() {
	[ -n "$1" ] && [ -d "$1" ] || return 0
	local d
	for d in "${TT_SKILLS_DIRS[@]}"; do [ "$d" = "$1" ] && return 0; done
	TT_SKILLS_DIRS+=("$1")
}
_tt_add "$(readlink -f "$_tt_src/../.." 2>/dev/null || (cd -P "$_tt_src/../.." && pwd -P))"
_tt_add "$(cd "$_tt_src/../.." 2>/dev/null && pwd)"
unset _tt_src

# tt_find <skill folder name>: print the folder, or return 1 if it isn't installed
tt_find() {
	local d
	for d in "${TT_SKILLS_DIRS[@]}"; do
		[ -d "$d/$1" ] && { printf '%s\n' "$d/$1"; return 0; }
	done
	for d in "$(tt_plugins_home)"/*/skills/"$1"; do
		[ -d "$d" ] && { printf '%s\n' "$d"; return 0; }
	done
	return 1
}

# tt_skills: the name of every installed tt-* skill folder, sorted, once each
tt_skills() {
	local base d
	{
		for base in "${TT_SKILLS_DIRS[@]}"; do
			for d in "$base"/tt-*; do [ -d "$d" ] && basename "$d"; done
		done
		for d in "$(tt_plugins_home)"/*/skills/tt-*; do [ -d "$d" ] && basename "$d"; done
	} | sort -u
}
