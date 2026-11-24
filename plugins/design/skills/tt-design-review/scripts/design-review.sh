#!/usr/bin/env bash
# design-review.sh: the only writer of a Design Review document, for
# tt-design-review (and any tool that shows one). A review is the list of areas
# a design document may be missing, each with the wording that would fill the
# gap. Every write reads the whole review, applies one change and renders it
# again in one layout. Confirming a suggestion is the only thing here that
# writes the design document itself.
# Needs bash, awk, sed, tr and cksum only.
set -u
export LC_ALL=C

usage() {
	cat >&2 <<'EOF'
usage: design-review.sh init <design doc> <review.md>
       design-review.sh add <review.md> <spec>
       design-review.sh decide <review.md> <DR-id> accept|reject|reopen [<reason>] [--if <hash>]
       design-review.sh wording <review.md> <DR-id> <text file> [--where <heading>|end] [--if <hash>]
       design-review.sh confirm <review.md> <DR-id> --doc <design doc> [--if <hash>] [--doc-if <doc hash>]
       design-review.sh list <review.md> --tsv [--doc <design doc>]
       design-review.sh show <review.md> <DR-id> --tsv
       design-review.sh hash <design doc>
       design-review.sh check <review.md>

init      Write a new review next to the design doc: the title, a link to the
          design doc and today's date, with no suggestions yet.
add       Add the suggestions in the spec (at most 8 per call) as Open and print
          their IDs, one per line (DR01, DR02 ... never reused).
decide    accept: Open -> Accepted. reject: Open or Accepted -> Rejected, with
          an optional reason. reopen: Accepted or Rejected -> Open. An Added
          suggestion can't change.
wording   Replace the suggested wording with the text file's content ("-" reads
          stdin), and optionally where it goes. Only while Open or Accepted. The
          suggestion is marked Edited when the text differs.
