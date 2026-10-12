#!/usr/bin/env bash
# debug-doc.sh: render a Debug Report from a finished Debug Log, so no model
# writes it. The log (tt-debug/templates/debug-log.md) is written render-ready;
# this checks it is complete and copies its sections into the report.
set -u

usage() {
	cat >&2 <<'EOF'
usage: debug-doc.sh [--check] <debug log.md> [<report.md>]

Checks that the Debug Log is finished, then writes the Debug Report:

  header   Symptom, Expected / Actual, Reproduction, Target and Status lines;
           Status is "Root cause confirmed <date>" or "Unresolved <date>"
  In short filled in, and not marked "(draft)"
  Hypotheses  at least one row; with a confirmed root cause, one row is
           "Root cause"
  Experiments at least one row
  Root cause  filled in (a confirmed root cause only)
  Temporary edits  every row removed ("yes"); the table may be empty
  Fix direction, Open questions  present

The report holds: the problem, In short, the root cause (or where the
investigation stands), what was tried, what it wasn't (the ruled-out
hypotheses and why), the observations, the fix direction and open questions.
Nothing is added that the log doesn't say.

--check  only check; write nothing (no <report.md> needed).
Prints "missing: …" lines for what the log lacks. The report is never
overwritten: delete it first to render again.
Exit: 0 written (or --check clean), 1 the log is incomplete, 2 usage error or
the report exists.
EOF
	exit 2
}

check=0
[ "${1:-}" = --check ] && { check=1; shift; }
case ${1:-} in -h | --help) usage ;; esac
if [ "$check" = 1 ]; then [ $# -eq 1 ] || usage; else [ $# -eq 2 ] || usage; fi
log=$1; out=${2:-}
[ -f "$log" ] || { echo "debug-doc.sh: no such file: $log" >&2; exit 2; }
[ -z "$out" ] || [ ! -e "$out" ] || { echo "debug-doc.sh: $out exists; delete it to render again" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$log" >"$work/log"

problems="$work/problems"; : >"$problems"
miss() { echo "missing: $*" >>"$problems"; }

# body <heading>: the section's text without its heading, edges trimmed
body() {
	bash "$here/md-section.sh" get "$work/log" "## $1" 2>/dev/null | sed '1d' |
		awk '{ a[NR] = $0 } END { s = 1; while (s <= NR && a[s] ~ /^[ \t]*$/) s++; e = NR; while (e >= s && a[e] ~ /^[ \t]*$/) e--; for (i = s; i <= e; i++) print a[i] }'
}
# rows <heading>: the table data rows (no header, no separator)
rows() { body "$1" | awk '/^\|/ { n++; if (n > 2) print }'; }
# label <name>: the text after "- **<name>:**" on its line
label() { sed -n "s#^- \*\*$1:\*\* *##p" "$work/log" | head -n 1; }
# strip an empty / template value
blank() { [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ] || printf '%s' "$1" | grep -q '^<'; }

symptom=$(label Symptom); eva=$(sed -n 's/^- \*\*Expected:\*\* *//p' "$work/log" | head -n 1)
repro=$(label Reproduction); since=$(label "Since / last good"); target=$(label Target); status=$(label Status)
folder=$(sed -n 's/^- \*\*Folder:\*\* *`\([^`]*\)`.*/\1/p' "$work/log" | head -n 1)
prefix=$(sed -n 's/.*\*\*Prefix:\*\* *\([^ ].*\)$/\1/p' "$work/log" | head -n 1)
title=$(sed -n 's/^# Debug Log: *//p' "$work/log" | head -n 1)
blank "$symptom" && miss "the Symptom line"
blank "$eva" && miss "the Expected / Actual line"
blank "$repro" && miss "the Reproduction line"
blank "$target" && miss "the Target line"
confirmed=0
case $status in
*"Root cause confirmed"*) confirmed=1 ;;
*Unresolved*) ;;
*) miss "a finished Status (\"Root cause confirmed <date>\" or \"Unresolved <date>\"); it is: ${status:-empty}" ;;
esac
short=$(body "In short")
if blank "$short"; then miss "the In short section"; elif printf '%s' "$short" | grep -qi '(draft)'; then miss "In short is still marked (draft)"; fi
hyp=$(rows Hypotheses)
[ -n "$hyp" ] || miss "a row in Hypotheses"
printf '%s\n' "$hyp" | awk -F'|' 'NF && $4 ~ /Root cause/ { f = 1 } END { exit !f }' || [ "$confirmed" = 0 ] || miss "a Hypotheses row with Status \"Root cause\""
exps=$(rows Experiments)
[ -n "$exps" ] || miss "a row in Experiments"
rc=$(body "Root cause")
if [ "$confirmed" = 1 ] && blank "$rc"; then miss "the Root cause section"; fi
fix=$(body "Fix direction"); blank "$fix" && miss "the Fix direction section (write \"none yet\" if there is none)"
oq=$(body "Open questions"); blank "$oq" && miss "the Open questions section (write \"None\" if there are none)"
temps=$(rows "Temporary edits")
printf '%s\n' "$temps" | awk -F'|' 'NF { r = $4; gsub(/^[ \t]+|[ \t]+$/, "", r); if (tolower(r) != "yes") { p = $2; gsub(/^[ \t]+|[ \t]+$/, "", p); print "missing: temporary edit not removed: " p } }' >>"$problems"

