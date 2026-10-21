#!/usr/bin/env bash
# lite-check.sh: check a Lite Brief's structure, so tt-execute-lite (and the
# tt-execute scripts it runs on the brief) can read it. Reads only; needs bash
# and awk.
set -u

usage() {
	cat >&2 <<'EOF'
usage: lite-check.sh <lite brief.md>

Checks, without a model:
  header     Revision, **Repo:** `<path>` · base `<branch>` · working branch …,
             and **Build check:** are above the first "## " heading
  sections   Goal, Acceptance, How it works today, The change, Not in scope,
             Open items, Work Units, Task Map, and at least one "## WU<n> — "
             unit block
  tables     Work Units and Task Map match the unit blocks and cards
             (lite-index.sh --check)
  acceptance each "**A<n>**" item is cited, as "(A<n>)", by a Validation item
  units      Validation list present; every item ends "(Agent)", "(Engineer)"
             or "(Agent + Engineer)"; checks-block lines are
             "<n> | ok|empty|nonempty | <command>" with n a Validation item
             that an agent runs
  cards      IDs unique and ascending; Executor is Agent or Engineer; Depends
             on names earlier tasks; an Agent card has Files (new/change lines)
             and Steps; an Engineer card has Steps
  leftovers  no "<!-- fill", "<!-- tt:end -->" or TODO markers
  code       no planning IDs inside code fences (check-planning-ids.sh --md)

Prints one "<line>: <problem>" per finding, then a count.
Exit: 0 clean, 1 findings, 2 usage error.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac
doc=$1
[ -f "$doc" ] || { echo "lite-check.sh: no such file: $doc" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$doc" >"$work/in"

awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cell(l,   a) { split(l, a, "|"); return trim(a[3]) }
function add(msg) { printf "%d: %s\n", NR, msg; n++ }
function finish_card(   i) {
	if (card == "") return
	if (ex[card] != "Agent" && ex[card] != "Engineer") add("card " card ": Executor must be Agent or Engineer (got \"" ex[card] "\")")
	if (!hasSteps) add("card " card ": no numbered Steps")
	if (ex[card] == "Agent" && nfiles == 0) add("card " card ": an Agent card needs Files (\"- new `path`: …\" or \"- change `path`: …\")")
	if (ex[card] == "Agent" && !hasFilesHead) add("card " card ": no **Files** heading")
}
/^```/ {
	if (fence) { fence = 0; if (inchecks) inchecks = 0 }
	else { fence = 1; if ($0 ~ /^```checks[ \t]*$/) { inchecks = 1; checksunit = unit } }
	next
}
fence {
	if (inchecks && trim($0) != "") {
		split($0, parts, "|"); k = trim(parts[1]); e = trim(parts[2]); c = trim(substr($0, index($0, "|") + 1)); c = trim(substr(c, index(c, "|") + 1))
		if (k !~ /^[0-9]+$/ || (e != "ok" && e != "empty" && e != "nonempty") || c == "") add("checks line must be \"<n> | ok|empty|nonempty | <command>\": " $0)
		else { nchk[unit]++; CK[unit "," k] = 1 }
	}
	next
}
/<!-- fill|<!-- tt:end|TODO/ { add("leftover marker: " trim($0)) }
NR == 1 && /^---[ \t]*$/ { fm = 1; next }
fm { if (/^---[ \t]*$/) fm = 0; next }
NR == 1 && /^# Tags/ { tags = 1; next }
tags { if (/^---[ \t]*$/) tags = 0; next }
!titled && NF { titled = 1; if ($0 !~ /^# .*: Lite Brief[ \t]*$/) add("the title must read \"# <Feature>: Lite Brief\" (after any front matter or tag block)") }
/^## / {
	finish_card(); card = ""; hasSteps = 0; nfiles = 0; hasFilesHead = 0; invalid = 0
	seenfirst = 1; sec = substr($0, 4); p = index(sec, " — "); sech = (p ? substr(sec, 1, p - 1) : sec)
	sections[sech] = 1; unit = ""
	if (p && sech ~ /^WU[0-9]+[a-z]*$/) {
		unit = sech; nunit++
		if (unit in seenunit) add("unit " unit " appears twice"); seenunit[unit] = 1
	}
	next
}
NR > 1 && !seenfirst && !/^## / { if ($0 ~ /\*\*Revision:\*\*/) { rev = 1; if ($0 !~ /\*\*Revision:\*\*[ \t]*[0-9]+/) add("Revision must be a number") }
	if ($0 ~ /\*\*Repo:\*\*/) { repo = 1; if ($0 !~ /\*\*Repo:\*\*[^`]*`[^`]+`.*base `[^`]+`.*working branch/) add("Repo line must read: **Repo:** `<path>` · base `<branch>` · working branch `<branch>`") }
	if ($0 ~ /\*\*Build check:\*\*/) { build = 1; if ($0 ~ /\*\*Build check:\*\*[ \t]*$/) add("Build check is empty") } }
/^### / {
	finish_card(); card = ""; hasSteps = 0; nfiles = 0; hasFilesHead = 0; invalid = 0
	p = index($0, " — "); head = (p ? substr($0, 1, p - 1) : $0)
	if (!(p && head ~ /^### T[0-9]+[a-z]*$/)) { add("card heading must be \"### T<nn> — <title>\": " $0); next }
	card = substr(head, 5)
	if (unit == "") { add("card " card " is not inside a unit block"); card = ""; next }
	if (card in seen) add("card " card " appears twice"); seen[card] = 1
	key = card; sub(/^T0*/, "", key); num = key + 0
	if (num < lastnum || (num == lastnum && card <= lastcard)) add("card " card " is out of order (after " lastcard ")")
	lastnum = num; lastcard = card; order[++ncard] = card; cardline[card] = NR; cardunit[card] = unit
	next
}
/^\| \*\*Executor\*\* \|/ && card != "" { ex[card] = cell($0); next }
/^\| \*\*Depends on\*\* \|/ && card != "" { dep[card] = cell($0); next }
card != "" && /^\*\*Files\*\*/ { hasFilesHead = 1; infiles = 1; next }
card != "" && /^\*\*/ { infiles = 0 }
card != "" && infiles && /^- (new|change|delete) `/ { nfiles++ }
card != "" && /^[0-9]+\. / { hasSteps = 1 }
sech == "Acceptance" && match($0, /\*\*A[0-9]+\*\*/) { id = substr($0, RSTART + 2, RLENGTH - 4); acc[id] = NR; nacc++ }
unit != "" && card == "" && /^\*\*Validation\*\*/ { inval = 1; next }
unit != "" && card == "" && /^\*\*/ { inval = 0 }
unit != "" && card == "" && inval && /^- \[[ xX]\] / {
	nv[unit]++; line = $0
	if (match(line, /\((Agent|Engineer|Agent \+ Engineer)\)[ \t]*$/)) { who = substr(line, RSTART + 1, RLENGTH - 2); sub(/\)[ \t]*$/, "", who); VW[unit "," nv[unit]] = who }
	else add("Validation item must end with (Agent), (Engineer) or (Agent + Engineer): " line)
	t = line
	while (match(t, /\(A[0-9]+\)/)) { cited[substr(t, RSTART + 1, RLENGTH - 2)] = 1; t = substr(t, RSTART + RLENGTH) }
}
END {
	finish_card()
	if (!rev) add("no **Revision:** line in the header")
	if (!repo) add("no **Repo:** line in the header")
	if (!build) add("no **Build check:** line in the header")
	m = split("Goal|Acceptance|How it works today|The change|Not in scope|Open items|Work Units|Task Map", req, "|")
	for (i = 1; i <= m; i++) if (!(req[i] in sections)) add("no \"## " req[i] "\" section")
	if (nunit == 0) add("no \"## WU<n> — <outcome>\" unit block")
	if (nacc == 0) add("the Acceptance section has no **A<n>** items")
	for (a in acc) if (!(a in cited)) add("acceptance " a " is not cited by any Validation item as (" a ")")
	for (i = 1; i <= ncard; i++) { c = order[i]; d = dep[c]
		if (d == "" || d == "—" || d == "-") continue
		k = split(d, ds, /[ ,]+/)
		for (j = 1; j <= k; j++) { if (ds[j] == "") continue
			if (!(ds[j] in seen)) { printf "%d: card %s depends on %s, which is not a card\n", cardline[c], c, ds[j]; n++ }
			else if (ds[j] >= c) { printf "%d: card %s depends on %s, which is not earlier\n", cardline[c], c, ds[j]; n++ } } }
	for (u in seenunit) {
		if (nv[u] == 0) add("unit " u " has no Validation items")
	}
	for (key in CK) { split(key, kk, ","); u = kk[1]; k = kk[2] + 0
		if (k < 1 || k > nv[u]) add("unit " u ": checks line " k " names no Validation item (" nv[u] " item(s))")
		else if (VW[u "," k] == "Engineer") add("unit " u ": checks line " k " is for an item only the engineer checks") }
	exit (n > 0)
}' "$work/in" >"$work/findings" 2>"$work/deps"
cat "$work/deps" >>"$work/findings"

bash "$here/lite-index.sh" --check "$doc" >"$work/idx" 2>&1 || {
	rc=$?; if [ "$rc" = 2 ]; then printf '0: %s\n' "$(head -n 1 "$work/idx")" >>"$work/findings"
	else printf '0: the Work Units / Task Map tables are missing or out of date: run lite-index.sh\n' >>"$work/findings"; fi; }

bash "$here/check-planning-ids.sh" --md "$doc" >"$work/ids" 2>&1
if [ $? -eq 1 ]; then
	awk -F'\t' 'NF >= 3 && $1 ~ /:[0-9]+$/ { n = $1; sub(/^.*:/, "", n); printf "%s: planning ID in a code block: %s (%s)\n", n, $3, $2 }' "$work/ids" >>"$work/findings"
fi

if [ -s "$work/findings" ]; then
	sort -n -t: -k1,1 "$work/findings" | awk '{ print } END { printf "%d finding(s)\n", NR }'
	exit 1
fi
echo "lite brief ok"
