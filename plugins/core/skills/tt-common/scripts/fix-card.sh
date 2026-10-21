#!/usr/bin/env bash
# fix-card.sh: draft a fix task for a work unit whose validation failed: the
# next unused task ID, the table rows the breakdown and the Task Status need,
# and the card from the task-card template with every known field filled in.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: fix-card.sh <task breakdown.md> <WU> [--after <task ID>] [--check <n>] [--executor Agent|Engineer]

Prints, each under a "==== <what>" line, for the engineer-approved fix task:
  id          the next unused task number (highest T number + 1, same width);
  task map    the new "## Task Map" row (columns from its header; Depends on is
              --after, else the unit's last task);
  work units  the unit's new Tasks cell for "## Work Units" and the Work Unit
              Board;
  task board  the new "# Task Board" row (Status Todo);
  card        tt-task-breakdown's templates/task-card.md with ID, Executor,
              Work unit, Depends on and "Validated in" (with --check) filled.
Nothing is written: add the rows and the card (after the unit's last card)
through the amendment rules, then fill in the card's remaining <…> fields.

Exit: 0 printed, 2 usage error (unknown unit or task, no template).
EOF
	exit 2
}

die() { echo "fix-card.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
bd=$1; wu=$2; shift 2
after=""; check=""; ex=Agent
while [ $# -gt 0 ]; do
	case "$1" in
		--after) after=${2:?}; shift 2 ;;
		--check) check=${2:?}; shift 2 ;;
		--executor) ex=${2:?}; shift 2 ;;
		*) usage ;;
	esac
done
case "$ex" in Agent | Engineer) ;; *) die "executor must be Agent or Engineer" ;; esac
[ -f "$bd" ] || die "no such file: $bd"
here=$(cd "$(dirname "$0")" && pwd)
. "$here/tt-path.sh"
tpl="$(tt_find tt-task-breakdown || true)/templates/task-card.md"
[ -f "$tpl" ] || die "no task-card template (is engineering installed?): $tpl"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$bd" >"$work/bd"

# One pass over the two tables: the Task Map header and rows, and the unit's Tasks.
awk -v WU="$wu" -v OUT="$work" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cells(l, arr,   n, i, raw) {
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, raw, "|")
	for (i = 1; i <= n; i++) { arr[i] = trim(raw[i]); gsub(/`/, "", arr[i]) }
	return n
}
/^## / { sec = trim(substr($0, 4)); inhdr = 1; next }
(sec == "Task Map" || sec == "Work Units") && /^[ \t]*\|/ {
	if (inhdr) { n = cells($0, h); inhdr = 0; sep = 1
		if (sec == "Task Map") { mh = n; for (i = 1; i <= n; i++) { mhdr[i] = h[i]; k = tolower(h[i]); if (k == "id") mi = i; else if (index(k, "work unit") == 1) mw = i } }
		else for (i = 1; i <= n; i++) { k = tolower(h[i]); if (k == "id") ui = i; else if (k == "tasks") ut = i }
		next }
	if (sep) { sep = 0; next }
	cells($0, c)
	if (sec == "Task Map") { if (c[mi] ~ /^T[0-9]/) { print c[mi] "\t" c[mw] > (OUT "/tasks") } }
	else if (c[ui] == WU) { print c[ut] > (OUT "/unit"); found = 1 }
}
END {
	for (i = 1; i <= mh; i++) printf "%s%s", (i > 1 ? "\t" : ""), mhdr[i] > (OUT "/maphdr")
	printf "\n" > (OUT "/maphdr")
	exit (found ? 0 : 3)
}' "$work/bd" || die "no $wu in the breakdown's Work Units"
[ -s "$work/tasks" ] || die "no tasks in the breakdown's Task Map"

width=$(cut -f1 "$work/tasks" | sed -n 's/^T\([0-9]*\).*/\1/p' | awk '{ if (length($0) > w) w = length($0) } END { print w }')
max=$(cut -f1 "$work/tasks" | sed -n 's/^T\([0-9]*\).*/\1/p' | sed 's/^0*//; s/^$/0/' | sort -n | tail -n 1)
new=$(printf "T%0${width}d" $((max + 1)))
if [ -z "$after" ]; then
	after=$(awk -F '\t' -v WU="$wu" '$2 == WU { t = $1 } END { print t }' "$work/tasks")
	[ -n "$after" ] || after="—"
elif ! cut -f1 "$work/tasks" | grep -qx -- "$after"; then
	die "no $after in the breakdown's Task Map"
fi
tasks=$(cat "$work/unit")
case "$tasks" in "" | "—" | "-") tasks=$new ;; *) tasks="$tasks, $new" ;; esac

echo "==== id"
echo "$new"
echo "==== task map"
awk -F '\t' -v ID="$new" -v EX="$ex" -v DEP="$after" -v WU="$wu" '{
	printf "|"
	for (i = 1; i <= NF; i++) {
		k = tolower($i)
		v = (k == "id") ? ID : (k == "task") ? "<title>" : (k == "executor") ? EX : (index(k, "depends") == 1) ? DEP : (index(k, "work unit") == 1) ? WU : "<" $i ">"
		printf " %s |", v
	}
	printf "\n"
}' "$work/maphdr"
echo "==== work units"
echo "$wu Tasks: $tasks"
echo "==== task board"
echo "| $new | <title> | $ex | $wu | $after | Todo | |"
echo "==== card"
validated="$wu"
[ -n "$check" ] && validated="$wu, checks $check"
awk '/^```/ { if (in_) exit; in_ = 1; next } in_' "$tpl" | awk -v ID="$new" -v EX="$ex" -v WU="$wu" -v DEP="$after" -v VAL="$validated" '
function rep(s, k, v,   res, p) { res = ""; while ((p = index(s, k)) > 0) { res = res substr(s, 1, p - 1) v; s = substr(s, p + length(k)) } return res s }
{
	l = $0
	if (l ~ /^\*\*Validated in:\*\*/) { print "**Validated in:** " VAL; next }
	if (l ~ /^\| \*\*Executor\*\* \|/) { print "| **Executor** | " EX " |"; next }
	l = rep(l, "<ID>", ID); l = rep(l, "<WU ID>", WU); l = rep(l, "<IDs, or —>", DEP)
	print l
}'