confirm   Add an Accepted suggestion's wording to the design doc, as whole
          blocks at the end of the section named by Where (or, for "end" or a
          heading that isn't there, as a new "## <Area>" section at the end),
          and record exactly what was added. Prints "under: <heading>" or
          "new section: <heading>". --doc-if refuses (exit 3) when the design
          doc's hash isn't the one given (see hash and list --doc).
list      Print the review as tab-separated records:
            meta    title|source|reviewed|doc  <value>
            dr      <id> <area> <status> <why> <where> <wording> <edited yes|no>
                    <added under> <added text> <reason> <hash>
          In every field \ is \\, a tab \t and a newline \n. <hash> changes
          whenever the suggestion does: pass it back with --if to refuse a
          change to a suggestion that moved since you read it. meta doc is the
          design doc's hash, printed with --doc.
show      One suggestion's record only.
hash      The design doc's hash (line endings ignored).
check     Exit 0 when the review is in the layout; otherwise print "problem: ..."
          lines. Every write refuses a review with problems.

A spec is a small text file, or - to read it from stdin (a quoted heredoc),
with a line of --- between suggestions:
  area: Rollout plan                (one line, no "|")
  where: Technical design           (a heading in the design doc, or end; default end)
  why: One line, or leave this empty and indent the lines below it two spaces
  wording:
    Text for the design doc, every line indented two spaces. Level 1 and 2
    headings aren't allowed; code fences must close.

Exit: 0 done, 1 refused input (a bad spec, an unknown suggestion, a change that
isn't allowed, a review with problems), 2 usage error or a missing file, 3 the
suggestion or the design doc changed since it was read (--if, --doc-if).
EOF
	exit 2
}

die() { echo "design-review.sh: $*" >&2; exit 2; }
refuse() { echo "design-review.sh: $*" >&2; exit 1; }
work=$(mktemp -d)
lock=""
cleanup() { [ -n "$lock" ] && rmdir "$lock" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

LIB='
BEGIN { for (i = 1; i < 256; i++) ORD[sprintf("%c", i)] = i }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function esc(s,   o, i, n, c) {
	if (s !~ /[\\\t\n]/) return s
	o = ""; n = length(s)
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "\\") o = o "\\\\"; else if (c == "\t") o = o "\\t"; else if (c == "\n") o = o "\\n"; else o = o c
	}
	return o
}
function unesc(s,   o, i, n, c) {
	if (index(s, "\\") == 0) return s
	o = ""; n = length(s)
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "\\" && i < n) { c = substr(s, ++i, 1); o = o (c == "t" ? "\t" : c == "n" ? "\n" : c) } else o = o c
	}
	return o
}
function hash(s,   h, i, n) {
	h = 5381; n = length(s)
	for (i = 1; i <= n; i++) h = (h * 33 + ORD[substr(s, i, 1)]) % 2147483647
	return sprintf("%d", h)
}
# a file read whole (lines joined with newlines, no final newline); texts reach awk through files, since -v would read their backslashes
function slurp(f,   s, l, first) {
	s = ""; first = 1
	while ((getline l < f) > 0) { s = s (first ? "" : "\n") l; first = 0 }
	close(f)
	return s
}
# the text of a heading line: no #s, no closing #s, trimmed, lower case
function headtext(l) { sub(/^#+[ \t]+/, "", l); sub(/[ \t]+#+[ \t]*$/, "", l); return tolower(trim(l)) }
'

# ---- the review document -> the model
# The model: one record per line, fields escaped (see list).
#   meta <key> <value> · dr <id> <area> <status> <why> <where> <wording>
#   <edited> <under> <text> <reason>
PARSE='
function problem(m) { printf "problem: %s\n", m >> PROB; close(PROB) }
function lp(m) { problem("line " NR ": " m) }
function addline(l) { buf = have ? buf "\n" l : l; have = 1 }
function endfield(   v) {
	if (cur == "") return
	v = buf
	sub(/^\n+/, "", v); sub(/\n+$/, "", v)
	if (cur in f) lp("the field " cur " twice in " id)
	f[cur] = v
	cur = ""; buf = ""; have = 0
}
function endrec(   s, e, k) {
	if (id == "") return
	endfield()
	for (k in f) if (!(k in OKL)) problem("an unknown field " k " in " id)
	for (k in REQ) if (!(k in f)) problem(id " has no " k)
	s = f["Status"]
	if (s != "" && s != "Open" && s != "Accepted" && s != "Rejected" && s != "Added") problem(id " has the status " s)
	if (s == "Added" && (f["Added text"] == "")) problem(id " is Added but records no text")
	e = f["Edited"] == "" ? "no" : f["Edited"]
	if (e != "yes" && e != "no") problem(id " has Edited " e)
	if (id in SEEN) problem("the ID " id " twice")
	SEEN[id] = 1
	printf "dr\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, esc(area), esc(s), esc(f["Why"]), esc(f["Where"]), esc(f["Wording"]), e, esc(f["Added under"]), esc(f["Added text"]), esc(f["Reason"])
	id = ""
	delete f
}
BEGIN {
	n = split("Status,Where,Why,Wording,Edited,Added under,Added text,Reason", A, ",")
	for (i = 1; i <= n; i++) OKL[A[i]] = 1
	REQ["Status"] = 1; REQ["Where"] = 1; REQ["Why"] = 1; REQ["Wording"] = 1
	sec = "head"
}
/^# / && sec == "head" && !title { title = substr($0, 3); printf "meta\ttitle\t%s\n", esc(title); next }
/^## DR[0-9]+: / {
	endrec()
	id = $0; sub(/^## /, "", id); area = id; sub(/:.*/, "", id); sub(/^[^:]*:[ \t]*/, "", area)
	sec = "rec"; cur = ""; buf = ""; have = 0
	delete f
	next
}
/^## / { endrec(); sec = "other"; next }
sec == "head" {
	if ($0 ~ /^- \*\*Source:\*\*/) { v = $0; sub(/^- \*\*Source:\*\*[ \t]*/, "", v); printf "meta\tsource\t%s\n", esc(v); next }
	if ($0 ~ /^- \*\*Reviewed:\*\*/) { v = $0; sub(/^- \*\*Reviewed:\*\*[ \t]*/, "", v); printf "meta\treviewed\t%s\n", esc(v); next }
	if ($0 ~ /^[ \t]*$/) next
	lp("text the layout does not have above the suggestions"); next
}
sec == "other" { next }
sec == "rec" {
	if ($0 ~ /^- \*\*[^*]+:\*\*/) {
		endfield()
		lab = $0; sub(/^- \*\*/, "", lab); sub(/:\*\*.*/, "", lab)
		rest = $0; sub(/^- \*\*[^*]+:\*\*[ \t]*/, "", rest)
		cur = lab; buf = ""; have = 0
		if (rest != "") addline(rest)
		next
	}
	if (cur == "") { if ($0 !~ /^[ \t]*$/) lp("text outside a field in " id); next }
	if ($0 ~ /^[ \t]*$/) { addline(""); next }
	if ($0 !~ /^  /) { lp("a line in " cur " that is not indented two spaces"); next }
	addline(substr($0, 3))
	next
}
END { endrec() }
'

# ---- the model -> the review document
RENDER='
function block(label, v,   n, a, i) {
	printf "- **%s:**\n", label
	n = split(v, a, "\n")
	for (i = 1; i <= n; i++) printf "%s\n", (a[i] == "" ? "" : "  " a[i])
}
function inl(label, v) { printf "- **%s:** %s\n", label, v }
BEGIN { FS = "\t" }
$1 == "meta" { M[$2] = unesc($3); next }
$1 == "dr" { N++; for (i = 1; i <= 11; i++) R[N, i] = unesc($i); next }
END {
	printf "# %s\n\n", M["title"]
	if (M["source"] != "") inl("Source", M["source"])
	if (M["reviewed"] != "") inl("Reviewed", M["reviewed"])
	printf "\n## At a glance\n\n| ID | Area | Status |\n|---|---|---|\n"
	if (N == 0) printf "| - | No suggestions yet | - |\n"
	for (k = 1; k <= N; k++) { a = R[k, 3]; gsub(/\|/, "\\|", a); printf "| %s | %s | %s |\n", R[k, 2], a, R[k, 4] }
	for (k = 1; k <= N; k++) {
		printf "\n## %s: %s\n\n", R[k, 2], R[k, 3]
		inl("Status", R[k, 4])
		inl("Where", R[k, 6])
		block("Why", R[k, 5])
		block("Wording", R[k, 7])
		inl("Edited", R[k, 8])
		if (R[k, 4] == "Added") { inl("Added under", R[k, 9]); block("Added text", R[k, 10]) }
		if (R[k, 11] != "") inl("Reason", R[k, 11])
	}
}
'

# ---- a spec -> new records
SPEC_AWK='
function fail(m) { printf "design-review.sh: spec: %s\n", m > "/dev/stderr"; bad = 1; exit 1 }
function addline(l) { buf = have ? buf "\n" l : l; have = 1 }
function endkey(   v) {
	if (key == "") return
	v = buf; sub(/^\n+/, "", v); sub(/\n+$/, "", v)
	val[key] = v; key = ""; buf = ""; have = 0
}
function flush(   n, a, i, fence, l) {
	endkey()
	if (!seen) return
	if (val["area"] == "") fail("a suggestion needs an area")
	if (val["area"] ~ /[|\t\n]/) fail("an area can not hold | or line breaks")
	if (val["why"] == "") fail("\"" val["area"] "\" needs a why")
	if (val["wording"] == "") fail("\"" val["area"] "\" needs wording")
	if (val["where"] == "") val["where"] = "end"
	if (val["where"] ~ /[\t\n]/) fail("where is one line")
	n = split(val["wording"], a, "\n"); fence = 0
	for (i = 1; i <= n; i++) {
		l = a[i]
		if (l ~ /^```/) fence = !fence
		else if (!fence && l ~ /^##?[ \t]/) fail("\"" val["area"] "\": wording can not hold a level 1 or 2 heading (line " i ")")
	}
	if (fence) fail("\"" val["area"] "\": a code fence in the wording is not closed")
	count++
	if (count > 8) fail("at most 8 suggestions in one add")
	printf "new\t%s\t%s\t%s\t%s\n", esc(val["area"]), esc(val["where"]), esc(val["why"]), esc(val["wording"])
	delete val; seen = 0
}
BEGIN { FS = "\n" }
$0 == "---" { flush(); next }
/^(area|where|why|wording):/ {
	endkey(); seen = 1
	key = $0; sub(/:.*/, "", key)
	rest = $0; sub(/^[a-z]+:[ \t]*/, "", rest)
	if (key in val) fail("the key " key " twice in one suggestion")
	buf = ""; have = 0
	if (rest != "") addline(rest)
	next
}
{
	if (key == "") { if ($0 ~ /^[ \t]*$/) next; fail("line " NR ": text that is not under a key") }
	if ($0 ~ /^[ \t]*$/) { addline(""); next }
	if ($0 !~ /^  /) fail("line " NR ": a line under " key " that is not indented two spaces")
	addline(substr($0, 3))
}
END { if (!bad) flush(); if (!bad && count == 0) fail("the spec has no suggestions") }
'

# ---- changes to the model
CHANGE='
BEGIN { FS = "\t"; OFS = "\t" }
function recline(k) { return "dr\t" K[k, 2] "\t" K[k, 3] "\t" K[k, 4] "\t" K[k, 5] "\t" K[k, 6] "\t" K[k, 7] "\t" K[k, 8] "\t" K[k, 9] "\t" K[k, 10] "\t" K[k, 11] }
function refuse(m, rc) { printf "design-review.sh: %s\n", m > "/dev/stderr"; exit rc }
$1 == "meta" { M++; ML[M] = $0; next }
$1 == "dr" {
	N++; for (i = 1; i <= 11; i++) K[N, i] = $i
	n = substr($2, 3) + 0; if (n > MAXN) MAXN = n
	if ($2 == ID) F = N
	next
}
$1 == "new" { NW++; for (i = 2; i <= 5; i++) W[NW, i] = $i; next }
END {
	if (OP != "add" && F == 0) refuse("no such suggestion: " ID, 1)
	if (F > 0 && IF != "" && hash(recline(F)) != IF) refuse(ID " changed since it was read", 3)
	st = (F > 0) ? unesc(K[F, 4]) : ""
	if (OP == "add") {
		for (j = 1; j <= NW; j++) {
			MAXN++; N++
			K[N, 1] = "dr"; K[N, 2] = sprintf("DR%02d", MAXN); K[N, 3] = W[j, 2]; K[N, 4] = "Open"; K[N, 5] = W[j, 4]; K[N, 6] = W[j, 3]; K[N, 7] = W[j, 5]
			K[N, 8] = "no"; K[N, 9] = ""; K[N, 10] = ""; K[N, 11] = ""
			print K[N, 2] > IDS
		}
	} else if (OP == "decide") {
		if (ACT == "accept") { if (st != "Open") refuse(ID " is " st ", only an Open one can be accepted", 1); K[F, 4] = "Accepted" }
		else if (ACT == "reject") { if (st != "Open" && st != "Accepted") refuse(ID " is " st ", it can not be rejected", 1); K[F, 4] = "Rejected"; K[F, 11] = esc(slurp(REASON_F)) }
		else if (ACT == "reopen") { if (st != "Accepted" && st != "Rejected") refuse(ID " is " st ", it can not be reopened", 1); K[F, 4] = "Open"; K[F, 11] = "" }
		else refuse("decide takes accept, reject or reopen", 1)
	} else if (OP == "wording") {
		if (st != "Open" && st != "Accepted") refuse(ID " is " st ", its wording can not change", 1)
		t = esc(slurp(TEXT_F))
		if (t != K[F, 7]) { K[F, 7] = t; K[F, 8] = "yes" }
		w = slurp(WHERE_F)
		if (w != "") K[F, 6] = esc(w)
	} else if (OP == "added") {
		if (st != "Accepted") refuse(ID " is " st ", only an Accepted one can be confirmed", 1)
		K[F, 4] = "Added"; K[F, 9] = esc(slurp(UNDER_F)); K[F, 10] = esc(slurp(ADDED_F))
	}
	for (m = 1; m <= M; m++) print ML[m]
	for (k = 1; k <= N; k++) print recline(k)
}
'

# ---- insert the wording into the design doc
INSERT='
function fenceline(l) { return l ~ /^```/ || l ~ /^~~~/ }
function levelof(l,   h) { h = l; sub(/[^#].*/, "", h); return length(h) }
BEGIN {
	FS = "\n"
	want = slurp(WHERE_F); sub(/^#+[ \t]+/, "", want); want = tolower(trim(want))
	wording = slurp(WORDING_F); area = slurp(AREA_F)
}
{ L[NR] = $0 }
END {
	n = NR; tgt = 0; fence = 0
	if (want != "" && want != "end") {
		for (i = 1; i <= n; i++) {
			if (fenceline(L[i])) { fence = !fence; continue }
			if (!fence && L[i] ~ /^#+[ \t]+/ && headtext(L[i]) == want) { tgt = i; break }
		}
	}
	if (tgt > 0) {
		lv = levelof(L[tgt]); stop = n + 1; fence = 0
		for (i = tgt + 1; i <= n; i++) {
			if (fenceline(L[i])) { fence = !fence; continue }
			if (!fence && L[i] ~ /^#+[ \t]+/ && levelof(L[i]) <= lv) { stop = i; break }
		}
		last = stop - 1
		while (last > tgt && L[last] ~ /^[ \t]*$/) last--
		for (i = 1; i <= last; i++) print L[i]
		print ""
		printf "%s\n", wording
		if (stop <= n && stop - 1 == last) print ""
		for (i = last + 1; i <= n; i++) print L[i]
		printf "under\t%s\n", L[tgt] > RESULT
	} else {
		last = n
		while (last > 0 && L[last] ~ /^[ \t]*$/) last--
		for (i = 1; i <= last; i++) print L[i]
		if (last > 0) print ""
		printf "## %s\n\n%s\n", area, wording
		printf "new\t## %s\n", area > RESULT
	}
}
'

take_lock() {
	local l
	l="$(dirname "$review")/.$(basename "$review").lock"
	for _ in $(seq 1 100); do
		mkdir "$l" 2>/dev/null && { lock=$l; return 0; }
		[ -n "$(find "$l" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$l" 2>/dev/null && continue
		sleep 0.1
	done
	die "the review is locked by another writer: $l"
}

# parse <file>: the model in $work/model, problems in $work/problems
parse() {
	: >"$work/problems"
	tr -d '\r' <"$1" >"$work/in"
	awk -v PROB="$work/problems" "$LIB$PARSE" "$work/in" >"$work/model"
}
fail_problems() {
	if [ -s "$work/problems" ]; then
		cat "$work/problems" >&2
		exit 1
	fi
}

# crlf <file>: succeeds when the file uses CRLF line ends
crlf() { [ -f "$1" ] && [ "$(head -c 4096 "$1" | tr -dc '\r' | wc -c)" -gt 0 ]; }

# write <text> <dest> [crlf]: replace dest atomically, with CRLF line ends when asked
write_out() {
	local src=$1 dest=$2 tmp
	tmp="$(dirname "$dest")/.$(basename "$dest").$$"
	if [ "${3:-}" = crlf ]; then
		awk -v BINMODE=3 '{ printf "%s\r\n", $0 }' "$src" >"$tmp" || { rm -f "$tmp"; die "can't write $dest"; }
	else
		cp "$src" "$tmp" || { rm -f "$tmp"; die "can't write $dest"; }
	fi
	mv -f "$tmp" "$dest" || { rm -f "$tmp"; die "can't write $dest"; }
}

# render <model> <out>: the review, CRLF when the file it replaces had it
render() {
	awk "$LIB$RENDER" "$1" >"$work/out"
	if crlf "$2"; then write_out "$work/out" "$2" crlf; else write_out "$work/out" "$2"; fi
}

# change <op> [awk vars...]: parse, apply, render (the lock is held by the caller)
change() {
	local op=$1; shift
	parse "$review"; fail_problems
	awk -v OP="$op" -v IDS="$work/ids" "$@" "$LIB$CHANGE" "$work/model" >"$work/model2"
	local rc=$?
	[ "$rc" = 0 ] || exit "$rc"
	render "$work/model2" "$review"
}

need_review() { [ -f "$review" ] || die "no such file: $review"; }
need_id() { case "$id" in DR[0-9][0-9]*) ;; *) refuse "not a suggestion ID: $id" ;; esac; }
# read a text argument: a file, or - for stdin; CRs dropped
text_arg() {
	local f=$1 to=$2
	if [ "$f" = - ] || [ "$f" = /dev/stdin ]; then cat >"$to.raw"; else [ -f "$f" ] || die "no such file: $f"; cat "$f" >"$to.raw"; fi
	tr -d '\r' <"$to.raw" >"$to"
}
dochash() { tr -d '\r' <"$1" | cksum | awk '{ print $1 }'; }

[ $# -ge 1 ] || usage
cmd=$1; shift
case "$cmd" in
	-h | --help) usage ;;
	init)
		[ $# -eq 2 ] || usage
		src=$1; review=$2
		[ -f "$src" ] || die "no such file: $src"
		[ -e "$review" ] && die "$review exists; delete it first to start again"
		[ -d "$(dirname "$review")" ] || die "no such folder: $(dirname "$review")"
		if [ "$(cd "$(dirname "$src")" && pwd -P)" = "$(cd "$(dirname "$review")" && pwd -P)" ]; then
			link="[[$(basename "$src" .md)]]"
		else
			link="\`$src\`"
		fi
		title="$(basename "$src" .md) - Design Review"
		printf 'meta\ttitle\t%s\nmeta\tsource\t%s\nmeta\treviewed\t%s\n' "$title" "$link" "$(date +%F)" >"$work/model"
		render "$work/model" "$review"
		echo "$review"
		;;
	add)
		[ $# -eq 2 ] || usage
		review=$1; sp=$2
		need_review
		text_arg "$sp" "$work/spec.in"
		awk "$LIB$SPEC_AWK" "$work/spec.in" >"$work/spec" || exit 1
		take_lock
		parse "$review"; fail_problems
		cat "$work/spec" >>"$work/model"
		awk -v OP=add -v IDS="$work/ids" "$LIB$CHANGE" "$work/model" >"$work/model2" || exit $?
		render "$work/model2" "$review"
		cat "$work/ids"
		;;
	decide)
		[ $# -ge 3 ] || usage
		review=$1; id=$2; act=$3; shift 3; reason=""; ifh=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--if) ifh=${2:?}; shift 2 ;;
				*) reason=$1; shift ;;
			esac
		done
		need_review; need_id
		case "$reason" in *$'\n'* | *$'\t'*) refuse "a reason can't hold a newline or tab" ;; esac
		printf '%s\n' "$reason" >"$work/reason"
		take_lock
		change decide -v ID="$id" -v ACT="$act" -v REASON_F="$work/reason" -v IF="$ifh"
		;;
	wording)
		[ $# -ge 3 ] || usage
		review=$1; id=$2; tf=$3; shift 3; where=""; ifh=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--where) where=${2:?}; shift 2 ;;
				--if) ifh=${2:?}; shift 2 ;;
				*) usage ;;
			esac
		done
		need_review; need_id
		text_arg "$tf" "$work/wording"
		# trim blank lines around the text
		awk '{ l[NR] = $0 } END { s = 1; n = NR; while (s <= n && l[s] ~ /^[ \t]*$/) s++; while (n >= s && l[n] ~ /^[ \t]*$/) n--; for (i = s; i <= n; i++) print l[i] }' "$work/wording" >"$work/wording.t"
		[ -s "$work/wording.t" ] || refuse "the wording is empty"
		awk '/^```/ { f = !f; next } !f && /^##?[ \t]/ { bad = 1 } END { exit bad ? 0 : 1 }' "$work/wording.t" && refuse "wording can not hold a level 1 or 2 heading"
		[ $(( $(grep -c '^```' "$work/wording.t") % 2 )) -eq 0 ] || refuse "a code fence in the wording is not closed"
		case "$where" in *$'\n'* | *$'\t'*) refuse "where is one line" ;; esac
		printf '%s\n' "$where" >"$work/where"
		take_lock
		change wording -v ID="$id" -v IF="$ifh" -v TEXT_F="$work/wording.t" -v WHERE_F="$work/where"
		;;
	confirm)
		[ $# -ge 2 ] || usage
		review=$1; id=$2; shift 2; doc=""; ifh=""; docif=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--doc) doc=${2:?}; shift 2 ;;
				--if) ifh=${2:?}; shift 2 ;;
				--doc-if) docif=${2:?}; shift 2 ;;
				*) usage ;;
			esac
		done
		[ -n "$doc" ] || usage
		need_review; need_id
		[ -f "$doc" ] || die "no such file: $doc"
		take_lock
		parse "$review"; fail_problems
		# the suggestion, unescaped into files; nothing is written to the doc for one that can't be added
		mkdir "$work/rec"
		awk "$LIB"'BEGIN { FS = "\t" }
			$1 == "dr" && $2 == ID {
				found = 1
				if (IF != "" && hash($0) != IF) exit 3
				print $4 > (D "/status"); print unesc($3) > (D "/area"); print unesc($6) > (D "/where"); print unesc($7) > (D "/wording")
			}
			END { if (!found) exit 1 }' ID="$id" IF="$ifh" D="$work/rec" "$work/model"
		case $? in
			0) ;;
			3) echo "design-review.sh: $id changed since it was read" >&2; exit 3 ;;
			*) refuse "no such suggestion: $id" ;;
		esac
		status_e=$(cat "$work/rec/status")
		[ "$status_e" = Accepted ] || refuse "$id is $status_e, only an Accepted one can be confirmed"
		if [ -n "$docif" ] && [ "$(dochash "$doc")" != "$docif" ]; then echo "design-review.sh: the design doc changed since it was read" >&2; exit 3; fi
		tr -d '\r' <"$doc" >"$work/doc.in"
		awk -v WHERE_F="$work/rec/where" -v AREA_F="$work/rec/area" -v WORDING_F="$work/rec/wording" -v RESULT="$work/result" "$LIB$INSERT" "$work/doc.in" >"$work/doc.out" || die "couldn't work out where to add it"
		IFS=$'\t' read -r kind under <"$work/result"
		if [ "$kind" = new ]; then
			{ printf '%s\n\n' "$under"; cat "$work/rec/wording"; } >"$work/added"
			printf '(new section) %s\n' "${under#\#\# }" >"$work/under"
			said="new section: ${under#\#\# }"
		else
			cp "$work/rec/wording" "$work/added"
			printf '%s\n' "$under" | sed 's/^#*[ \t]*//' >"$work/under"
			said="under: $(cat "$work/under")"
		fi
		# the doc first (it is what the person reads), then the record of it
		if crlf "$doc"; then write_out "$work/doc.out" "$doc" crlf; else write_out "$work/doc.out" "$doc"; fi
		change added -v ID="$id" -v UNDER_F="$work/under" -v ADDED_F="$work/added"
		echo "$said"
		;;
	list | show)
		[ $# -ge 2 ] || usage
		review=$1; shift
		id=""
		if [ "$cmd" = show ]; then id=$1; shift; fi
		tsv=0; doc=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--tsv) tsv=1; shift ;;
				--doc) doc=${2:?}; shift 2 ;;
				*) usage ;;
			esac
		done
		[ "$tsv" = 1 ] || usage
		need_review
		parse "$review"; fail_problems
		if [ -n "$doc" ]; then
			[ -f "$doc" ] || die "no such file: $doc"
			printf 'meta\tdoc\t%s\n' "$(dochash "$doc")"
		fi
		awk "$LIB"'BEGIN { FS = "\t"; OFS = "\t" }
			$1 == "meta" { if (ID == "") print; next }
			$1 == "dr" { if (ID != "" && $2 != ID) next; found = 1; print $0, hash($0) }
			END { if (ID != "" && !found) { printf "design-review.sh: no such suggestion: %s\n", ID > "/dev/stderr"; exit 1 } }' ID="$id" "$work/model"
		;;
	hash)
		[ $# -eq 1 ] || usage
		[ -f "$1" ] || die "no such file: $1"
		dochash "$1"
		;;
	check)
		[ $# -eq 1 ] || usage
		review=$1; need_review
		parse "$review"
		if [ -s "$work/problems" ]; then cat "$work/problems"; exit 1; fi
		;;
	*) usage ;;
esac
