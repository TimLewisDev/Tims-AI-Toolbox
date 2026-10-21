#!/usr/bin/env bash
# validation-checklist.sh: gather what the engineer's inline validation
# checklist for a work unit is built from, so the orchestrator reads one short
# draft instead of the unit block, the attempt and every task's Step Log entry.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: validation-checklist.sh <task breakdown.md> <task status.md> <WU>

Prints a markdown draft (redirect it to a file to keep it):
  ## Checks waiting on the engineer: the unit's Validation items marked
     Engineer or Agent + Engineer, with their numbers; once an attempt is
     recorded, only those still pending, failed or blocked in the latest one
  ## Engineer steps: the "Engineer" part of the unit's How to validate
  ## To validate notes: each of the unit's tasks' "- To validate:" from the
     Step Log
The orchestrator turns it into the inline checklist: concrete paths, menu
items and values (looked up in the repo where the draft is vague), one check
per item, what to report back. Read-only.

Exit: 0 printed, 1 no engineer checks for the unit, 2 usage error.
EOF
	exit 2
}

[ $# -eq 3 ] || usage
bd=$1; st=$2; wu=$3
[ -f "$bd" ] || { echo "validation-checklist.sh: no such file: $bd" >&2; exit 2; }
[ -f "$st" ] || { echo "validation-checklist.sh: no such file: $st" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$here/md-section.sh" get "$bd" "## $wu —" 2>/dev/null | tr -d '\r' | awk '/^### / { exit } { print }' >"$work/unit" || true
[ -s "$work/unit" ] || { echo "validation-checklist.sh: no \"## $wu —\" unit block" >&2; exit 2; }
tr -d '\r' <"$st" >"$work/status"

awk -v WU="$wu" -v STATUS="$work/status" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
BEGIN {
	# The latest attempt for the unit: which checks are still open.
	while ((getline l < STATUS) > 0) {
		if (l ~ /^# /) { sec = trim(substr(l, 3)); continue }
		if (sec == "Work Unit Validation" && l ~ /^## /) { u = substr(l, 4); sub(/[ \t]+—.*$/, "", u); cu = plain(u); continue }
		if (sec == "Work Unit Validation" && cu == WU && l ~ /^### Attempt/) { delete OPEN; delete SEEN; att = 1; continue }
		if (att && cu == WU && match(l, /^[ \t]+- Check [0-9]+ /)) {
			split(trim(l), w, " "); cn = w[3] + 0; SEEN[cn] = 1
			r = l; p = index(r, "]: "); if (p == 0) p = index(r, "): "); r = substr(r, p + 3)
			if (r ~ /^(pending|failed|blocked)/) { o = r; sub(/[ .;].*$/, "", o); OPEN[cn] = o }
		}
		if (sec == "Task Board" && l ~ /^\|/) { split(l, c, "|"); if (plain(c[5]) == WU) TASKS[++nt] = plain(c[2]) }
		if (sec == "Step Log" && l ~ /^## /) { e = substr(l, 4); t = e; sub(/[ \t]+—.*$/, "", t); ent = plain(t); TITLE[ent] = e; intv = 0; continue }
		if (sec == "Step Log" && ent != "" && l ~ /^- To validate:/) { intv = 1; v = trim(substr(l, 15)); if (v != "") TV[ent] = TV[ent] v "\n"; continue }
		if (sec == "Step Log" && intv) { if (l ~ /^- /) intv = 0; else TV[ent] = TV[ent] l "\n" }
	}
	close(STATUS)
}
/^\*\*Validation\*\*/ { inv = 1; next }
/^\*\*How to validate\*\*/ { inv = 0; inh = 1; next }
inv && /^- \[[ xX]\] / {
	n++; t = substr($0, 7)
	if (t ~ /\((Agent \+ Engineer|Engineer)\)[ \t]*$/ && (!att || (n in OPEN) || !(n in SEEN))) { ENG[++ne] = n ". " t (att && (n in OPEN) ? " — " OPEN[n] " in the latest attempt" : "") }
	next
}
inh && /^- Engineer/ { ineng = 1; next }
inh && /^- / && !/^- Engineer/ { ineng = 0 }
inh && ineng { STEPS = STEPS $0 "\n" }
END {
	if (ne == 0) { print "validation-checklist.sh: no open engineer checks for " WU > "/dev/stderr"; exit 1 }
	print "# " WU ": engineer checklist (draft)"
	print ""
	print "## Checks waiting on the engineer"
	for (i = 1; i <= ne; i++) print "- " ENG[i]
	print ""
	print "## Engineer steps (How to validate)"
	printf "%s", (STEPS == "" ? "(none in the unit block)\n" : STEPS)
	print ""
	print "## To validate notes (Step Log)"
	for (i = 1; i <= nt; i++) { t = TASKS[i]; if (TV[t] == "" || TV[t] ~ /^none\.?\n$/) continue
		print ""; print "### " (t in TITLE ? TITLE[t] : t); printf "%s", TV[t] }
}' "$work/unit"
