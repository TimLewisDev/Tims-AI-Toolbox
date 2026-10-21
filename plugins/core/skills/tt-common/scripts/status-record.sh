#!/usr/bin/env bash
# status-record.sh: add one record to a Task Status document (a decision, a
# breakdown change, a risk, an improvement, a work-unit validation attempt or
# one check's result), then refresh the derived header, in one atomic write.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-record.sh <status.md> decision --decision <text> --resolution <text> --affects <text> [--date <d>]
       status-record.sh <status.md> change --affects <text> --change <text> --why <text> --approved-by <text> [--date <d>]
       status-record.sh <status.md> risk --add <text> [--by <ID>]
       status-record.sh <status.md> risk --close <text> --how <text>
       status-record.sh <status.md> improvement --description <t> --benefits <t> --risks <t> --why <t>
       status-record.sh <status.md> validation <WU> --file <attempt.md>
       status-record.sh <status.md> check <WU> <n> <passed|failed|pending|waived|blocked> [--evidence <text>]

decision     A row in "# Decisions Taken", numbered D<n> after the highest one.
change       A row in "# Breakdown Changes".
risk --add   A bullet under the header's "- Outstanding Risks:".
risk --close Marks the first risk bullet containing <text> closed, with how.
improvement  "## Improvement <n>" under "# Identified Improvements".
validation   "### Attempt <n>" under "## <WU> — <name>" in "# Work Unit
             Validation" (the heading is added if missing), from an attempt
             file such as run-checks.sh writes: "- Run:", "- Results:" with
             "  - Check <n> (<text>) [<who>]: <result>…" lines, "- Outcome:".
check        Sets check <n>'s result in the unit's latest attempt (keeping
             its text), then recomputes that attempt's Outcome: Failed if any
             check failed, else "Pending (checks …)" while any is pending or
             blocked, else Done.
Dates default to today. Table cells have "|" escaped. Line endings are kept.
After the write, status-set.sh --refresh recomputes the header.

Exit: 0 recorded, 1 recorded but the boards are inconsistent, 2 usage error
or nothing written.
EOF
	exit 2
}

die() { echo "status-record.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
doc=$1; kind=$2; shift 2
[ -f "$doc" ] || die "no such file: $doc"
here=$(cd "$(dirname "$0")" && pwd)
today=$(date '+%Y-%m-%d')

declare -A A=()
wu=""; n=""; result=""
case "$kind" in
	validation) [ $# -ge 1 ] || usage; wu=$1; shift ;;
	check) [ $# -ge 3 ] || usage; wu=$1; n=$2; result=$3; shift 3
		case "$result" in passed | failed | pending | waived | blocked) ;; *) die "not a check result: $result" ;; esac
		case "$n" in '' | *[!0-9]*) die "not a check number: $n" ;; esac ;;
	decision | change | risk | improvement) ;;
	*) usage ;;
esac
while [ $# -gt 0 ]; do
	case "$1" in
		--decision | --resolution | --affects | --date | --change | --why | --approved-by | --add | --by | --close | --how | --description | --benefits | --risks | --file | --evidence)
			[ $# -ge 2 ] || usage; A[${1#--}]=$2; shift 2 ;;
		*) usage ;;
	esac
done
need() { for k in "$@"; do [ -n "${A[$k]:-}" ] || die "$kind needs --$k"; done; }
case "$kind" in
	decision) need decision resolution affects ;;
	change) need affects change why approved-by ;;
	risk) if [ -n "${A[add]:-}" ]; then :; elif [ -n "${A[close]:-}" ]; then need how; else die "risk needs --add or --close"; fi ;;
	improvement) need description benefits risks why ;;
	validation) need file; [ -f "${A[file]}" ] || die "no such attempt file: ${A[file]}" ;;
esac

crlf=0
[ "$(head -c 4096 "$doc" | tr -dc '\r' | wc -c)" -gt 0 ] && crlf=1
dir=$(dirname "$doc")
t1=$(mktemp "$dir/.status-record.XXXXXX"); t2=$(mktemp "$dir/.status-record.XXXXXX"); rep=$(mktemp)
trap 'rm -f "$t1" "$t2" "$rep"' EXIT
tr -d '\r' <"$doc" >"$t1"
attempt=/dev/null
[ "$kind" = validation ] && attempt=${A[file]}

# Values go through the environment so backslashes and quotes survive.
export SR_KIND=$kind SR_WU=$wu SR_N=$n SR_RESULT=$result SR_TODAY=$today
for k in decision resolution affects date change why approved-by add by close how description benefits risks evidence; do
	v=${A[$k]:-}; export "SR_$(printf '%s' "$k" | tr 'a-z-' 'A-Z_')=$v"
