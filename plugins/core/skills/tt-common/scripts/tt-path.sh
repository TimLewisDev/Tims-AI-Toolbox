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
case ${BASH_SOURCE[0]} in */*) _tt_src=${BASH_SOURCE[0]%/*} ;; *) _tt_src=. ;; esac
TT_SKILLS_DIRS=()
_tt_add() {
	[ -n "$1" ] && [ -d "$1" ] || return 0
	local d
	for d in "${TT_SKILLS_DIRS[@]}"; do [ "$d" = "$1" ] && return 0; done
	TT_SKILLS_DIRS+=("$1")
}
_tt_add "$(readlink -f "$_tt_src/../.." 2>/dev/null || (cd -P "$_tt_src/../.." && pwd -P))"
# _tt_abs <dir>: set _tt_b to the directory's path as cd reports it, or to
# nothing; the sourcing shell's directory and OLDPWD are left as they were.
_tt_abs() {
	local pwd_=$PWD old_=${OLDPWD-} had_=${OLDPWD+x}
	_tt_b=
	cd "$1" >/dev/null 2>&1 && _tt_b=$PWD
	cd "$pwd_" >/dev/null 2>&1
	if [ -n "$had_" ]; then OLDPWD=$old_; else unset OLDPWD; fi
}
_tt_abs "$_tt_src/../.."
_tt_add "$_tt_b"
# The script that sourced this one, by the path it was started with: when it
# resolved its own folder to the real one, this still has the linked folder.
case $0 in */*) _tt_caller=${0%/*} ;; *) _tt_caller=. ;; esac
_tt_abs "$_tt_caller/../.."
_tt_caller=$_tt_b
[ -d "$_tt_caller/tt-common" ] && _tt_add "$_tt_caller"
unset _tt_src _tt_caller _tt_b
unset -f _tt_abs

# tt_find <skill folder name>: print the folder, or return 1 if it isn't installed
tt_find() { tt_find_reply "$1" && printf '%s\n' "$REPLY"; }

# tt_find_reply <skill folder name>: the same search, but the folder is left in
# REPLY (empty when not found) and nothing is printed, so no subshell is needed
tt_find_reply() {
	local d
	REPLY=
	for d in "${TT_SKILLS_DIRS[@]}"; do
		[ -d "$d/$1" ] && { REPLY=$d/$1; return 0; }
	done
	for d in "${TT_PLUGINS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-plugins}"/*/skills/"$1"; do
		[ -d "$d" ] && { REPLY=$d; return 0; }
	done
	return 1
}

# tt_skills: the name of every installed tt-* skill folder, sorted, once each
tt_skills() {
	local base d
	{
		for base in "${TT_SKILLS_DIRS[@]}"; do
			for d in "$base"/tt-*; do [ -d "$d" ] && printf '%s\n' "${d##*/}"; done
		done
		for d in "${TT_PLUGINS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-plugins}"/*/skills/tt-*; do [ -d "$d" ] && printf '%s\n' "${d##*/}"; done
	} | sort -u
}
