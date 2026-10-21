#!/usr/bin/env bash
# status-set.sh: set a task's or work unit's status in a Task Status document,
# apply the rules that tie tasks and units together, and recompute the derived
# header fields and Resume Here, in one atomic write.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-set.sh <task status.md> <ID> <Status> [--note <text>]
       status-set.sh <task status.md> --refresh

Sets the Status cell of the <ID> row in the "# Task Board" or the
"# Work Unit Board" (and its Notes cell, with --note; --note "" clears it),
then:
  - a task's Step Log entry ("## <ID> —") gets the same "- Status:" line;
  - a unit set to Done marks each of its tasks Done (Dropped ones excepted),
    with their Step Log Status lines;
  - a task change moves its unit: Todo -> In Progress when a task starts,
    -> Blocked while any task is Blocked, Blocked -> In Progress when none is.
    Ready to Validate, Failed and Done are only ever set explicitly.
  - the "# Status" header lines State, Progress, Current Unit, Current Task,
    Next, Last Updated and Blocking Decisions are recomputed (status-counts.sh),
    and Resume Here's "1. Read this document, then <unit>" and
    "4. Next action:" lines follow them.
--refresh only recomputes the derived fields.

Task statuses: Todo, In Progress, Blocked, Implemented, Done, Dropped.
Unit statuses: Todo, In Progress, Blocked, Ready to Validate, Failed, Done.
A task under a work unit becomes Done only through its unit.
Line endings are kept. Prints one line per change; never prints content.

Exit: 0 written, 1 written but the boards are inconsistent (the "! " lines
from status-counts.sh are printed), 2 usage error or nothing written.
EOF
	exit 2
}

die() { echo "status-set.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
doc=$1; shift
case "${1:-}" in -h | --help) usage ;; esac
[ -f "$doc" ] || die "no such file: $doc"
here=$(cd "$(dirname "$0")" && pwd)