done

tr -d '\r' <"$attempt" | awk -v REPORT="$rep" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
function cell(s) { gsub(/\|/, "\\|", s); gsub(/\n/, " ", s); return s }
function E(k) { return ENVIRON["SR_" k] }
function split_row(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|"); for (i = 1; i <= n; i++) gsub(/\001/, "\\|", arr[i])
	return n
}
function fail(m) { print "status-record.sh: " m > "/dev/stderr"; failed = 1; exit 2 }
function blanks() { for (; bl > 0; bl--) print "" }
# The row, bullet or block to add, built once pass 1 has read the document.
function build(   d) {
	date = (E("DATE") != "" ? E("DATE") : E("TODAY"))
	if (KIND == "decision") { did = "D" (maxd + 1); ROW = "| " did " | " cell(E("DECISION")) " | " cell(E("RESOLUTION")) " | " cell(E("AFFECTS")) " | " date " |"; TARGET = "Decisions Taken"; MSG = "decision " did " recorded" }
	if (KIND == "change") { ROW = "| " date " | " cell(E("AFFECTS")) " | " cell(E("CHANGE")) " | " cell(E("WHY")) " | " cell(E("APPROVED_BY")) " |"; TARGET = "Breakdown Changes"; MSG = "breakdown change recorded" }
	if (KIND == "improvement") { BLOCK = "## Improvement " (maxi + 1) "\n- Description: " E("DESCRIPTION") "\n- Benefits: " E("BENEFITS") "\n- Risks/Tradeoffs: " E("RISKS") "\n- Why High Impact: " E("WHY"); TARGET = "Identified Improvements"; MSG = "improvement " (maxi + 1) " recorded" }
	if (KIND == "validation") {
		if (!(WU in UNAME)) fail(WU " is not on the Work Unit Board")
		an = natt[WU] + 1
		BLOCK = "### Attempt " an "\n" ATT
		if (!(WU in HASWU)) BLOCK = "## " WU " — " UNAME[WU] "\n\n" BLOCK
		TARGET = "Work Unit Validation"; MSG = WU " attempt " an " recorded"
	}
}
BEGIN { KIND = E("KIND"); WU = E("WU") }
# The attempt file comes first on stdin ("-"); then the document, twice.
FILENAME == "-" { l = $0; if (trim(l) != "" || ATT != "") ATT = ATT l "\n"; next }
FNR == 1 { pass++; if (pass == 1) { sub(/\n+$/, "", ATT) } }
/^# / { sec = trim(substr($0, 3)); hdr = 1 }
pass == 1 && sec == "Work Unit Board" && /^[ \t]*\|/ {
	if (hdr) { hdr = 0; sep = 1; next }
	if (sep) { sep = 0; next }
	split_row($0, c); UNAME[plain(c[1])] = trim(c[2]); next
}
pass == 1 && sec == "Decisions Taken" && /^[ \t]*\| *D[0-9]+ *\|/ { split_row($0, c); v = plain(c[1]); sub(/^D/, "", v); if (v + 0 > maxd) maxd = v + 0; next }
pass == 1 && sec == "Identified Improvements" && /^## Improvement [0-9]+/ { if ($3 + 0 > maxi) maxi = $3 + 0; next }
pass == 1 && sec == "Work Unit Validation" && /^## / { u = substr($0, 4); sub(/[ \t]+—.*$/, "", u); cur = plain(u); HASWU[cur] = 1; next }
pass == 1 && sec == "Work Unit Validation" && /^### Attempt [0-9]+/ { if ($3 + 0 > natt[cur]) natt[cur] = $3 + 0; next }
pass == 1 { next }
pass == 2 && FNR == 1 { build() }

