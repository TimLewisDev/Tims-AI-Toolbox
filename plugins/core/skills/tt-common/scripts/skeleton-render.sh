#!/usr/bin/env bash
# skeleton-render.sh: write the parts of a Task Breakdown that are pure copies
# of its approved skeleton: the manifest, the Work Units table and the Task
# Map, so no model re-types them.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: skeleton-render.sh <draft folder>

From <draft>/skeleton.md, writes (replacing earlier renders):
  <draft>/manifest.txt         parts/00-header.md, 10-work-units.md,
                               20-task-map.md, then per unit 30-<WU>.md and
                               31-<WU>-<task>.md for each of its tasks, then
                               80-coverage.md and 90-verification.md
  <draft>/parts/10-work-units.md  "## Work Units": ID, After this unit you
                               can…, Tasks, Validated by, Depends on
  <draft>/parts/20-task-map.md    "## Task Map": ID, Task, Executor, Depends
                               on, Work unit, Plan step, Traces to; the line
                               on which tasks may run in parallel; then the
                               "## Units and Tasks" heading
Both parts end with <!-- tt:end -->. Writes go through a temp file.
Prints one line per file written.

Exit: 0 written, 1 the skeleton has no tasks or units, 2 usage error.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac
draft=$1
sk="$draft/skeleton.md"
[ -f "$sk" ] || { echo "skeleton-render.sh: no skeleton: $sk" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash "$here/skeleton-tsv.sh" "$sk" tasks >"$work/tasks" || { echo "skeleton-render.sh: no tasks in the skeleton" >&2; exit 1; }
bash "$here/skeleton-tsv.sh" "$sk" units >"$work/units" || { echo "skeleton-render.sh: no units in the skeleton" >&2; exit 1; }
mkdir -p "$draft/parts"

put() { # file <- stdin, atomically
	local t; t=$(mktemp "$(dirname "$1")/.render.XXXXXX"); cat >"$t"; mv "$t" "$1"; echo "wrote $1"
}

awk -F'\t' '
FILENAME ~ /tasks$/ { next }
BEGIN { print "## Work Units"; print ""; print "| ID | After this unit you can… | Tasks | Validated by | Depends on |"; print "|---|---|---|---|---|" }
{ t = $3; gsub(/,/, ", ", t); print "| " $1 " | " $2 " | " t " | " $4 " | " $5 " |" }
END { print ""; print "<!-- tt:end -->" }' "$work/units" | put "$draft/parts/10-work-units.md"

awk -F'\t' '
FILENAME ~ /units$/ { n = split($3, ts, ","); for (i = 1; i <= n; i++) U[ts[i]] = $1; if ($6 != "—" && $6 != "") par = par (par == "" ? "" : "; ") $1 ": " $6; next }
FNR == 1 { print "## Task Map"; print ""; print "| ID | Task | Executor | Depends on | Work unit | Plan step | Traces to |"; print "|---|---|---|---|---|---|---|" }
{ print "| " $1 " | " $2 " | " $3 " | " $5 " | " (($1 in U) ? U[$1] : "—") " | " ($9 == "" ? "—" : $9) " | " ($6 == "" ? "—" : $6) " |" }
END {
	print ""
	print (par == "" ? "None: every unit runs its tasks in order." : "May run in parallel (Agent tasks with no shared files): " par ".")
	print ""; print "## Units and Tasks"; print ""; print "<!-- tt:end -->"
}' "$work/units" "$work/tasks" | put "$draft/parts/20-task-map.md"

awk -F'\t' '
BEGIN { print "parts/00-header.md"; print "parts/10-work-units.md"; print "parts/20-task-map.md" }
{ print "parts/30-" $1 ".md"; n = split($3, ts, ","); for (i = 1; i <= n; i++) print "parts/31-" $1 "-" ts[i] ".md" }
END { print "parts/80-coverage.md"; print "parts/90-verification.md" }' "$work/units" | put "$draft/manifest.txt"
