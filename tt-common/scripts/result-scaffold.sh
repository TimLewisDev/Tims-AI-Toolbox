#!/usr/bin/env bash
# result-scaffold.sh: print a task's result file with everything a script can
# know already written (heading, work unit, Files Modified), leaving
# "<!-- fill: … -->" markers only for what the writer has to say.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: result-scaffold.sh <task breakdown.md> <task ID> [--run <run folder>] [--repo <path>]

Prints the shape of tt-coder's templates/result.md for the task:
  "# Result: <ID> — <title>" and "- Validation: Deferred to <WU>", from the
  breakdown's Task Map;
  Files Modified from "task-files.sh diff" when --run has a snapshot for the
  task (each file's purpose left to fill), else one marker;
  every other section as a marker.
Redirect it to <run>/results/<ID>.md and replace each marker. status-log.sh
refuses a result file that still has one.

Exit: 0 printed, 2 usage error (unknown task).
EOF
	exit 2
}

die() { echo "result-scaffold.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
bd=$1; id=$2; shift 2
run=""; repo=()
while [ $# -gt 0 ]; do
	case "$1" in
		--run) run=${2:?}; shift 2 ;;
		--repo) repo=(--repo "${2:?}"); shift 2 ;;
		*) usage ;;
	esac
done
[ -f "$bd" ] || die "no such file: $bd"
here=$(cd "$(dirname "$0")" && pwd)

row=$(tr -d '\r' <"$bd" | awk -v ID="$id" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cells(l, arr,   n, i, raw) {
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, raw, "|")
	for (i = 1; i <= n; i++) { arr[i] = trim(raw[i]); gsub(/`/, "", arr[i]) }
	return n
}
/^## / { sec = trim(substr($0, 4)); inhdr = 1; next }
sec == "Task Map" && /^[ \t]*\|/ {
	if (inhdr) { nh = cells($0, h); inhdr = 0; sep = 1
		for (i = 1; i <= nh; i++) { k = tolower(h[i]); if (k == "id") ci = i; else if (k == "task") ct = i; else if (index(k, "work unit") == 1) cw = i }
		next }
	if (sep) { sep = 0; next }
	cells($0, c)
	if (c[ci] == ID) { print c[ct] "\t" c[cw]; exit }
}')
[ -n "$row" ] || die "no $id in the breakdown's Task Map"
title=${row%%$'\t'*}; wu=${row#*$'\t'}

files="- <!-- fill: new|change \`<path>\`: <purpose or what changed>, one per file -->"
if [ -n "$run" ] && [ -f "$run/snapshots/$id.tsv" ]; then
	listed=$(bash "$here/task-files.sh" diff "$bd" "$run" "$id" ${repo[@]+"${repo[@]}"} 2>/dev/null |
		awk -F '\t' '$1 == "new" || $1 == "change" || $1 == "delete" { printf "- %s `%s`: <!-- fill: %s -->\n", $1, $2, ($1 == "new" ? "purpose" : $1 == "delete" ? "why" : "what changed") }') || true
	[ -n "$listed" ] && files=$listed
fi

cat <<EOF
# Result: $id — $title

- Task status: <!-- fill: implemented | blocked | interrupted -->
- Validation: Deferred to $wu

## Files Modified
$files

## Summary
<!-- fill: what was done, in a few lines -->

## To validate
<!-- fill: what to check, how, the expected result, edge cases -->

## Follow-up Concerns
<!-- fill: or none -->

## Risks
- <!-- fill: one risk per bullet, or none -->

## Improvements
<!-- fill: ### <short name> with Description, Benefits, Risks/Tradeoffs, Why High Impact; or none -->

## Critical Decision
<!-- fill: none, or the Critical Decision block -->
EOF
