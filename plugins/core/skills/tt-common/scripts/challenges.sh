#!/usr/bin/env bash
# challenges.sh: the only writer of a "<Prefix> - Challenges.md" document once it
# exists. Appends an adversary's challenge set, records the planner's take and the
# engineer's decision on each challenge, and marks accepted ones applied. Needs
# bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: challenges.sh append <doc> <set.md>
       challenges.sh take <doc> CH<n> <option>        (the take's text on stdin)
       challenges.sh decide <doc> CH<n> <option> [--note <text>] [--fi <fi-notes.md>]
       challenges.sh applied <doc> CH<n> <resolution>
       challenges.sh list [--tsv] [--stage <stage>] <doc>
       challenges.sh show <doc> CH<n>
       challenges.sh status [--stage <stage>] <doc>
       challenges.sh check <doc>

append   Appends a challenge set (an adversary's file, ending with
         <!-- tt:end -->) after the document's last line, and adds a row per
         challenge to "## At a glance". Refuses a set whose CH numbers are
         already in the document.
take     Records the planner's view of a challenge before it is put to the
         engineer: "- **Take:** *Recommend <option>.* <text>", just above its
         Outcome line.
decide   Records the engineer's decision. Options:
           accept   Accept & change: Outcome Accepted, Resolution "To apply: …"
                    until the planner has changed the plan (then: applied)
           rebut    Rebut (needs --note, the engineer's reason): Rebutted
           defer    Defer: Deferred, and a line in the plan's fi-notes.md
                    (<doc folder>/.tt/<Prefix> - Plan/research/fi-notes.md
                    unless --fi names another)
           dismiss  Dismiss (minor challenges only): Dismissed
         Blocking and significant challenges take accept, rebut or defer;
         minor ones take accept or dismiss. A decision can be changed until an
         accepted challenge has been applied.
applied  Marks an accepted challenge applied: its Resolution becomes
         "<date>: <resolution>" (the IDs the change touched).
list     id, severity, outcome and title per challenge; --tsv prints
         id stage severity target outcome state title, where state is
         open (no decision), apply (accepted, not yet applied) or done.
show     One challenge as "<field><TAB><value>" lines (id stage title
         severity target assumption why evidence question take recommended
         outcome resolution state), then one line per option it can take:
         option<TAB>key<TAB>title<TAB>detail<TAB>recommended 0|1<TAB>needs-note 0|1
status   total=, open=, apply=, done= (for one stage with --stage).
check    The layout: every challenge has a known severity and outcome, a
         Resolution line, a valid take, a unique CH and a matching At a glance
         row. Prints the problems.

The stage of a challenge is the "## <Stage> — challenged …" heading above it.
Line endings and a BOM are kept. Writes take a lock and replace the file whole.
Exit: 0 ok, 1 refused or problems found, 2 usage error or missing file.
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
. "$here/decide-lib.sh"
MARK='<!-- tt:end -->'
me=challenges.sh

die() { echo "$me: $*" >&2; exit "${2:-1}"; }

# model <file>: one TSV line per challenge:
#   1 id 2 stage 3 title 4 severity 5 target 6 assumption 7 why 8 evidence
#   9 question 10 recommended 11 take 12 outcome 13 resolution
model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function clean(s) { gsub(/\t/, " ", s); return trim(s) }
	function endfield() { if (fname != "") val[fname] = trim(fval); fname = "" }
	function endblock(   rec, tk) {
		endfield()
		if (id != "") {
			rec = ""; tk = val["Take"]
			if (match(tk, /^\*Recommend [a-z]+\.\*/)) { rec = substr(tk, 12, RLENGTH - 13); tk = trim(substr(tk, RLENGTH + 1)) }
			print id, stage, clean(title), clean(sev), clean(target), clean(val["Assumption attacked"]), clean(val["Why it may be wrong"]), clean(val["Evidence"]), clean(val["Question for the engineer"]), rec, clean(tk), clean(val["Outcome"]), clean(val["Resolution"])
		}
		id = ""; sev = ""; target = ""; title = ""; split("", val)
	}
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	/^```/ { fence = !fence }
	fence { next }
	/^## / {
		endblock(); s = substr($0, 4); p = index(s, " — challenged")
		stage = p ? substr(s, 1, p - 1) : ""; next
	}
	/^### CH[0-9]+/ {
		endblock(); id = $2; sub(/[^A-Za-z0-9]+$/, "", id)
		p = index($0, " — "); title = p ? substr($0, p + length(" — ")) : ""; next
	}
	/^#/ { endblock(); next }
	id == "" { next }
	/^\*\*/ { endblock(); next }
	/^[ \t]*$/ { endfield(); next }
	/^- \*\*[^*]+:\*\*/ {
		endfield(); s = substr($0, 5); p = index(s, ":**")
		fname = substr(s, 1, p - 1); fval = substr(s, p + 3)
		if (fname == "Severity") {
			q = index(fval, "**Target:**")
			if (q) { target = substr(fval, q + 11); sev = substr(fval, 1, q - 1) } else sev = fval
			gsub(/·/, "", sev); sev = trim(sev)
		}
		next
	}
	fname != "" { fval = fval " " trim($0) }
	END { endblock() }' "$1"
}

# rec_of <id>: the challenge's model line (empty if it isn't there)
rec_of() { model "$doc" | awk -F'\t' -v id="$1" '$1 == id { print; exit }'; }
field() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '{ print $n }'; }
state_of() { # <outcome> <resolution>
	case $1 in
	Open | "") echo open ;;
	Accepted) case $2 in "To apply"*) echo apply ;; *) echo done ;; esac ;;
	*) echo done ;;
	esac
}
options_for() { case $1 in minor) echo "accept dismiss" ;; *) echo "accept rebut defer" ;; esac; }
opt_title() { case $1 in accept) echo "Accept & change" ;; rebut) echo "Rebut" ;; defer) echo "Defer" ;; dismiss) echo "Dismiss" ;; esac; }
opt_detail() {
	case $1 in
	accept) echo "The plan changes to answer it, through the stage's own rules." ;;
	rebut) echo "The plan stands. Your reason is recorded." ;;
	defer) echo "Not now: noted for Future Iterations." ;;
	dismiss) echo "Minor: not taken up." ;;
	esac
}
valid_opt() { case " $(options_for "$1") " in *" $2 "*) return 0 ;; esac; return 1; }

# rewrite <id> [o <outcome>] [r <resolution>] [t <take>]: replace those lines of
# the challenge (and its At a glance Outcome cell), keeping line endings and BOM
rewrite() {
	local id=$1 so=0 sr=0 st=0 vo="" vr="" vt="" tmp
	shift
	while [ $# -gt 0 ]; do
		case $1 in o) so=1; vo=$2 ;; r) sr=1; vr=$2 ;; t) st=1; vt=$2 ;; esac
		shift 2
	done
	tmp="$doc.tmp.$$"
	C_ID=$id C_SO=$so C_SR=$sr C_ST=$st C_VO=$vo C_VR=$vr C_VT=$vt C_CR=$(dl_crlf "$doc") C_BOM=$(dl_bom "$doc") awk '
	BEGIN { id = ENVIRON["C_ID"]; so = ENVIRON["C_SO"] + 0; sr = ENVIRON["C_SR"] + 0; st = ENVIRON["C_ST"] + 0
		vo = ENVIRON["C_VO"]; vr = ENVIRON["C_VR"]; vt = ENVIRON["C_VT"]; cr = ENVIRON["C_CR"] + 0; bom = ENVIRON["C_BOM"] + 0 }
	function out(s) { if (!started && bom) s = "\357\273\277" s; started = 1; printf "%s%s\n", s, (cr ? "\r" : "") }
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
	skip && (/^[ \t]*$/ || /^- \*\*/ || /^#/ || /^\*\*/) { skip = 0 }
	skip { next }
	/^## / { glance = ($0 ~ /^## At a glance/); inb = 0 }
	/^### / { x = $2; sub(/[^A-Za-z0-9]+$/, "", x); inb = (x == id); seen = 0 }
	glance && so && /^\|/ {
		n = split($0, c, "|"); x = c[2]; gsub(/^ +| +$/, "", x)
		if (x == id && n >= 7) { c[n - 1] = " " vo " "; l = c[1]; for (i = 2; i <= n; i++) l = l "|" c[i]; out(l); next }
	}
	inb && /^- \*\*Take:\*\*/ { seen = 1; if (st) { out("- **Take:** " vt); skip = 1; next } }
	inb && /^- \*\*Outcome:\*\*/ {
		if (st && !seen) { out("- **Take:** " vt); seen = 1 }
		if (so) { out("- **Outcome:** " vo); skip = 1; next }
	}
	inb && /^- \*\*Resolution:\*\*/ { if (sr) { out("- **Resolution:** " vr); skip = 1; next } }
	{ out($0) }' "$doc" >"$tmp" || { rm -f "$tmp"; die "could not write $doc"; }
	dl_put "$doc" "$tmp"
}

# fi_path: where a deferred challenge is noted
fi_path() {
	if [ -n "$fi" ]; then echo "$fi"; return; fi
	local d n
	d=$(dirname "$doc"); n=$(basename "$doc"); n=${n% - Challenges.md}
	echo "$d/.tt/$n - Plan/research/fi-notes.md"
}
fi_drop() { # <id>: remove the line this script wrote for it
	local f; f=$(fi_path)
	[ -f "$f" ] || return 0
	awk -v id="$1" 'index($0, "- " id " (deferred ") != 1' "$f" >"$f.tmp.$$" && mv -f "$f.tmp.$$" "$f"
}
fi_add() { # <id> <title> <note>
	local f; f=$(fi_path)
	mkdir -p "$(dirname "$f")" || die "cannot create $(dirname "$f")"
	fi_drop "$1"
	printf -- '- %s (deferred %s): %s%s\n' "$1" "$(dl_today)" "$2" "${3:+ — $3}" >>"$f"
}

# ---- arguments ----
cmd=${1:-}; [ $# -gt 0 ] && shift
tsv=0; stage=""; note=""; fi=""; hasnote=0
args=()
while [ $# -gt 0 ]; do
	case $1 in
	--tsv) tsv=1 ;;
	--stage) [ $# -ge 2 ] || { usage; exit 2; }; stage=$2; shift ;;
	--note) [ $# -ge 2 ] || { usage; exit 2; }; note=$2; hasnote=1; shift ;;
	--fi) [ $# -ge 2 ] || { usage; exit 2; }; fi=$2; shift ;;
	-h | --help) usage; exit 0 ;;
	*) args+=("$1") ;;
	esac
	shift
done
set -- "${args[@]+"${args[@]}"}"
case $cmd in
append) [ $# -eq 2 ] || { usage; exit 2; } ;;
take | decide) [ $# -eq 3 ] || { usage; exit 2; } ;;
applied) [ $# -eq 3 ] || { usage; exit 2; } ;;
show) [ $# -eq 2 ] || { usage; exit 2; } ;;
list | status | check) [ $# -eq 1 ] || { usage; exit 2; } ;;
-h | --help) usage; exit 0 ;;
*) usage; exit 2 ;;
esac
doc=$1
[ -f "$doc" ] || die "no such document: $doc" 2

case $cmd in
list)
	model "$doc" | awk -F'\t' -v st="$stage" -v tsv="$tsv" -v OFS='\t' '
		st != "" && $2 != st { next }
		{ s = ($12 == "Open" || $12 == "") ? "open" : ($12 == "Accepted" && $13 ~ /^To apply/) ? "apply" : "done"
		  if (tsv) print $1, $2, $4, $5, $12, s, $3
		  else printf "%-6s %-12s %-10s %s\n", $1, $4, $12 (s == "apply" ? " (to apply)" : ""), $3 }' ;;
status)
	model "$doc" | awk -F'\t' -v st="$stage" '
		st != "" && $2 != st { next }
		{ t++; if ($12 == "Open" || $12 == "") o++; else if ($12 == "Accepted" && $13 ~ /^To apply/) a++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\n", t, o, a, d }' ;;
show)
	r=$(rec_of "$2"); [ -n "$r" ] || die "no challenge $2 in $doc"
	printf '%s\n' "$r" | awk -F'\t' -v OFS='\t' '{
		print "id", $1; print "stage", $2; print "title", $3; print "severity", $4; print "target", $5
		print "assumption", $6; print "why", $7; print "evidence", $8; print "question", $9
		print "take", $11; print "recommended", $10; print "outcome", $12; print "resolution", $13 }'
	sev=$(field "$r" 4); rec=$(field "$r" 10)
	printf 'state\t%s\n' "$(state_of "$(field "$r" 12)" "$(field "$r" 13)")"
	for k in $(options_for "$sev"); do
		nn=0; [ "$k" = rebut ] && nn=1
		rr=0; [ "$k" = "$rec" ] && rr=1
		printf 'option\t%s\t%s\t%s\t%s\t%s\n' "$k" "$(opt_title "$k")" "$(opt_detail "$k")" "$rr" "$nn"
	done ;;
check)
	model "$doc" >"$doc.model.$$"
	bad=$(awk -F'\t' '
		FNR == NR {
			if (seen[$1]++) print $1 ": the CH number is used twice"
			if ($4 !~ /^(blocking|significant|minor)$/) print $1 ": unknown severity \"" $4 "\""
			if ($12 !~ /^(Open|Accepted|Rebutted|Deferred|Dismissed)$/) print $1 ": unknown outcome \"" $12 "\""
			if ($13 == "") print $1 ": no Resolution line"
			if ($10 != "" && !(($4 == "minor" && $10 ~ /^(accept|dismiss)$/) || ($4 != "minor" && $10 ~ /^(accept|rebut|defer)$/))) print $1 ": the take recommends \"" $10 "\", not an option it can take"
			out[$1] = $12; next
		}
		{ sub(/\r$/, "") }
		/^## / { g = ($0 ~ /^## At a glance/) }
		g && /^\| *CH[0-9]+ *\|/ { n = split($0, c, "|"); x = c[2]; y = c[n - 1]; gsub(/^ +| +$/, "", x); gsub(/^ +| +$/, "", y); row[x] = y }
		END {
			for (i in out) {
				if (!(i in row)) print i ": no At a glance row"
				else if (row[i] != out[i]) print i ": At a glance says \"" row[i] "\", the challenge says \"" out[i] "\""
			}
		}' "$doc.model.$$" "$doc")
	rm -f "$doc.model.$$"
	if [ -n "$bad" ]; then printf '%s\n' "$bad" | sort; exit 1; fi
	echo ok ;;
append)
	set_file=$2
	[ -f "$set_file" ] || die "no such set: $set_file" 2
	last=$(tr -d '\r' <"$set_file" | awk 'NF { l = $0 } END { gsub(/^[ \t]+|[ \t]+$/, "", l); print l }')
	[ "$last" = "$MARK" ] || die "the set is not complete (no $MARK at its end): $set_file"
	grep -q '^## At a glance' "$doc" || die "no \"## At a glance\" section in $doc"
	dl_lock "$doc"
	new=$(model "$set_file")
	[ -n "$new" ] || die "the set has no challenges (### CH<n> — <title>): $set_file"
	have=$(model "$doc" | cut -f1)
	clash=$(printf '%s\n' "$new" | awk -F'\t' -v have=" $(echo $have) " 'index(have, " " $1 " ") { printf "%s ", $1 }')
	[ -z "$clash" ] || die "already in the document: $clash"
	dups=$(printf '%s\n' "$new" | cut -f1 | sort | uniq -d | tr '\n' ' ')
	[ -z "$dups" ] || die "used twice in the set: $dups"
	rows=$(printf '%s\n' "$new" | awk -F'\t' '{ t = $5; gsub(/\|/, "/", t); o = ($12 == "" ? "Open" : $12); printf "| %s | %s | %s | %s | %s |\n", $1, $2, $4, t, o }')
	cr=$(dl_crlf "$doc"); bom=$(dl_bom "$doc"); tmp="$doc.tmp.$$"
	{
		C_ROWS=$rows C_CR=$cr C_BOM=$bom awk '
		BEGIN { nr = split(ENVIRON["C_ROWS"], rows, "\n"); cr = ENVIRON["C_CR"] + 0; bom = ENVIRON["C_BOM"] + 0 }
		function out(s) { if (!started && bom) s = "\357\273\277" s; started = 1; printf "%s%s\n", s, (cr ? "\r" : "") }
		function flushblank() { for (; blanks > 0; blanks--) out("") }
		function addrows() { for (i = 1; i <= nr; i++) out(rows[i]); done = 1 }
		{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, "") }
		/^## / { if (g && intab && !done) addrows(); g = ($0 ~ /^## At a glance/); intab = 0 }
		g && /^\|/ { intab = 1 }
		g && intab && !/^\|/ && !done { addrows() }
		/^[ \t]*$/ { blanks++; next }
		{ flushblank(); out($0) }
		END { if (g && !done) addrows() }' "$doc"
		if [ "$cr" = 1 ]; then printf '\r\n'; else printf '\n'; fi
		awk -v CR="$cr" -v MARK="$MARK" '
		{ l = $0; sub(/\r$/, "", l); if (FNR == 1) sub(/^\357\273\277/, "", l)
		  t = l; gsub(/^[ \t]+|[ \t]+$/, "", t); if (t == MARK) next
		  if (t == "") { if (started) blanks++; next }
		  for (; blanks > 0; blanks--) printf "%s\n", (CR ? "\r" : "")
		  started = 1; printf "%s%s\n", l, (CR ? "\r" : "") }' "$set_file"
	} >"$tmp" || { rm -f "$tmp"; die "could not write $doc"; }
	dl_put "$doc" "$tmp"
	echo "appended $(printf '%s\n' "$new" | wc -l | tr -d ' ') challenges: $(printf '%s\n' "$new" | cut -f1 | tr '\n' ' ')" ;;
take)
	id=$2; opt=$3
	dl_lock "$doc"
	r=$(rec_of "$id"); [ -n "$r" ] || die "no challenge $id in $doc"
	sev=$(field "$r" 4)
	valid_opt "$sev" "$opt" || die "$id is $sev: its options are $(options_for "$sev")"
	text=$(tr -d '\r' | awk 'NF { gsub(/^[ \t]+|[ \t]+$/, ""); s = s (s == "" ? "" : " ") $0 } END { print s }')
	[ -n "$text" ] || die "no take on stdin"
	rewrite "$id" t "*Recommend $opt.* $text"
	echo "$id: take recorded (recommends $opt)" ;;
decide)
	id=$2; opt=$3
	dl_lock "$doc"
	r=$(rec_of "$id"); [ -n "$r" ] || die "no challenge $id in $doc"
	sev=$(field "$r" 4); was=$(field "$r" 12); res=$(field "$r" 13); title=$(field "$r" 3)
	[ "$(state_of "$was" "$res")" = done ] && [ "$was" = Accepted ] && die "$id was accepted and has been applied; change the plan through its stage instead"
	valid_opt "$sev" "$opt" || die "$id is $sev: its options are $(options_for "$sev")"
	note=$(printf '%s' "$note" | tr '\r\n' '  ' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }')
	if [ "$opt" = rebut ] && [ -z "$note" ]; then die "rebut needs --note: the engineer's reason"; fi
	d=$(dl_today)
	case $opt in
	accept) o=Accepted; rs="To apply${note:+: $note}" ;;
	rebut) o=Rebutted; rs="$d: $note" ;;
	defer) o=Deferred; rs="$d: deferred to Future Iterations${note:+: $note}" ;;
	dismiss) o=Dismissed; rs="$d: minor, not taken up${note:+: $note}" ;;
	esac
	rewrite "$id" o "$o" r "$rs"
	if [ "$opt" = defer ]; then fi_add "$id" "$title" "$note"; elif [ "$was" = Deferred ]; then fi_drop "$id"; fi
	echo "$id: $o" ;;
applied)
	id=$2; text=$(printf '%s' "$3" | tr '\r\n' '  ')
	dl_lock "$doc"
	r=$(rec_of "$id"); [ -n "$r" ] || die "no challenge $id in $doc"
	[ "$(state_of "$(field "$r" 12)" "$(field "$r" 13)")" = apply ] || die "$id is not waiting to be applied (outcome: $(field "$r" 12))"
	[ -n "$text" ] || die "applied needs the resolution (the IDs the change touched)"
	rewrite "$id" r "$(dl_today): $text"
	echo "$id: applied" ;;
esac