# risk: the header list.
KIND == "risk" && pass == 2 && inrisks {
	if ($0 ~ /^[ \t]+[-*] /) {
		if (E("CLOSE") != "" && !closed && index($0, E("CLOSE")) > 0) { $0 = $0 " **Closed " E("TODAY") ":** " E("HOW"); closed = 1 }
		print; next
	}
	if (E("ADD") != "") { print "  - " E("ADD") (E("BY") != "" ? " (" E("BY") ", " E("TODAY") ")" : " (" E("TODAY") ")"); added = 1 }
	inrisks = 0
}
KIND == "risk" && pass == 2 && sec == "Status" && /^- Outstanding Risks:/ {
	v = trim(substr($0, 21)); if (E("ADD") != "" && (tolower(v) == "none" || v == "")) $0 = "- Outstanding Risks:"
	print; inrisks = 1; next
}
# check: one line of the unit'"'"'s latest attempt, then its Outcome.
KIND == "check" && pass == 1 && sec == "Work Unit Validation" { }
KIND == "check" && pass == 2 && sec == "Work Unit Validation" && /^## / { u = substr($0, 4); sub(/[ \t]+—.*$/, "", u); cur = plain(u) }
KIND == "check" && pass == 2 && sec == "Work Unit Validation" && cur == WU && /^### Attempt [0-9]+/ { inatt = ($3 + 0 == natt[WU]) }
KIND == "check" && pass == 2 && inatt && cur == WU && match($0, "^[ \t]+- Check " E("N") " [(]") {
	p = index($0, "]: "); if (p == 0) p = index($0, "): ")
	if (p == 0) fail("check " E("N") " has no \"]: \" or \"): \" before its result")
	# Keep the earlier evidence (an Agent + Engineer check keeps the agent part).
	old = substr($0, p + 3); sub(/^[a-z]+\.?[ \t]*/, "", old); sub(/;? *engineer part pending$/, "", old)
	ev = old; if (E("EVIDENCE") != "") ev = (ev == "" ? E("EVIDENCE") : ev "; " E("EVIDENCE"))
	$0 = substr($0, 1, p + 2) E("RESULT") (ev != "" ? ". " ev : ".")
	setc = 1
}
KIND == "check" && pass == 2 && inatt && cur == WU && /^[ \t]+- Check [0-9]+ / {
	r = $0; p = index(r, "]: "); if (p == 0) p = index(r, "): "); r = substr(r, p + 3); split(r, w, /[ .;,]/)
	cn = $3; if (w[1] == "failed") nfail++; else if (w[1] == "pending" || w[1] == "blocked") pend = pend (pend == "" ? "" : ", ") cn
}
KIND == "check" && pass == 2 && inatt && cur == WU && /^- Outcome:/ {
	$0 = "- Outcome: " (nfail ? "Failed" : pend != "" ? "Pending (checks " pend ")" : "Done"); outc = substr($0, 12)
}
# Tables and blocks: append at the end of the target section.
pass == 2 && (KIND == "decision" || KIND == "change") && sec == TARGET && /^[ \t]*\|/ { print; lastrow = 1; next }
pass == 2 && (KIND == "decision" || KIND == "change") && lastrow && !done { print ROW; done = 1; lastrow = 0 }
pass == 2 && (KIND == "improvement" || KIND == "validation") && $0 == "" { bl++; next }
pass == 2 && (KIND == "improvement" || KIND == "validation") && /^# / {
	if (prevsec == TARGET && !done) { print ""; print BLOCK; print ""; done = 1; bl = 0 }
	blanks(); print; prevsec = sec; next
}
pass == 2 && (KIND == "improvement" || KIND == "validation") { blanks(); print; next }
pass == 2 { print }
END {
	if (failed) exit 2
	if ((KIND == "decision" || KIND == "change") && lastrow && !done) { print ROW; done = 1 }
	if ((KIND == "improvement" || KIND == "validation") && sec == TARGET && !done) { print ""; print BLOCK; done = 1 }
	if (KIND == "risk" && inrisks && E("ADD") != "") { print "  - " E("ADD") (E("BY") != "" ? " (" E("BY") ", " E("TODAY") ")" : " (" E("TODAY") ")"); added = 1 }
	if (KIND == "risk") { if (E("ADD") != "" && added) MSG = "risk added"; else if (closed) MSG = "risk closed"; else { print "status-record.sh: " (E("ADD") != "" ? "no \"- Outstanding Risks:\" line" : "no risk bullet contains: " E("CLOSE")) > "/dev/stderr"; exit 2 } }
	else if (KIND == "check") { if (!setc) { print "status-record.sh: no check " E("N") " in the latest attempt for " WU > "/dev/stderr"; exit 2 }; MSG = WU " check " E("N") ": " E("RESULT") "; outcome: " outc }
	else if (!done) { print "status-record.sh: no \"# " TARGET "\" table or section to add to" > "/dev/stderr"; exit 2 }
	print MSG > REPORT
}' - "$t1" "$t1" >"$t2" || exit 2

if [ "$crlf" = 1 ]; then sed 's/$/\r/' "$t2" >"$t1"; mv "$t1" "$doc"; else mv "$t2" "$doc"; fi
cat "$rep"
bash "$here/status-set.sh" "$doc" --refresh >/dev/null
