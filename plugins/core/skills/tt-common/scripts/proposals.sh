#!/usr/bin/env bash
# proposals.sh: the only writer of a "<Prefix> - Tech Proposals.md" document once it
# exists. Appends proposals written as part files, records the engineer's decision on
# one (its Status, the (Chosen) marks, its Decision section and its At a glance row),
# marks a decision applied to the plan, and supersedes. Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: proposals.sh add <doc> <part.md> [<part.md> ...]
       proposals.sh decide <doc> P<n> <option> [--note <why>] [--by <name>]
       proposals.sh applied <doc> P<n>
       proposals.sh supersede <doc> P<n> P<m>
       proposals.sh ask <doc> P<n>
       proposals.sh list [--tsv] <doc>
       proposals.sh show <doc> P<n>
       proposals.sh status <doc>
       proposals.sh check <doc>

add        Appends complete parts (ending with <!-- tt:end -->), each holding one or
           more "## P<n> — <question>" proposals in the template's layout, and adds
           their At a glance rows. Refuses a P number already in the document.
decide     Records the engineer's choice:
             <A-D>   an option of the proposal: Status "Decided <date>", the option
                     marked (Chosen), the Decision section written (Chosen, By /
                     when, Why from --note, Not chosen), and "Applied: not yet"
                     until the plan follows it (then: applied)
             other   none of them (needs --note: what they want instead): the
                     Decision says so and the planner settles it with them
             leave   a Default applied proposal stays as it is (for now)
           An Open or Default applied proposal can be decided; a decision can be
           changed until it is applied. A decided one is otherwise superseded.
applied    Removes the "Applied: not yet" line once the plan records the decision.
supersede  P<n> becomes "Superseded by P<m> (<date>)"; P<m> must exist.
ask        Marks a Default applied proposal as put to the engineer, so it is
           waiting for a decision (an Open one always is).
list       id, status and question per proposal; --tsv prints
           id type status state recommended chosen question, where state is
           open (waiting for a decision), apply (decided, the plan not yet
           following) or done.
show       One proposal as "<field><TAB><value>" lines (id question type status
           decides context recommendation chosen state), then its options:
           option<TAB>key<TAB>title<TAB>detail<TAB>recommended 0|1<TAB>needs-note 0|1
status     total=, open=, apply=, done=
check      The layout: a known status and type, two to four options with at most
           one recommended, a Chosen line once decided, a unique P and a matching
           At a glance row. Prints the problems.

Line endings and a BOM are kept. Writes take a lock and replace the file whole.
Exit: 0 ok, 1 refused or problems found, 2 usage error or missing file.
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
. "$here/decide-lib.sh"
MARK='<!-- tt:end -->'
me=proposals.sh
die() { echo "$me: $*" >&2; exit "${2:-1}"; }

