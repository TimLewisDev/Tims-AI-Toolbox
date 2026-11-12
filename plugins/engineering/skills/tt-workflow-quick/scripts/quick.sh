#!/usr/bin/env bash
# quick.sh: the folder link, stage reader and go-ahead writer for tt-workflow-quick.
# A quick task is a lite task that runs without a conversation, so the link,
# the state and the documents are the lite route's: start, state, link, unlink,
# new and linked are lite.sh's (tt-workflow's workflow.sh with the lite links
# file). An empty folder says a new task is described, not that bug or feature
# is asked.
#
# confirm <focus log>  records the engineer's go-ahead: it writes the Status line
#   `Focus confirmed <date>` that workflow-state.sh and tt-lite-brief read, and the
#   header line `**Pace:** quick` (if the log lacks it) that makes a resume come
#   back to tt-workflow-quick. It changes nothing else in the log.
set -u

usage() {
	cat >&2 <<'EOF'
usage: quick.sh start | state [folder] | linked | link <folder> | unlink | new <parent> <name>
                (as lite.sh; -h for more)
       quick.sh confirm <focus log>   record the go-ahead in a lite Focus Log

Exit: 0 ok, 1 nothing linked, 2 usage or environment error.
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)

if [ "${1:-}" = confirm ]; then
	shift
	[ $# -eq 1 ] || { usage; exit 2; }
	log=$1
	[ -f "$log" ] || { echo "quick.sh: no such Focus Log: $log" >&2; exit 2; }
	grep -q '^- [*][*]Mode:[*][*] lite' "$log" ||
		{ echo "quick.sh: $log is not a lite Focus Log (its header has no '**Mode:** lite')." >&2; exit 2; }
	grep -q '^- [*][*]Status:[*][*]' "$log" ||
		{ echo "quick.sh: $log has no '**Status:**' line." >&2; exit 2; }
	if grep -q '^- [*][*]Status:[*][*] *Focus confirmed' "$log" && grep -q '^- [*][*]Pace:[*][*] *quick' "$log"; then
		echo "Already confirmed: $log"
		exit 0
	fi
	today=$(date +%F)
	tmp="$log.$$"
	# Line by line, keeping each line's own CR: the log may be LF or CRLF.
	pace=0
	grep -q '^- [*][*]Pace:[*][*]' "$log" && pace=1
	{
		while IFS= read -r l || [ -n "$l" ]; do
			cr=""
			if [[ $l == *$'\r' ]]; then cr=$'\r'; l=${l%$'\r'}; fi
			if [[ $l == '- **Status:**'* ]]; then
				printf '%s%s\n' "- **Status:** Focus confirmed $today (quick: go-ahead given)" "$cr"
			elif [[ $l == '- **Mode:** lite'* ]] && [ "$pace" = 0 ]; then
				printf '%s%s\n' "$l" "$cr"
				printf '%s%s\n' "- **Pace:** quick" "$cr"
				pace=1
			else
				printf '%s%s\n' "$l" "$cr"
			fi
		done <"$log"
	} >"$tmp" && mv "$tmp" "$log" || { rm -f "$tmp"; echo "quick.sh: could not write $log" >&2; exit 2; }
	echo "Confirmed: $log"
	# Record the stage (silent, best-effort): <folder>/.tt/<Prefix> - Familiarisation/focus-log.md
	lp=$(cd "$(dirname "$log")" 2>/dev/null && pwd)
	if [ -n "$lp" ]; then
		fam=${lp##*/}; prefix=${fam% - Familiarisation}
		folder=$(dirname "$(dirname "$lp")")
		common=""
		for d in "$(dirname "$(dirname "$here")")" "${TT_PLUGINS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-plugins}/core/skills"; do
			[ -d "$d/tt-common/scripts" ] && { common="$d/tt-common/scripts"; break; }
		done
		if [ "$prefix" != "$fam" ] && [ -n "$common" ] && [ -f "$common/tt-event.sh" ]; then
			bash "$common/tt-event.sh" emit explore.focus_confirmed --prefix "$prefix" --folder "$folder" --skill tt-workflow-quick >/dev/null 2>&1
		fi
	fi
	exit 0
fi

case ${1:-} in -h | --help) usage; exit 0 ;; esac

# The rest is lite.sh's. Find it beside this skill (skills linked into one folder),
# else by the real path.
lite="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/tt-workflow-lite/scripts/lite.sh"
[ -f "$lite" ] || lite="$(dirname "$(dirname "$here")")/tt-workflow-lite/scripts/lite.sh"
[ -f "$lite" ] || { echo "quick.sh: tt-workflow-lite is not installed beside tt-workflow-quick ($lite)" >&2; exit 2; }
out=$(bash "$lite" "$@"); rc=$?
[ -z "$out" ] || printf '%s\n' "$out" | sed 's|^  → a new task: is it a bug or a feature?$|  → a new task: what is the change? (/tt-workflow-quick "<folder>" <the task, in words>)|'
exit $rc
