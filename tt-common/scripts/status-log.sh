#!/usr/bin/env bash
# status-log.sh: apply a coder subagent's result file to a Task
# Status document: the task's Step Log entry, its risks and its identified
# improvements, then the task's status (through status-set.sh). The
# orchestrator never re-types the result.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-log.sh <task status.md> <result.md> [--no-set]

<result.md> is a delegated result file (tt-coder's
templates/result.md): "# Result: <ID> — <title>", a "- Task status:" line,
and the sections Files Modified, Summary, To validate, Follow-up Concerns,
Risks, Improvements and Critical Decision.

It writes, in one atomic write:
  - the "## <ID> — <title>" entry under "# Step Log" (title from the Task
    Board), replacing an existing entry for the task or appending a new one:
    Status, Files Modified, Summary, Validation (the result's, else
    "Deferred to <unit>"), To validate, Follow-up Concerns;
  - each risk as a bullet under the header's "- Outstanding Risks:", tagged
    "(<ID>, <date>)";
  - each improvement as "## Improvement <n>" under "# Identified Improvements".
Then, unless --no-set, runs status-set.sh to set the task's status from the
result (implemented -> Implemented, blocked -> Blocked, interrupted -> In
Progress), which also recomputes the header.

A Critical Decision is not recorded: it is reported, for the orchestrator to
present to the engineer. Prints one line per change; never prints content.

Exit: 0 applied, 1 applied but the boards are inconsistent, 2 usage error or
nothing written (bad result file, unknown task).
EOF
	exit 2
}

die() { echo "status-log.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
doc=$1; res=$2; shift 2
noset=0
while [ $# -gt 0 ]; do case "$1" in --no-set) noset=1; shift ;; *) usage ;; esac; done
[ -f "$doc" ] || die "no such file: $doc"
[ -f "$res" ] || die "no such result file: $res"
grep -q "<!-- fill:" "$res" && die "unfilled <!-- fill: --> markers in $res"
here=$(cd "$(dirname "$0")" && pwd)

crlf=0
[ "$(head -c 4096 "$doc" | tr -dc '\r' | wc -c)" -gt 0 ] && crlf=1
dir=$(dirname "$doc")
t1=$(mktemp "$dir/.status-log.XXXXXX"); t2=$(mktemp "$dir/.status-log.XXXXXX")
work=$(mktemp -d)
trap 'rm -rf "$t1" "$t2" "$work"' EXIT
tr -d '\r' <"$doc" >"$t1"

# 1. Parse the result file into the entry body, the risks and the improvements.
meta=$(tr -d '\r' <"$res" | awk -v BODY="$work/body" -v RISKS="$work/risks" -v IMPS="$work/imps" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function isnone(s) { s = tolower(trim(s)); gsub(/[`*_.]/, "", s); return s == "none" || s == "" || s == "- none" }
function field(name, key,   n, i, first, last, one) {
	n = cnt[key]; first = 1; last = n
	while (first <= n && trim(L[key, first]) == "") first++
	while (last >= first && trim(L[key, last]) == "") last--
	if (first > last) { print "- " name ": none" > BODY; return }
	if (first == last && isnone(L[key, first])) { print "- " name ": none" > BODY; return }
	one = trim(L[key, first])
	if (first == last && one !~ /^([-*+]|[0-9]+\.)[ \t]/ && key != "files modified") { print "- " name ": " one > BODY; return }
	print "- " name ":" > BODY
	for (i = first; i <= last; i++) print (trim(L[key, i]) == "" ? "" : "  " L[key, i]) > BODY
}
/^# Result:/ {
	h = $0; sub(/^# Result:[ \t]*/, "", h); id = h; sub(/[ \t]+—.*$/, "", id); gsub(/[`*]/, "", id); id = trim(id); next
}
sec == "" && /^- Task status:/ { ts = tolower(trim(substr($0, 16))); next }
sec == "" && /^- Validation:/ { val = trim(substr($0, 14)); next }
/^## / { sec = tolower(trim(substr($0, 4))); imp = 0; next }
sec == "improvements" && /^### / { nimp++; imp = nimp; IN[imp] = trim(substr($0, 5)); next }
sec == "improvements" && imp && /^- [A-Za-z\/ ]+:/ { IL[imp] = IL[imp] $0 "\n"; next }
sec == "risks" && /^[-*][ \t]/ { r = trim(substr($0, 3)); if (!isnone(r)) { nr++; print r > RISKS }; next }
sec != "" { cnt[sec]++; L[sec, cnt[sec]] = $0; if (sec == "critical decision" && !isnone($0)) cd = 1 }
END {
	if (id == "") { print "status-log.sh: no \"# Result: <ID> — <title>\" line" > "/dev/stderr"; exit 2 }
	if (ts !~ /^(implemented|blocked|interrupted)$/) { print "status-log.sh: Task status must be implemented, blocked or interrupted, not: " ts > "/dev/stderr"; exit 2 }
	field("Files Modified", "files modified")
	field("Summary", "summary")
	print "- Validation: @VALIDATION@" > BODY
	field("To validate", "to validate")
	field("Follow-up Concerns", "follow-up concerns")
	for (i = 1; i <= nimp; i++) {
		if (IL[i] == "" && isnone(IN[i])) continue
		printf "%s", (IL[i] == "" ? "- Description: " IN[i] "\n" : IL[i]) > IMPS; print "@@" > IMPS; ni++
	}
	printf "%s\037%s\037%s\037%d\037%d\n", id, ts, (val == "" ? "-" : val), cd, ni
}') || exit 2
IFS=$'\037' read -r id ts val cd ni <<<"$meta"
[ "$val" = - ] && val=""
case "$ts" in implemented) st=Implemented ;; blocked) st=Blocked ;; *) st="In Progress" ;; esac
touch "$work/risks" "$work/imps"
today=$(date '+%Y-%m-%d')