id=""; new=""; note=""; hasnote=0; refresh=0
if [ "$1" = --refresh ]; then
	refresh=1; shift
	[ $# -eq 0 ] || usage
else
	[ $# -ge 2 ] || usage
	id=$1; new=$2; shift 2
	while [ $# -gt 0 ]; do
		case "$1" in
			--note) note=${2?}; hasnote=1; shift 2 ;;
			*) usage ;;
		esac
	done
fi

crlf=0
[ "$(head -c 4096 "$doc" | tr -dc '\r' | wc -c)" -gt 0 ] && crlf=1
dir=$(dirname "$doc")
t1=$(mktemp "$dir/.status-set.XXXXXX"); t2=$(mktemp "$dir/.status-set.XXXXXX"); t3=$(mktemp)
trap 'rm -f "$t1" "$t2" "$t3"' EXIT
tr -d '\r' <"$doc" >"$t1"

if [ "$refresh" = 0 ]; then
	# Pass 1 reads the boards; pass 2 writes the file with the changes.
	if ! awk -v REPORT="$t3" -v ID="$id" -v NEW="$new" -v NOTE="$note" -v HASNOTE="$hasnote" '
	function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
	function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
	# split a table row into cells; escaped pipes stay inside their cell
	function split_row(l, arr,   n, i) {
		gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
		n = split(l, arr, "|"); for (i = 1; i <= n; i++) gsub(/\001/, "\\|", arr[i])
		return n
	}
	function join_row(arr, n,   i, s) { s = "|"; for (i = 1; i <= n; i++) s = s arr[i] "|"; return s }
	function col(want, h, nh,   i) { for (i = 1; i <= nh; i++) if (index(tolower(plain(h[i])), want) == 1) return i; return 0 }
	function set_cell(arr, i, v) { arr[i] = (v == "" ? " " : " " v " ") }
	BEGIN { TS["Todo"]; TS["In Progress"]; TS["Blocked"]; TS["Implemented"]; TS["Done"]; TS["Dropped"]
		US["Todo"]; US["In Progress"]; US["Blocked"]; US["Ready to Validate"]; US["Failed"]; US["Done"] }
	FNR == 1 { pass++ }
	/^# / { sec = trim(substr($0, 3)); hdr = 1 }
	pass == 1 && (sec == "Task Board" || sec == "Work Unit Board") && /^[ \t]*\|/ {
		if (hdr) { nh = split_row($0, h); hdr = 0; sep = 1
			if (sec == "Task Board") { tid = col("id", h, nh); tst = col("status", h, nh); twu = col("work unit", h, nh) }
			else { uid = col("id", h, nh); ust = col("status", h, nh); utk = col("tasks", h, nh) }
			next }
		if (sep) { sep = 0; next }
		split_row($0, c)
		if (sec == "Task Board") { k = plain(c[tid]); nt++; T[nt] = k; TSt[k] = plain(c[tst]); TU[k] = (twu ? plain(c[twu]) : "") }
		else { k = plain(c[uid]); nu++; U[nu] = k; USt[k] = plain(c[ust]) }
		next
	}
	pass == 1 { next }
	pass == 2 && FNR == 1 {
		# Work out every change before writing anything.
		if (ID in TSt) {
			if (!(NEW in TS)) { print "status-set.sh: not a task status: " NEW > "/dev/stderr"; exit 2 }
			u = TU[ID]
			if (NEW == "Done" && u != "") { print "status-set.sh: " ID " becomes Done only with its unit; set " u " Done" > "/dev/stderr"; exit 2 }
			chg[ID] = NEW; target = "task"
			if (u != "" && (u in USt)) {
				ublk = 0; ustarted = 0
				for (i = 1; i <= nt; i++) { t = T[i]; if (TU[t] != u) continue
					s = (t == ID) ? NEW : TSt[t]
					if (s == "Blocked") ublk = 1
					if (s != "Todo" && s != "Dropped") ustarted = 1 }
				us = USt[u]
				if (us != "Done") {
					if (ublk && us != "Blocked") chg[u] = "Blocked"
					else if (!ublk && us == "Blocked") chg[u] = "In Progress"
					else if (us == "Todo" && ustarted) chg[u] = "In Progress"
				}
			}
		} else if (ID in USt) {
			if (!(NEW in US)) { print "status-set.sh: not a work unit status: " NEW > "/dev/stderr"; exit 2 }
			chg[ID] = NEW; target = "unit"
			if (NEW == "Done") for (i = 1; i <= nt; i++) { t = T[i]; if (TU[t] == ID && TSt[t] != "Dropped" && TSt[t] != "Done") chg[t] = "Done" }
		} else { print "status-set.sh: no board row for " ID > "/dev/stderr"; exit 2 }
		for (k in chg) {
			old = (k in TSt) ? TSt[k] : USt[k]
			if (old != chg[k]) printf "%s: %s -> %s\n", k, old, chg[k] > REPORT
			else if (k != ID) delete chg[k]
		}
		if (HASNOTE) printf "%s: note %s\n", ID, (NOTE == "" ? "cleared" : "set") > REPORT
	}
	pass == 2 && (sec == "Task Board" || sec == "Work Unit Board") && /^[ \t]*\|/ {
		if (hdr) { nh = split_row($0, h); hdr = 0; sep = 1
			bid = col("id", h, nh); bst = col("status", h, nh); bno = col("notes", h, nh)
			print; next }
		if (sep) { sep = 0; print; next }
		n = split_row($0, c); k = plain(c[bid])
		if (k in chg) {
			set_cell(c, bst, chg[k])
			if (k == ID && HASNOTE && bno) set_cell(c, bno, NOTE)
			print join_row(c, n); next
		}
		print; next
	}
	pass == 2 && sec == "Step Log" && /^## / {
		e = substr($0, 4); sub(/[ \t]+—.*$/, "", e); entry = plain(e); print; next
	}
	pass == 2 && sec == "Step Log" && /^- Status:/ && (entry in chg) { print "- Status: " chg[entry]; next }
	pass == 2 { print }
	' "$t1" "$t1" >"$t2"; then
		exit 2
	fi
	cp "$t2" "$t1"; sort -u "$t3"
fi

# Derived fields from the (new) boards.
set +e
derived=$(bash "$here/status-counts.sh" "$t1")
rc=$?
set -e
[ "$rc" -le 1 ] || die "status-counts.sh failed on the boards"
now=$(date '+%Y-%m-%d %H:%M')

