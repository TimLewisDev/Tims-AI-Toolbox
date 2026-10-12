#!/usr/bin/env bash
# lite-index.sh: write a Lite Brief's "## Work Units" and "## Task Map" tables
# from its unit blocks and task cards, so no model types them.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: lite-index.sh [--check] <lite brief.md>

Reads the brief's "## WU<n> — <outcome>" blocks (their Depends on and Validated
by rows) and "### T<nn> — <title>" cards (their Executor and Depends on rows;
the unit is the one the card sits under) and writes, in place, the two tables
every tt-execute script reads:

  ## Work Units   ID | After this unit you can… | Tasks | Validated by | Depends on
  ## Task Map     ID | Task | Executor | Depends on | Work unit

Any old copy of either section is replaced; both go just before the first unit
block. Headings inside fenced code blocks are ignored. The file's line endings
are kept.

--check  change nothing; exit 1 if the tables are missing or out of date.
Exit: 0 written (or up to date), 1 --check found them out of date, 2 usage
error or a brief with no unit block or a card outside a unit.
EOF
	exit 2
}

die() { echo "lite-index.sh: $*" >&2; exit 2; }

check=0
[ "${1:-}" = --check ] && { check=1; shift; }
[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac
doc=$1
[ -f "$doc" ] || die "no such file: $doc"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$doc" >"$work/in"
crlf=0; [ "$(head -c 4096 "$doc" | tr -dc '\r' | wc -c)" -gt 0 ] && crlf=1

# The two tables.
awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cell(l,   a) { split(l, a, "|"); return trim(a[3]) }
/^```/ { fence = !fence; next }
fence { next }
/^## / {
	unit = ""; card = ""
	p = index($0, " — "); head = (p ? substr($0, 1, p - 1) : $0)
	if (p && head ~ /^## WU[0-9]+[a-z]*$/) { unit = substr(head, 4); nu++; U[nu] = unit; rest = substr($0, p); sub(/^ — /, "", rest); UN[unit] = trim(rest) }
	next
}
/^### / {
	card = ""
	p = index($0, " — "); head = (p ? substr($0, 1, p - 1) : $0)
	if (p && head ~ /^### T[0-9]+[a-z]*$/) {
		if (unit == "") { print "card " substr(head, 5) " is not inside a unit block" > "/dev/stderr"; bad = 1; next }
		card = substr(head, 5); nt++; T[nt] = card; rest = substr($0, p); sub(/^ — /, "", rest); TT[card] = trim(rest); TW[card] = unit
		UT[unit] = UT[unit] (UT[unit] == "" ? "" : ", ") card
	}
	next
}
/^\| \*\*Executor\*\* \|/ && card != "" { TE[card] = cell($0); next }
/^\| \*\*Depends on\*\* \|/ { if (card != "") TD[card] = cell($0); else if (unit != "") UD[unit] = cell($0); next }
/^\| \*\*Validated by\*\* \|/ && unit != "" && card == "" { UV[unit] = cell($0); next }
END {
	if (bad) exit 2
	if (nu == 0) { print "no \"## WU<n> — \" unit block" > "/dev/stderr"; exit 2 }
	print "## Work Units"
	print "| ID | After this unit you can… | Tasks | Validated by | Depends on |"
	print "|---|---|---|---|---|"
	for (i = 1; i <= nu; i++) { u = U[i]; printf "| %s | %s | %s | %s | %s |\n", u, UN[u], UT[u], (UV[u] == "" ? "—" : UV[u]), (UD[u] == "" ? "—" : UD[u]) }
	print ""
	print "## Task Map"
	print "| ID | Task | Executor | Depends on | Work unit |"
	print "|---|---|---|---|---|"
	for (i = 1; i <= nt; i++) { t = T[i]; printf "| %s | %s | %s | %s | %s |\n", t, TT[t], (TE[t] == "" ? "?" : TE[t]), (TD[t] == "" ? "—" : TD[t]), TW[t] }
}' "$work/in" >"$work/tables" || die "can't read the unit blocks and cards (see above)"

# The document with both sections replaced.
awk -v TABLES="$work/tables" '
function flush(   l) { while ((getline l < TABLES) > 0) print l; print ""; done = 1 }
/^```/ { fence = !fence }
!fence && /^## / {
	skip = ($0 == "## Work Units" || $0 == "## Task Map")
	if (!skip && !done && index($0, "## WU") == 1 && index($0, " — ")) flush()
}
!skip { print }' "$work/in" >"$work/out"

if [ "$check" = 1 ]; then
	cmp -s "$work/in" "$work/out" || { echo "lite-index.sh: the tables in $doc are missing or out of date"; exit 1; }
	echo "tables up to date"
	exit 0
fi
if cmp -s "$work/in" "$work/out"; then echo "tables up to date"; exit 0; fi
t=$(mktemp "$(dirname "$doc")/.lite-index.XXXXXX")
if [ "$crlf" = 1 ]; then sed 's/$/\r/' "$work/out" >"$t"; else cp "$work/out" "$t"; fi
mv "$t" "$doc"
echo "wrote the Work Units and Task Map tables in $doc: $(grep -c '^| WU' "$work/tables") unit(s), $(grep -c '^| T[0-9]' "$work/tables") task(s)"
