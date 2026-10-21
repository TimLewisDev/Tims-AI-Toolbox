#!/usr/bin/env bash
# status-counts.sh: recompute a Task Status document's derived header fields
# from its boards, and report board inconsistencies.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-counts.sh <task status.md>

Reads the "# Work Unit Board" (ID, Outcome, Tasks, Validated by, Status, …) and
"# Task Board" (ID, Task, Executor, Work unit, …, Status, …) tables, finding
columns by header text, and prints the header fields they imply:

  State: …   Progress: …   Current Unit: …   Current Task: …   Next: …

then any inconsistencies, one per line, starting with "! ":
  a task in a Done unit that isn't Done or Dropped; a Done task in a unit that
  isn't Done; a unit Ready to Validate with a task not Implemented; a unit
  marked Blocked with no Blocked task; a unit In Progress with every task Todo.
Without a Work Unit Board (standalone), State and Progress follow the tasks.

Exit: 0 consistent, 1 inconsistencies found, 2 usage error.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
[ -f "$1" ] || { echo "status-counts.sh: no such file: $1" >&2; exit 2; }

awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cells(l, arr,   n, i, raw) {
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, raw, "|")
	for (i = 1; i <= n; i++) { arr[i] = trim(raw[i]); gsub(/`/, "", arr[i]) }
	return n
}
function col(want,   i) { for (i = 1; i <= nh; i++) if (index(tolower(hdr[i]), want) == 1) return i; return 0 }
function status_of(s) { gsub(/\*/, "", s); return trim(s) }
{ l = $0; sub(/\r$/, "", l) }
l ~ /^# / { sec = trim(substr(l, 3)); inhdr = 1; next }
(sec == "Work Unit Board" || sec == "Task Board") && l ~ /^[ \t]*\|/ {
	if (inhdr) { nh = cells(l, hdr); inhdr = 0; sep = 1
		if (sec == "Work Unit Board") { ui = col("id"); un = col("outcome"); ust = col("status") }
		else { ti = col("id"); tn = col("task"); tst = col("status"); tw = col("work unit"); tex = col("executor") }
		next }
	if (sep) { sep = 0; next }
	cells(l, c)
	if (sec == "Work Unit Board") { nu++; UID[nu] = c[ui]; UNAME[nu] = c[un]; UST[nu] = status_of(c[ust]) }
	else { nt++; TID[nt] = c[ti]; TNAME[nt] = c[tn]; TST[nt] = status_of(c[tst]); TWU[nt] = (tw ? c[tw] : ""); TEX[nt] = (tex ? c[tex] : "") }
}
function bad(msg) { print "! " msg; nbad++ }
END {
	if (nt == 0) { print "status-counts.sh: no Task Board found" > "/dev/stderr"; exit 2 }
	for (i = 1; i <= nt; i++) {
		if (TST[i] == "Dropped") continue
		tm++; if (TST[i] == "Implemented" || TST[i] == "Done") td++
		if (TST[i] == "In Progress" || TST[i] == "Blocked") if (curt == "") curt = TID[i] " — " TNAME[i]
		if (TST[i] != "Todo") anyt = 1
	}
	if (nu == 0) {
		alld = 1; for (i = 1; i <= nt; i++) { if (TST[i] != "Done" && TST[i] != "Dropped") alld = 0; if (TST[i] == "Blocked") blk = 1 }
		state = alld ? "Complete" : blk ? "Blocked" : anyt ? "In Progress" : "Not Started"
		for (i = 1; i <= nt && next_ == ""; i++) if (TST[i] == "Todo" || TST[i] == "In Progress") next_ = TID[i] " — " TNAME[i]
		printf "State: %s\nProgress: %d of %d tasks Done\nCurrent Task: %s\nNext: %s\n", state, td, tm, (curt == "" ? "None" : curt), (next_ == "" ? "None" : next_)
		exit 0
	}
	for (j = 1; j <= nu; j++) {
		u = UID[j]; nin = 0; nimpl = 0; nblk = 0; ntodo = 0
		for (i = 1; i <= nt; i++) {
			if (TWU[i] != u || TST[i] == "Dropped") continue
			nin++
			if (TST[i] == "Implemented" || TST[i] == "Done") nimpl++
			if (TST[i] == "Blocked") nblk++
			if (TST[i] == "Todo") ntodo++
			if (UST[j] == "Done" && TST[i] != "Done") bad(TID[i] " is " TST[i] " but " u " is Done")
			if (UST[j] != "Done" && TST[i] == "Done") bad(TID[i] " is Done but " u " is " UST[j])
		}
		if (UST[j] == "Ready to Validate" && nimpl < nin) bad(u " is Ready to Validate but " nin - nimpl " task(s) aren\047t Implemented")
		if (UST[j] == "Blocked" && nblk == 0) bad(u " is Blocked but none of its tasks is")
		if (nblk > 0 && UST[j] != "Blocked") bad(u " has a Blocked task but is " UST[j])
		if (UST[j] == "In Progress" && ntodo == nin && nin > 0) bad(u " is In Progress but every task is Todo")
		if (UST[j] == "Done") ud++
		if (UST[j] == "Blocked") ublk = 1
		if (UST[j] != "Todo") anyu = 1
		if (curu == "" && UST[j] != "Done" && UST[j] != "Todo") { curu = u; curuname = UNAME[j]; curust = UST[j] }
	}
	if (curu != "") {
		if (curust == "Ready to Validate") next_ = "Validate " curu
		else for (i = 1; i <= nt && next_ == ""; i++) if (TWU[i] == curu && (TST[i] == "Todo" || TST[i] == "In Progress" || TST[i] == "Blocked")) next_ = TID[i] " — " TNAME[i] (TEX[i] != "" ? " (" TEX[i] ")" : "")
		if (next_ == "") next_ = "Validate " curu
	} else for (j = 1; j <= nu && next_ == ""; j++) if (UST[j] == "Todo") next_ = "Start " UID[j] " — " UNAME[j]
	state = (ud == nu) ? "Complete" : ublk ? "Blocked" : (curust == "Ready to Validate") ? "Ready to Validate" : (anyu || anyt) ? "In Progress" : "Not Started"
	printf "State: %s\nProgress: %d of %d units Done · %d of %d tasks Implemented or Done\n", state, ud, nu, td, tm
	printf "Current Unit: %s\nCurrent Task: %s\nNext: %s\n", (curu == "" ? "None" : curu " — " curuname), (curt == "" ? "None" : curt), (next_ == "" ? "None" : next_)
	exit (nbad > 0 ? 1 : 0)
}' "$1"