# model <file>: one P line per proposal, then one O line per option:
#   P id question type status statusfull decides context recommendation chosen applied asked
#   O id key title recommended oneline benefit risk chosen
model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function clean(s) { gsub(/\t/, " ", s); return trim(s) }
	# split a table row into c[1..n], keeping a "|" inside [[...|...]] links
	function cells(line,   s, i, n, out, inl) {
		s = line; out = ""; inl = 0
		for (i = 1; i <= length(s); i++) {
			ch = substr(s, i, 1)
			if (substr(s, i, 2) == "[[") inl = 1
			if (substr(s, i, 2) == "]]") inl = 0
			out = out ((ch == "|" && inl) ? "\001" : ch)
		}
		sub(/^[ \t]*\|/, "", out); sub(/\|[ \t]*$/, "", out)
		n = split(out, c, "|")
		for (i = 1; i <= n; i++) { gsub(/\001/, "|", c[i]); c[i] = trim(c[i]) }
		return n
	}
	function word(s) {
		if (s ~ /^Default applied/) return "Default applied"
		if (s ~ /^Open/) return "Open"; if (s ~ /^Decided/) return "Decided"; if (s ~ /^Superseded/) return "Superseded"
		return s
	}
	function endsec(   i) {
		if (id == "") return
		print "P", id, clean(q), clean(type), word(clean(st)), clean(st), clean(dec), clean(ctx), clean(rec), clean(chosen), applied + 0, asked + 0
		for (i = 1; i <= nk; i++) print "O", id, key[i], clean(otitle[i]), orec[i] + 0, clean(one[key[i]]), clean(ben[key[i]]), clean(risk[key[i]]), ochosen[i] + 0
		id = ""
	}
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	/^```/ { fence = !fence }
	fence { next }
	/^## P[0-9]+ / {
		endsec(); id = $2; p = index($0, " — "); q = p ? substr($0, p + length(" — ")) : ""
		type = ""; st = ""; dec = ""; ctx = ""; rec = ""; chosen = ""; applied = 0; asked = 0; sub_ = ""; nk = 0; hdr = 0
		split("", one); split("", ben); split("", risk); next
	}
	/^## / { endsec(); next }
	id == "" { next }
	/^### / { sub_ = substr($0, 5); next }
	sub_ == "" && /^\| \*\*(Status|Type|Decides)\*\* \|/ {
		f = $0; sub(/^\| \*\*/, "", f); name = substr(f, 1, index(f, "**") - 1); v = substr(f, index(f, "**") + 2)
		sub(/^ *\| */, "", v); sub(/ *\| *$/, "", v)
		if (name == "Status") st = v; else if (name == "Type") type = v; else dec = v
		next
	}
	st == "" && /\*\*Status:\*\*/ { s = $0; sub(/.*\*\*Status:\*\* */, "", s); sub(/ *·.*/, "", s); st = s }
	sub_ == "The question" && NF { ctx = ctx " " $0; next }
	sub_ == "Recommendation" && NF { rec = rec " " $0; next }
	sub_ == "Options at a glance" && /^\|/ {
		n = cells($0)
		if (!hdr) {
			hdr = 1
			for (i = 1; i <= n; i++) if (match(c[i], /^[A-Z]: /)) {
				t = substr(c[i], 4); nk++; key[nk] = substr(c[i], 1, 1)
				orec[nk] = (t ~ /\(Recommended\)/); ochosen[nk] = (t ~ /\(Chosen\)/)
				gsub(/ *\((Recommended|Chosen)\)/, "", t); otitle[nk] = t; col[i] = key[nk]
			}
			next
		}
		r = c[1]; gsub(/\*/, "", r)
		for (i = 2; i <= n; i++) if (col[i] != "") {
			if (r == "In one line") one[col[i]] = c[i]
			else if (r == "Main benefit") ben[col[i]] = c[i]
			else if (r == "Main risk") risk[col[i]] = c[i]
		}
		next
	}
	sub_ == "Decision" && /^- \*\*Chosen:\*\*/ { chosen = substr($0, index($0, ":**") + 3) }
	sub_ == "Decision" && /^- \*\*Applied:\*\* *not yet/ { applied = 1 }
	sub_ == "Decision" && /^- \*\*Asked:\*\*/ { asked = 1 }
	END { endsec() }' "$1"
}

state_of() { # <status> <applied> <asked>
	if [ "$2" = 1 ]; then echo apply; return; fi
	case $1 in Open) echo open ;; "Default applied") [ "$3" = 1 ] && echo open || echo done ;; *) echo done ;; esac
}
prec() { model "$doc" | awk -F'\t' -v id="$1" '$1 == "P" && $2 == id { print; exit }'; }
popts() { model "$doc" | awk -F'\t' -v id="$1" '$1 == "O" && $2 == id'; }
field() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '{ print $n }'; }
now() { date '+%Y-%m-%d %H:%M'; }
who() {
	if [ -n "$by" ]; then echo "$by"; return; fi
	local n; n=$(git -C "$(dirname "$doc")" config user.name 2>/dev/null)
	echo "${n:-the engineer}"
}

# rewrite <id>: change the proposal through the R_* settings in the environment:
#   R_STATUS     a new Status cell ("" keeps it)
#   R_MARK       the option key to mark (Chosen), "-" to clear the marks, "" to keep them
#   R_DEC_MODE   replace (R_DEC, lines split by \n, becomes the Decision section),
#                add (R_DEC becomes its first line), drop (lines starting R_DEC go)
#   R_GSTATUS / R_GCHOSEN  the At a glance Status / Chosen cells ("" keeps them)
rewrite() {
	local tmp="$doc.tmp.$$"
	R_ID=$1 R_NOW=$(now) R_CR=$(dl_crlf "$doc") R_BOM=$(dl_bom "$doc") awk '
	BEGIN { id = ENVIRON["R_ID"]; nst = ENVIRON["R_STATUS"]; mark = ENVIRON["R_MARK"]; mode = ENVIRON["R_DEC_MODE"]
		nd = split(ENVIRON["R_DEC"], dl, "\n"); gst = ENVIRON["R_GSTATUS"]; gch = ENVIRON["R_GCHOSEN"]
		cr = ENVIRON["R_CR"] + 0; bom = ENVIRON["R_BOM"] + 0; stamp = ENVIRON["R_NOW"] }
	function out(s) { if (!started && bom) s = "\357\273\277" s; started = 1; printf "%s%s\n", s, (cr ? "\r" : "") }
	function cells(line,   s, i, n, o, inl, ch) {
		s = line; o = ""; inl = 0
		for (i = 1; i <= length(s); i++) {
			ch = substr(s, i, 1)
			if (substr(s, i, 2) == "[[") inl = 1
			if (substr(s, i, 2) == "]]") inl = 0
			o = o ((ch == "|" && inl) ? "\001" : ch)
		}
		n = split(o, c, "|")
		for (i = 1; i <= n; i++) gsub(/\001/, "|", c[i])
		return n
	}
	function join(n,   i, l) { l = c[1]; for (i = 2; i <= n; i++) l = l "|" c[i]; return l }
	function writedec(   i) { for (i = 1; i <= nd; i++) out(dl[i]); out(""); wrote = 1 }
	function endsec() { if (insec && mode == "replace" && !wrote) { out("### Decision"); writedec() } insec = 0 }
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	skip && (/^### / || /^## / || /^---/) { skip = 0 }
	skip { next }
	/^## / { endsec(); glance = ($0 ~ /^## At a glance/); x = $2; insec = (x == id); sub_ = ""; hdr = 0 }
	/^---/ && insec { endsec() }
	/^- \*\*Last updated:\*\*/ { out("- **Last updated:** " stamp); next }
	glance && /^\|/ && (gst != "" || gch != "") {
		n = cells($0); x = c[2]; gsub(/^ +| +$/, "", x)
		if (x == id && n >= 8) { if (gst != "") c[n - 3] = " " gst " "; if (gch != "") c[n - 1] = " " gch " "; out(join(n)); next }
	}
	!insec { out($0); next }
	/^### / { sub_ = substr($0, 5) }
	/^### Option [A-Z] / && mark != "" {
		k = $3; l = $0; gsub(/ \(Chosen\)/, "", l); if (k == mark) l = l " (Chosen)"; out(l); next
	}
	/^### Decision/ {
		out($0)
		if (mode == "replace") { writedec(); skip = 1 }
		else if (mode == "add") { out(dl[1]); out(""); wrote = 1; skipblank = 1 }
		next
	}
	skipblank { skipblank = 0; if ($0 ~ /^[ \t]*$/) next }
	nst != "" && sub_ == "" && /^\| \*\*Status\*\* \|/ { out("| **Status** | " nst " |"); next }
	mark != "" && sub_ == "Options at a glance" && /^\|/ && !hdr {
		hdr = 1; n = cells($0)
		for (i = 1; i <= n; i++) {
			t = c[i]; gsub(/ \(Chosen\)/, "", t)
			if (match(t, /^ *[A-Z]: /)) { k = substr(t, RSTART + RLENGTH - 3, 1); if (k == mark) { sub(/ *$/, "", t); t = t " (Chosen) " } }
			c[i] = t
		}
		out(join(n)); next
	}
	mode == "drop" && sub_ == "Decision" && index($0, dl[1]) == 1 { if (dl[1] ~ /Asked/) skipblank = 1; next }
	{ out($0) }
	END { endsec() }' "$doc" >"$tmp" || { rm -f "$tmp"; die "could not write $doc"; }
	dl_put "$doc" "$tmp"
}

# ---- arguments ----
cmd=${1:-}; [ $# -gt 0 ] && shift
tsv=0; note=""; by=""; args=()
while [ $# -gt 0 ]; do
	case $1 in
	--tsv) tsv=1 ;;
	--note) [ $# -ge 2 ] || { usage; exit 2; }; note=$2; shift ;;
	--by) [ $# -ge 2 ] || { usage; exit 2; }; by=$2; shift ;;
	-h | --help) usage; exit 0 ;;
	*) args+=("$1") ;;
	esac
	shift
done
set -- "${args[@]+"${args[@]}"}"
case $cmd in
add) [ $# -ge 2 ] || { usage; exit 2; } ;;
decide | supersede) [ $# -eq 3 ] || { usage; exit 2; } ;;
applied | ask | show) [ $# -eq 2 ] || { usage; exit 2; } ;;
list | status | check) [ $# -eq 1 ] || { usage; exit 2; } ;;
-h | --help) usage; exit 0 ;;
*) usage; exit 2 ;;
esac
doc=$1
[ -f "$doc" ] || die "no such document: $doc" 2
note=$(printf '%s' "$note" | tr '\r\n' '  ' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
export R_STATUS="" R_MARK="" R_DEC_MODE="" R_DEC="" R_GSTATUS="" R_GCHOSEN=""

case $cmd in
list)
	model "$doc" | awk -F'\t' -v OFS='\t' -v tsv="$tsv" '
		$1 == "O" && $5 == 1 { rk[$2] = $3 ": " $4 }
		$1 == "P" { n++; ids[n] = $2; line[$2] = $0 }
		END {
			for (i = 1; i <= n; i++) {
				split(line[ids[i]], f, "\t")
				s = (f[11] == 1) ? "apply" : (f[5] == "Open") ? "open" : (f[5] == "Default applied" && f[12] == 1) ? "open" : "done"
				if (tsv) print f[2], f[4], f[5], s, rk[f[2]], f[10], f[3]
				else printf "%-4s %-16s %-6s %s\n", f[2], f[5], s, f[3]
			}
		}' ;;
status)
	model "$doc" | awk -F'\t' '$1 == "P" { t++; if ($11 == 1) a++; else if ($5 == "Open" || ($5 == "Default applied" && $12 == 1)) o++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\n", t, o, a, d }' ;;
show)
	r=$(prec "$2"); [ -n "$r" ] || die "no proposal $2 in $doc"
	printf '%s\n' "$r" | awk -F'\t' -v OFS='\t' '{ print "id", $2; print "question", $3; print "type", $4; print "status", $6
		print "decides", $7; print "context", $8; print "recommendation", $9; print "chosen", $10 }'
	sw=$(field "$r" 5)
	printf 'state\t%s\n' "$(state_of "$sw" "$(field "$r" 11)" "$(field "$r" 12)")"
	popts "$2" | awk -F'\t' -v OFS='\t' '{ d = $6; if ($7 != "") d = d (d == "" ? "" : ". ") "Benefit: " $7; if ($8 != "") d = d (d == "" ? "" : ". ") "Risk: " $8
		print "option", $3, $4, d, $5, 0 }'
	[ "$sw" = "Default applied" ] && printf 'option\tleave\tLeave it as applied for now\tThe recommendation stays in the plan, open for review.\t0\t0\n'
	printf 'option\tother\tSomething else\tNone of these: say what you want instead, and the planner works it out with you.\t0\t1\n' ;;
check)
	tmpm="$doc.model.$$"; model "$doc" >"$tmpm"
	bad=$(awk -F'\t' '
		FNR == NR {
			if ($1 == "P") { if (seen[$2]++) print $2 ": the P number is used twice"
				if ($5 !~ /^(Open|Default applied|Decided|Superseded)$/) print $2 ": unknown status \"" $6 "\""
				if ($4 !~ /^(Approach|Requirement or scope|Blocking decision|Review item)$/) print $2 ": unknown type \"" $4 "\""
				if ($5 == "Decided" && $10 == "") print $2 ": decided, but no Chosen line"
				st[$2] = $5; ids[$2] = 1 }
			else { no[$2]++; if ($5 == 1) nr[$2]++ }
			next
		}
		{ sub(/\r$/, "") }
		/^## / { g = ($0 ~ /^## At a glance/) }
		g && /^\| *P[0-9]+ *\|/ { n = split($0, c, "|"); x = c[2]; gsub(/^ +| +$/, "", x); y = c[n - 3]; gsub(/^ +| +$/, "", y); row[x] = y }
		END {
			for (i in ids) {
				if (no[i] < 2 || no[i] > 4) print i ": " no[i] + 0 " options (two to four)"
				if (nr[i] > 1) print i ": more than one option is recommended"
				if (!(i in row)) print i ": no At a glance row"
				else if (row[i] != st[i]) print i ": At a glance says \"" row[i] "\", the proposal says \"" st[i] "\""
			}
		}' "$tmpm" "$doc")
	rm -f "$tmpm"
	if [ -n "$bad" ]; then printf '%s\n' "$bad" | sort; exit 1; fi
	echo ok ;;
add)
	shift
	grep -q '^## At a glance' "$doc" || die "no \"## At a glance\" section in $doc"
	for part in "$@"; do
		[ -f "$part" ] || die "no such part: $part" 2
		last=$(tr -d '\r' <"$part" | awk 'NF { l = $0 } END { gsub(/^[ \t]+|[ \t]+$/, "", l); print l }')
		[ "$last" = "$MARK" ] || die "the part is not complete (no $MARK at its end): $part"
	done
	dl_lock "$doc"
	have=" $(model "$doc" | awk -F'\t' '$1 == "P" { printf "%s ", $2 }')"
	new=""
	for part in "$@"; do
		m=$(model "$part")
		ps=$(printf '%s\n' "$m" | awk -F'\t' '$1 == "P"')
		[ -n "$ps" ] || die "the part has no proposal (## P<n> — <question>): $part"
		probs=$(printf '%s\n' "$m" | awk -F'\t' -v have="$have" '
			$1 == "P" { if (index(have, " " $2 " ")) print $2 " is already in the document"
				if ($5 !~ /^(Open|Default applied)$/) print $2 ": a new proposal is Open or Default applied, not \"" $6 "\""
				if ($4 == "") print $2 ": no Type"; ids[$2] = 1 }
			$1 == "O" { no[$2]++ }
			END { for (i in ids) if (no[i] < 2) print i ": needs two to four options in Options at a glance" }')
		[ -z "$probs" ] || die "$probs"
		have="$have$(printf '%s\n' "$ps" | awk -F'\t' '{ printf "%s ", $2 }')"
		new="$new$m"$'\n'
	done
	rows=$(printf '%s' "$new" | awk -F'\t' '
		$1 == "O" && $5 == 1 { rk[$2] = $3 ": " $4 }
		$1 == "P" { n++; ids[n] = $2; q[$2] = $3; t[$2] = $4; s[$2] = $5 }
		END { for (i = 1; i <= n; i++) { k = ids[i]; x = q[k]; gsub(/\|/, "/", x); printf "| %s | %s | %s | %s | %s | — |\n", k, x, t[k], s[k], (k in rk) ? rk[k] : "—" } }')
	cr=$(dl_crlf "$doc"); bom=$(dl_bom "$doc"); tmp="$doc.tmp.$$"
	{
		C_ROWS=$rows C_CR=$cr C_BOM=$bom C_NOW=$(now) awk '
		BEGIN { nr = split(ENVIRON["C_ROWS"], rows, "\n"); cr = ENVIRON["C_CR"] + 0; bom = ENVIRON["C_BOM"] + 0; stamp = ENVIRON["C_NOW"] }
		function out(s) { if (!started && bom) s = "\357\273\277" s; started = 1; printf "%s%s\n", s, (cr ? "\r" : "") }
		function flushblank() { for (; blanks > 0; blanks--) out("") }
		function addrows(   i) { for (i = 1; i <= nr; i++) out(rows[i]); done = 1 }
		{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
		/^- \*\*Last updated:\*\*/ { flushblank(); out("- **Last updated:** " stamp); next }
		/^## / { if (g && intab && !done) addrows(); g = ($0 ~ /^## At a glance/); intab = 0 }
		g && /^\|/ { intab = 1 }
		g && intab && !/^\|/ && !done { addrows() }
		/^[ \t]*$/ { blanks++; next }
		{ flushblank(); out($0) }
		END { if (g && !done) addrows() }' "$doc"
		for part in "$@"; do
			if [ "$cr" = 1 ]; then printf '\r\n'; else printf '\n'; fi
			awk -v CR="$cr" -v MARK="$MARK" '
			{ l = $0; sub(/\r$/, "", l); if (FNR == 1) sub(/^\357\273\277/, "", l)
			  t = l; gsub(/^[ \t]+|[ \t]+$/, "", t); if (t == MARK) next
			  if (t == "") { if (started) blanks++; next }
			  for (; blanks > 0; blanks--) printf "%s\n", (CR ? "\r" : "")
			  started = 1; printf "%s%s\n", l, (CR ? "\r" : "") }' "$part"
		done
	} >"$tmp" || { rm -f "$tmp"; die "could not write $doc"; }
	dl_put "$doc" "$tmp"
	echo "added $(printf '%s' "$new" | awk -F'\t' '$1 == "P" { printf "%s ", $2 }')" ;;
decide)
	id=$2; opt=$3
	dl_lock "$doc"
	r=$(prec "$id"); [ -n "$r" ] || die "no proposal $id in $doc"
	sw=$(field "$r" 5); ap=$(field "$r" 11)
	case $sw in
	Open | "Default applied") ;;
	*) [ "$ap" = 1 ] || die "$id is $sw: a decided proposal is superseded by a new one, not decided again" ;;
	esac
	d=$(dl_today)
	if [ "$opt" = leave ]; then
		[ "$sw" = "Default applied" ] && [ "$ap" != 1 ] || die "$id is $sw: only a Default applied proposal can be left as it is"
		R_DEC_MODE=drop R_DEC="- **Asked:**" rewrite "$id"
		echo "$id: left as applied"; exit 0
	fi
	if [ "$opt" = other ]; then
		[ -n "$note" ] || die "other needs --note: what the engineer wants instead"
		R_MARK=- R_DEC_MODE=replace R_DEC="- **Chosen:** Other: $note"$'\n'"- **By / when:** $(who), $d"$'\n'"- **Applied:** not yet" \
			R_GCHOSEN="Other (to settle)" rewrite "$id"
		echo "$id: other, to settle"; exit 0
	fi
	o=$(popts "$id" | awk -F'\t' -v k="$opt" '$3 == k { print; exit }')
	[ -n "$o" ] || die "$id has no option $opt (its options: $(popts "$id" | cut -f3 | tr '\n' ' ')${sw:+, other}$([ "$sw" = "Default applied" ] && echo ", leave"))"
	title=$(field "$o" 4)
	others=$(popts "$id" | awk -F'\t' -v k="$opt" '$3 != k { printf "%s%s: %s", (n++ ? " · " : ""), $3, $4 }')
	dec="- **Chosen:** Option $opt: $title"$'\n'"- **By / when:** $(who), $d"$'\n'"- **Why:** ${note:-—}"
	[ -n "$others" ] && dec="$dec"$'\n'"- **Not chosen:** $others"
	dec="$dec"$'\n'"- **Applied:** not yet"
	R_STATUS="Decided $d" R_MARK=$opt R_DEC_MODE=replace R_DEC=$dec R_GSTATUS=Decided R_GCHOSEN="$opt: $title" rewrite "$id"
	echo "$id: Decided ($opt: $title)" ;;
applied)
	id=$2
	dl_lock "$doc"
	r=$(prec "$id"); [ -n "$r" ] || die "no proposal $id in $doc"
	[ "$(field "$r" 11)" = 1 ] || die "$id is not waiting to be applied"
	R_DEC_MODE=drop R_DEC="- **Applied:** not yet" rewrite "$id"
	echo "$id: applied" ;;
supersede)
	id=$2; by_id=$3
	dl_lock "$doc"
	r=$(prec "$id"); [ -n "$r" ] || die "no proposal $id in $doc"
	[ -n "$(prec "$by_id")" ] || die "no proposal $by_id in $doc: add it first"
	[ "$id" != "$by_id" ] || die "a proposal can't supersede itself"
	[ "$(field "$r" 5)" != Superseded ] || die "$id is already superseded"
	R_STATUS="Superseded by $by_id ($(dl_today))" R_GSTATUS=Superseded R_DEC_MODE=drop R_DEC="- **Applied:** not yet" rewrite "$id"
	echo "$id: superseded by $by_id" ;;
ask)
	id=$2
	dl_lock "$doc"
	r=$(prec "$id"); [ -n "$r" ] || die "no proposal $id in $doc"
	[ "$(field "$r" 5)" = "Default applied" ] || die "$id is $(field "$r" 5): only a Default applied proposal is asked (an Open one is always waiting)"
	if [ "$(field "$r" 12)" = 1 ]; then echo "$id: already asked"; exit 0; fi
	R_DEC_MODE=add R_DEC="- **Asked:** $(dl_today)" rewrite "$id"
	echo "$id: asked" ;;
esac