if [ -s "$problems" ]; then cat "$problems"; exit 1; fi
if [ "$check" = 1 ]; then echo "debug log complete"; exit 0; fi

if [ "$confirmed" = 1 ]; then outcome="Root cause found"; else outcome="Unresolved"; fi
now=$(date +%F)
{
	echo "# Debug Report: $title"
	echo
	echo "- **Status:** Written $now · **Outcome:** $outcome"
	echo "- **Read at:** $target"
	if [ -n "$prefix" ]; then echo "- **Debug Log:** \`.tt/$prefix - Debug/debug-log.md\` (working notes)"; fi
	echo
	echo "> This report records what was found while debugging. The fix direction is the"
	echo "> engineer's intent, not a reviewed design."
	echo
	echo "## The problem"
	echo "- **Symptom:** $symptom"
	echo "- **Expected:** $eva"
	echo "- **Reproduction:** $repro"
	[ -n "$since" ] && echo "- **Since / last good:** $since"
	echo
	echo "## In short"
	printf '%s\n\n' "$short"
	if [ "$confirmed" = 1 ]; then
		echo "## Root cause"
		printf '%s\n\n' "$rc"
	else
		echo "## Where it stands"
		echo "The root cause was not found. The hypotheses still standing:"
		echo
		echo "| Hypothesis | Status | Evidence for |"
		echo "|---|---|---|"
		printf '%s\n' "$hyp" | awk -F'|' '{ s = $4; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s != "Ruled out") { h = $3; f = $5; gsub(/^[ \t]+|[ \t]+$/, "", h); gsub(/^[ \t]+|[ \t]+$/, "", f); printf "| %s | %s | %s |\n", h, s, f } }'
		echo
	fi
	echo "## What was tried"
	echo "| # | What was tried | Who | Result | Points to |"
	echo "|---|---|---|---|---|"
	printf '%s\n\n' "$exps"
	ruled=$(printf '%s\n' "$hyp" | awk -F'|' '{ s = $4; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s == "Ruled out") { h = $3; a = $6; gsub(/^[ \t]+|[ \t]+$/, "", h); gsub(/^[ \t]+|[ \t]+$/, "", a); printf "| %s | %s |\n", h, a } }')
	if [ -n "$ruled" ]; then
		echo "## What it wasn't"
		echo "| Hypothesis | Why not |"
		echo "|---|---|"
		printf '%s\n\n' "$ruled"
	fi
	obs=$(body Observations)
	if ! blank "$obs"; then echo "## Evidence"; printf '%s\n\n' "$obs"; fi
	echo "## Fix direction"
	printf '%s\n\n' "$fix"
	echo "## Open questions"
	printf '%s\n\n' "$oq"
	echo "## Temporary edits"
	if [ -n "$temps" ]; then echo "Every temporary edit made while debugging has been removed:"; echo; echo "| Path | What | Removed |"; echo "|---|---|---|"; printf '%s\n' "$temps"; else echo "None were made."; fi
} >"$out"
echo "wrote $out ($outcome)"
