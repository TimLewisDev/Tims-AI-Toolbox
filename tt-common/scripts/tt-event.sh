#!/usr/bin/env bash
# tt-event.sh: the tt toolbox's stage-completion ledger. Appends one JSON line to
# a user-level, append-only file each time a stage or gate is finished, so a
# companion app can award experience from it. Events are facts, never rewards.
# Best-effort and silent: it never fails or delays the skill that calls it.
# Needs bash and awk only. See tt-common/events.md for the contract.
set -u

usage() {
	cat >&2 <<'EOF'
usage: tt-event.sh emit <event> --prefix <Prefix> --folder <dir>
                        [--route full|lite|debug] [--qualifier <q>]
                        [--skill <name>] [--source skill|reconcile]
       tt-event.sh reconcile <folder>   record the events the documents prove
       tt-event.sh tail [n]             the last n ledger lines (default 10)
       tt-event.sh where                the ledger's path
       tt-event.sh events               the event names this script accepts

emit appends one line unless the same key (project|prefix|event[|qualifier]) is
already in the ledger, and prints "recorded: <key>" or "already recorded: <key>".
The route is worked out from the folder's documents when not given. Call it
after the closing state is on disk.

reconcile finds every feature in the folder (as workflow-state.sh does) and
records what its documents prove, marked "source":"reconcile","approx":true,
since the time is when it was noticed. Safe to run any number of times.

Environment:
  TT_EVENTS       off | 0 | false | no: emit and reconcile do nothing
  TT_EVENTS_HOME  state directory (default: ~/.claude/tt-events)
  TT_EVENTS_LOG   the ledger (default: events.jsonl in the state directory)

Exit: 0 always, except 2 for a usage error (emit and reconcile with a bad
argument, an unknown event name).
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
home=${TT_EVENTS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-events}
log=${TT_EVENTS_LOG:-$home/events.jsonl}

EVENTS="explore.focus_confirmed explore.documented
plan.familiarisation_closed plan.requirements_closed plan.scope_closed plan.approach_closed
plan.design_closed plan.whole_closed plan.signed_off
breakdown.written lite.brief_written build.unit_validated build.complete
debug.root_cause_confirmed debug.report_written"

off() { case "${TT_EVENTS:-on}" in off | OFF | 0 | false | no) return 0 ;; esac; return 1; }

# esc <text>: JSON string content (control characters become spaces)
esc() { printf '%s' "$1" | tr '\t\r\n' '   ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# abs <dir>: the folder's absolute path, with forward slashes
abs() { (cd "$1" 2>/dev/null && { pwd -W 2>/dev/null || pwd; }); }

# field <file> <regex>: the first line matching the regex, without CR
field() { awk -v re="$2" '{ sub(/\r$/, "") } $0 ~ re { print; exit }' "$1"; }

project=$(git rev-parse --show-toplevel 2>/dev/null) || project=$(pwd -W 2>/dev/null || pwd)

# detect_route <event> <prefix> <folder>
detect_route() {
	case $1 in
	debug.*) echo debug ;;
	lite.*) echo lite ;;
	build.* | explore.focus_confirmed)
		if [ -f "$3/$2 - Lite Brief.md" ] ||
			{ [ -f "$3/.tt/$2 - Familiarisation/focus-log.md" ] && grep -q 'Mode:\*\* lite' "$3/.tt/$2 - Familiarisation/focus-log.md"; }; then
			echo lite
		else echo full; fi ;;
	*) echo full ;;
	esac
}

# do_emit <event> <prefix> <folder> <route> <qualifier> <skill> <source>
# route may be empty (detected). Prints a result line; returns 0 unless the event is unknown.
do_emit() {
	local event=$1 prefix=$2 folder=$3 route=$4 qual=$5 skill=$6 source=$7
	case " $(printf '%s' "$EVENTS" | tr '\n' ' ') " in *" $event "*) ;; *) echo "tt-event.sh: unknown event: $event" >&2; return 2 ;; esac
	off && return 0
	[ -n "$route" ] || route=$(detect_route "$event" "$prefix" "$folder")
	local key="$project|$prefix|$event${qual:+|$qual}"
	local ekey; ekey=$(esc "$key")
	mkdir -p "$(dirname "$log")" 2>/dev/null || return 0

	# One writer at a time; if the lock can't be had for ~2s, carry on without it.
	local lock="$log.lock" n=0 locked=0
	while [ $n -lt 20 ]; do
		if mkdir "$lock" 2>/dev/null; then locked=1; break; fi
		sleep 0.1; n=$((n + 1))
	done
	if [ -f "$log" ] && grep -qF -- "\"key\":\"$ekey\"" "$log" 2>/dev/null; then
		[ $locked = 1 ] && rmdir "$lock" 2>/dev/null
		echo "already recorded: $key"; return 0
	fi
	local approx=false; [ "$source" = reconcile ] && approx=true
	printf '{"v":1,"ts":"%s","event":"%s","key":"%s","route":"%s","prefix":"%s","folder":"%s","project":"%s","qualifier":"%s","source":"%s","skill":"%s","approx":%s}\n' \
		"$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$event" "$ekey" "$route" "$(esc "$prefix")" "$(esc "$folder")" \
		"$(esc "$project")" "$(esc "$qual")" "$source" "$(esc "$skill")" "$approx" >>"$log" 2>/dev/null
	[ $locked = 1 ] && rmdir "$lock" 2>/dev/null
	echo "recorded: $key"
	return 0
}