# 2. Splice the entry, the risks and the improvements into the document.
awk -v NI="$ni" -v ID="$id" -v ST="$st" -v VAL="$val" -v TODAY="$today" -v BODY="$work/body" -v RISKS="$work/risks" -v IMPS="$work/imps" -v REPORT="$work/report" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
function split_row(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|"); for (i = 1; i <= n; i++) gsub(/\001/, "\\|", arr[i])
	return n
}
function col(want, h, nh,   i) { for (i = 1; i <= nh; i++) if (index(tolower(plain(h[i])), want) == 1) return i; return 0 }
function blanks() { for (; bl > 0; bl--) print "" }
function entry(   l) {
	print "## " ID " — " TITLE; print "- Status: " ST
	while ((getline l < BODY) > 0) { if (l == "- Validation: @VALIDATION@") l = "- Validation: " (VAL != "" ? VAL : (UNIT != "" ? "Deferred to " UNIT : "none")); print l }
	close(BODY)
}
# Improvements and risks already in the document (a result applied twice)
# are skipped.
function imps(   l, k, blk, d) {
	k = maxn; blk = ""; d = ""
	while ((getline l < IMPS) > 0) {
		if (l == "@@") {
			if (!(d in HAVEI)) { k++; print "## Improvement " k; printf "%s", blk; print ""; nimp++; HAVEI[d] = 1 }
			blk = ""; d = ""; continue
		}
		blk = blk l "\n"; if (l ~ /^- Description:/) d = trim(substr(l, 15))
	}
	close(IMPS)
}
function emit_risks(   i) { for (i = 1; i <= nnew; i++) print "  - " NEWR[i] " (" ID ", " TODAY ")" }
FNR == 1 { pass++ }
/^# / { sec = trim(substr($0, 3)); hdr = 1 }
pass == 1 && sec == "Task Board" && /^[ \t]*\|/ {
	if (hdr) { nh = split_row($0, h); hdr = 0; sep = 1; ti = col("id", h, nh); tt = col("task", h, nh); tw = col("work unit", h, nh); next }
	if (sep) { sep = 0; next }
	split_row($0, c); if (plain(c[ti]) == ID) { TITLE = trim(c[tt]); UNIT = (tw ? plain(c[tw]) : ""); found = 1 }
	next
}
pass == 1 && sec == "Step Log" && /^## / { e = substr($0, 4); sub(/[ \t]+—.*$/, "", e); if (plain(e) == ID) had = 1; next }
pass == 1 && sec == "Identified Improvements" && /^## Improvement [0-9]+/ { n = $3 + 0; if (n > maxn) maxn = n; next }
pass == 1 && sec == "Identified Improvements" && /^- Description:/ { HAVEI[trim(substr($0, 15))] = 1; next }
pass == 1 && sec == "Status" && /^[ \t]+[-*] / {
	r = trim($0); sub(/^[-*] /, "", r); tag = " (" ID ", "
	if ((p = index(r, tag)) > 0) HAVER[substr(r, 1, p - 1)] = 1
	next
}
pass == 1 { next }
pass == 2 && FNR == 1 {
	if (!found) { print "status-log.sh: " ID " is not on the Task Board" > "/dev/stderr"; failed = 1; exit 2 }
	while ((getline l < RISKS) > 0) if (!(l in HAVER)) { NEWR[++nnew] = l; HAVER[l] = 1 }
	close(RISKS)
}
# Outstanding Risks: append bullets after the existing ones.
pass == 2 && inrisks { if ($0 ~ /^[ \t]+[-*]/) { print; next }; emit_risks(); inrisks = 0 }
pass == 2 && sec == "Status" && /^- Outstanding Risks:/ {
	v = trim(substr($0, 21))
	if (nnew > 0) { if (tolower(v) == "none" || v == "") $0 = "- Outstanding Risks:"; print; inrisks = 1; next }
	print; next
}
# Step Log: replace the entry, or append it at the end of the section.
pass == 2 && skip { if ($0 ~ /^#{1,2} /) skip = 0; else next }
pass == 2 && $0 == "" { bl++; next }
pass == 2 && /^# / {
	if (prevsec == "Step Log" && !done) { print ""; entry(); print ""; done = 1; bl = 0; ok = "appended" }
	if (prevsec == "Identified Improvements" && !idone && NI > 0) { print ""; imps(); idone = 1; bl = 0 }
	blanks(); print; prevsec = sec; next
}
pass == 2 && sec == "Step Log" && /^## / {
	e = substr($0, 4); sub(/[ \t]+—.*$/, "", e)
	if (plain(e) == ID) { blanks(); entry(); done = 1; skip = 1; ok = "replaced"; bl = 1; next }
}
pass == 2 { blanks(); print }
END {
	if (failed || pass < 2) exit 2
	if (inrisks) emit_risks()
	if (sec == "Step Log" && !done) { print ""; entry(); done = 1; ok = "appended" }
	if (sec == "Identified Improvements" && !idone && NI > 0) { print ""; imps(); idone = 1 }
	if (!done) { print "status-log.sh: no \"# Step Log\" section" > "/dev/stderr"; exit 2 }
	printf "step log: %s %s\n", ID, ok > REPORT
	if (nnew > 0) printf "risks: %d added\n", nnew > REPORT
	if (nimp > 0) printf "improvements: %d added\n", nimp > REPORT
}' "$t1" "$t1" >"$t2" || exit 2

[ -s "$work/report" ] || die "nothing written"
if [ "$crlf" = 1 ]; then sed 's/$/\r/' "$t2" >"$t1"; mv "$t1" "$doc"; else mv "$t2" "$doc"; fi
cat "$work/report"
if [ "$cd" = 1 ]; then echo "critical decision: yes, in $res; present it to the engineer"; else echo "critical decision: none"; fi

[ "$noset" = 1 ] && exit 0
bash "$here/status-set.sh" "$doc" "$id" "$st"