awk -v D="$derived" -v NOW="$now" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
function split_row(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|"); for (i = 1; i <= n; i++) gsub(/\001/, "\\|", arr[i])
	return n
}
function col(want, h, nh,   i) { for (i = 1; i <= nh; i++) if (index(tolower(plain(h[i])), want) == 1) return i; return 0 }
BEGIN {
	n = split(D, L, "\n")
	for (i = 1; i <= n; i++) if (L[i] !~ /^! / && match(L[i], /^[A-Za-z ]+: /)) { k = substr(L[i], 1, RLENGTH - 2); V[k] = substr(L[i], RLENGTH + 1) }
	V["Last Updated"] = NOW
	cu = V["Current Unit"]; sub(/[ \t]+—.*$/, "", cu)
	if (cu == "None" || cu == "") { cu = V["Next"]; sub(/^Start /, "", cu); sub(/[ \t]+—.*$/, "", cu); if (cu !~ /^WU/) cu = "" }
}
FNR == 1 { pass++ }
/^# / { sec = trim(substr($0, 3)); hdr = 1 }
# Pass 1: Blocking Decisions come from the Blocked task rows and their notes.
pass == 1 && sec == "Task Board" && /^[ \t]*\|/ {
	if (hdr) { nh = split_row($0, h); hdr = 0; sep = 1; tid = col("id", h, nh); tst = col("status", h, nh); tno = col("notes", h, nh); next }
	if (sep) { sep = 0; next }
	split_row($0, c)
	if (plain(c[tst]) == "Blocked") { b = plain(c[tid]); nn = (tno ? trim(c[tno]) : ""); blk = blk (blk == "" ? "" : "; ") b (nn == "" ? "" : " (" nn ")") }
	next
}
pass == 1 { next }
pass == 2 && FNR == 1 { V["Blocking Decisions"] = (blk == "" ? "None" : blk) }
pass == 2 && skipping { if (/^[ \t]+[-*0-9]/) next; skipping = 0 }
# A value that already starts with the derived one keeps its annotation
# ("None (T14 Implemented)", "Validate WU5 (Agent + Engineer)").
pass == 2 && sec == "Status" && match($0, /^- [A-Za-z ]+:/) {
	k = substr($0, 3, RLENGTH - 3); cur = trim(substr($0, RLENGTH + 1))
	if ((k in V) && k != "Last Updated" && index(cur, V[k]) == 1) next_keep = 1; else next_keep = 0
	if ((k in V) && !next_keep) { print "- " k ": " V[k]; if (k == "Blocking Decisions") skipping = 1; next }
}
pass == 2 && sec == "Resume Here" && /^1\. / && cu != "" { sub(/then WU[0-9]+[a-z]?/, "then " cu) }
# The next action is rewritten only when it no longer names the next step.
pass == 2 && sec == "Resume Here" && /^4\. Next action:/ {
	nx = V["Next"]; sub(/[ \t]+\(.*$/, "", nx)
	if (index(tolower($0), tolower(nx)) == 0) { print "4. Next action: " V["Next"] "."; next }
}
pass == 2 { print }
' "$t1" "$t1" >"$t2"

if [ "$crlf" = 1 ]; then sed 's/$/\r/' "$t2" >"$t1"; mv "$t1" "$doc"; else mv "$t2" "$doc"; fi
printf '%s\n' "$derived" | grep -v '^! ' | sed -n 's/^\(State\|Next\): /header \1: /p'
# Stage-completion events (tt-common/events.md): a unit set Done, and a finished
# feature. Best-effort: nothing here can change the output or the exit code.
dname=$(basename "$doc")
case $dname in
*" - Task Status.md")
	prefix=${dname% - Task Status.md}
	{
		case $id in WU*) [ "$new" = Done ] && bash "$here/tt-event.sh" emit build.unit_validated --prefix "$prefix" --folder "$dir" --qualifier "$id" --skill tt-execute ;; esac
		printf '%s\n' "$derived" | grep -q '^State: Complete' &&
			bash "$here/tt-event.sh" emit build.complete --prefix "$prefix" --folder "$dir" --skill tt-execute
	} >/dev/null 2>&1 || true ;;
esac
if [ "$rc" = 1 ]; then printf '%s\n' "$derived" | grep '^! ' >&2; exit 1; fi
exit 0