# stages_closed <plan>: the event for each Stages row that is Closed
stages_closed() {
	awk -F'|' '{ sub(/\r$/, "") }
		/^\*\*Stages\*\*/ { on = 1; next }
		on && /^\|/ {
			s = tolower($2); t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
			if (s == "stage" || s ~ /^-+$/) next
			if (t !~ /^Closed/) next
			if (s ~ /^familiarisation/) print "plan.familiarisation_closed"
			else if (s ~ /^requirements/) print "plan.requirements_closed"
			else if (s ~ /^scope/) print "plan.scope_closed"
			else if (s ~ /^approach/) print "plan.approach_closed"
			else if (s ~ /^technical design/) print "plan.design_closed"
			else if (s ~ /^whole/) print "plan.whole_closed"
			next }
		on && NF && !/^\|/ { exit }' "$1"
}

# units_done <task status>: the ID of each Work Unit Board row whose Status is Done
units_done() {
	awk '
	function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
	function cells(l, arr,   n, i, raw) {
		sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l); n = split(l, raw, "|")
		for (i = 1; i <= n; i++) { arr[i] = trim(raw[i]); gsub(/[`*]/, "", arr[i]) }
		return n }
	function col(want,   i) { for (i = 1; i <= nh; i++) if (index(tolower(hdr[i]), want) == 1) return i; return 0 }
	{ l = $0; sub(/\r$/, "", l) }
	l ~ /^# / { sec = trim(substr(l, 3)); inhdr = 1; next }
	sec == "Work Unit Board" && l ~ /^[ \t]*\|/ {
		if (inhdr) { nh = cells(l, hdr); inhdr = 0; sep = 1; ui = col("id"); us = col("status"); next }
		if (sep) { sep = 0; next }
		cells(l, c); if (ui && us && c[us] == "Done") print c[ui] }' "$1"
}

# reconcile_one <folder> <prefix>
reconcile_one() {
	local dir=$1 p=$2 e
	local plan="$dir/$p - Comprehensive Tech Plan.md" st="$dir/$p - Task Status.md"
	local fam="$dir/$p - Familiarisation.md" log_="$dir/.tt/$p - Familiarisation/focus-log.md"
	local lb="$dir/$p - Lite Brief.md" dlog="$dir/.tt/$p - Debug/debug-log.md" drep="$dir/$p - Debug Report.md"
	em() { do_emit "$1" "$p" "$dir" "" "${2:-}" reconcile reconcile; }

	if [ -f "$fam" ] || { [ -f "$log_" ] && grep -q '^- \*\*Status:\*\* *Focus confirmed' "$log_"; }; then em explore.focus_confirmed; fi
	[ -f "$fam" ] && em explore.documented
	if [ -f "$plan" ]; then
		if field "$plan" 'Status:' | grep -q Draft; then
			stages_closed "$plan" | while IFS= read -r e; do em "$e"; done
		else
			# The Stages table is deleted at sign-off: every stage was closed.
			[ -f "$fam" ] && em plan.familiarisation_closed
			for e in plan.requirements_closed plan.scope_closed plan.approach_closed plan.design_closed plan.whole_closed plan.signed_off; do em "$e"; done
		fi
	fi
	[ -f "$lb" ] && em lite.brief_written
	if [ -f "$st" ]; then
		[ -f "$lb" ] || em breakdown.written
		units_done "$st" | while IFS= read -r e; do em build.unit_validated "$e"; done
		field "$st" '^- State:' | grep -q 'Complete' && em build.complete
	fi
	if [ -f "$dlog" ] && field "$dlog" '^- [*][*]Status:[*][*]' | grep -q 'Root cause confirmed'; then em debug.root_cause_confirmed; fi
	[ -f "$drep" ] && em debug.report_written
	return 0
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
emit)
	[ $# -ge 1 ] || { usage; exit 2; }
	event=$1; shift
	prefix=""; folder=""; route=""; qual=""; skill=""; source=skill
	while [ $# -gt 0 ]; do
		case $1 in
		--prefix) prefix=${2?}; shift 2 ;;
		--folder) folder=${2?}; shift 2 ;;
		--route) route=${2?}; shift 2 ;;
		--qualifier) qual=${2?}; shift 2 ;;
		--skill) skill=${2?}; shift 2 ;;
		--source) source=${2?}; shift 2 ;;
		*) usage; exit 2 ;;
		esac
	done
	[ -n "$prefix" ] && [ -n "$folder" ] || { usage; exit 2; }
	case $route in "" | full | lite | debug) ;; *) usage; exit 2 ;; esac
	case $source in skill | reconcile) ;; *) usage; exit 2 ;; esac
	folder=$(abs "$folder") || folder=$folder
	do_emit "$event" "$prefix" "$folder" "$route" "$qual" "$skill" "$source"
	rc=$?
	[ $rc = 2 ] && exit 2
	exit 0
	;;
reconcile)
	[ $# -eq 1 ] || { usage; exit 2; }
	off && exit 0
	d=$(abs "$1") || exit 0
	prefixes=$(bash "$here/workflow-state.sh" --tsv "$d" 2>/dev/null | awk -F'\t' 'NF && $1 != "" { print $1 }' | sort -u)
	while IFS= read -r p; do
		[ -n "$p" ] && reconcile_one "$d" "$p"
	done <<<"$prefixes"
	exit 0
	;;
tail) tail -n "${1:-10}" "$log" 2>/dev/null; exit 0 ;;
where) echo "$log"; exit 0 ;;
events) printf '%s\n' $EVENTS; exit 0 ;;
-h | --help | "") usage; [ -z "$cmd" ] && exit 2; exit 0 ;;
*) usage; exit 2 ;;
esac
