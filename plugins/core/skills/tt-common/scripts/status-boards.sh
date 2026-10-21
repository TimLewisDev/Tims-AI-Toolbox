#!/usr/bin/env bash
# status-boards.sh: print a new Task Status document's Work Unit Board and Task
# Board, built from a Task Breakdown's Work Units and Task Map tables, with
# every row Todo. Used by Task Status init, so no row is ever invented.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-boards.sh <task breakdown.md>

Reads the "## Work Units" table (ID, After this unit you can…, Tasks,
Validated by, Depends on) and the "## Task Map" table (ID, Task, Executor,
Depends on, Work unit, …), finding columns by their header text, and prints:

  # Work Unit Board
  | ID | Outcome | Tasks | Validated by | Status | Notes |
  # Task Board
  | ID | Task | Executor | Work unit | Depends on | Status | Notes |

With no Work Units table (a standalone plan), only the Task Board is printed,
without its Work unit column.
Exit: 0 printed, 1 no Task Map table found, 2 usage error.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
[ -f "$1" ] || { echo "status-boards.sh: no such file: $1" >&2; exit 2; }

awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cells(l, arr,   n, i, raw) {
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, raw, "|")
	for (i = 1; i <= n; i++) arr[i] = trim(raw[i])
	return n
}
function col(want,   i) { for (i = 1; i <= nh; i++) if (index(tolower(hdr[i]), want) == 1) return i; return 0 }
{ l = $0; sub(/\r$/, "", l) }
l ~ /^## / { sec = trim(substr(l, 4)); inhdr = 1; next }
l ~ /^#/ { sec = ""; next }
(sec == "Work Units" || sec == "Task Map") && l ~ /^[ \t]*\|/ {
	if (inhdr) { nh = cells(l, hdr); inhdr = 0; sep = 1; sec_kind = sec
		if (sec == "Work Units") { u_id = col("id"); u_out = col("after this unit"); u_tasks = col("tasks"); u_val = col("validated by") }
		else { t_id = col("id"); t_task = col("task"); t_exec = col("executor"); t_dep = col("depends on"); t_wu = col("work unit") }
		next }
	if (sep) { sep = 0; next }
	n = cells(l, c)
	# A row with no ID is a divider ("| **MR 2** | | |"), not a unit or task.
	if ((sec == "Work Units" ? c[u_id] : c[t_id]) == "") next
	if (sec == "Work Units") { nu++; U[nu] = sprintf("| %s | %s | %s | %s | Todo | |", c[u_id], c[u_out], c[u_tasks], c[u_val]) }
	else { nt++; T[nt] = c[t_id]; TT[nt] = c[t_task]; TE[nt] = c[t_exec]; TW[nt] = (t_wu ? c[t_wu] : ""); TD[nt] = c[t_dep] }
}
END {
	if (nt == 0) { print "status-boards.sh: no Task Map table found" > "/dev/stderr"; exit 1 }
	if (nu > 0) {
		print "# Work Unit Board"
		print "| ID | Outcome | Tasks | Validated by | Status | Notes |"
		print "|---|---|---|---|---|---|"
		for (i = 1; i <= nu; i++) print U[i]
		print ""
		print "# Task Board"
		print "| ID | Task | Executor | Work unit | Depends on | Status | Notes |"
		print "|---|---|---|---|---|---|---|"
		for (i = 1; i <= nt; i++) printf "| %s | %s | %s | %s | %s | Todo | |\n", T[i], TT[i], TE[i], TW[i], TD[i]
	} else {
		print "# Task Board"
		print "| ID | Task | Executor | Depends on | Status | Notes |"
		print "|---|---|---|---|---|---|"
		for (i = 1; i <= nt; i++) printf "| %s | %s | %s | %s | Todo | |\n", T[i], TT[i], TE[i], TD[i]
	}
}' "$1"
