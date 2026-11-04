#!/usr/bin/env bash
# questions.sh: the only writer of a question list, a small document of questions a
# skill has worked out before asking any of them (design choices, check findings,
# open questions, candidate constraints, a work unit's engineer checks), each with
# its options, so they can be answered one at a time in the chat or all together
# outside it. Lists live in <feature folder>/.tt/<Prefix> - Questions/<list>.md.
# Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: questions.sh init <list.md> --title <title> [--for <what the answers feed>] [--feature <Prefix>]
       questions.sh add <list.md>                 (questions on stdin)
       questions.sh decide <list.md> Q<n> <option> [--note <text>]
       questions.sh applied <list.md> Q<n> [<what was done>]
       questions.sh list [--tsv] <list.md>
       questions.sh show <list.md> Q<n>
       questions.sh status <list.md>
       questions.sh check <list.md>

init     Creates an empty list (refused if it exists). Its folder is made.
add      Adds questions from stdin, numbered after the highest Q, each written as
           title: <one line>
           ref: <what it refers to, e.g. "WU3 check 2" (optional)>
           context: <what the person needs to know; more lines indented two spaces>
           take: <your view, and why (optional)>
           option: <key> | <title> | <detail> [| recommended] [| note]
         with a line "---" between questions. Two or more options; keys are
         letters, digits and "-"; "note" means the option needs the person's
         words (--note) when chosen. At most one option is recommended.
decide   Records the chosen option (and the note). A choice can be changed
         until the question is applied.
applied  Marks a decided question carried out (optionally saying how).
list     id, state, decision and title per question; --tsv prints
           id state decision ref title
         where state is open (no decision), apply (decided, not yet carried
         out) or done.
show     One question as "<field><TAB><value>" lines (id title ref context take
         decision note applied state list for; context lines are joined by
         " / "), then one line per option:
         option<TAB>key<TAB>title<TAB>detail<TAB>recommended 0|1<TAB>needs-note 0|1
status   total=, open=, apply=, done=, and title= and for= of the list.
check    The layout and the rules above. Prints the problems.

The list's own Status line (Open, Decided, Done) follows its questions. Line
endings and a BOM are kept. Writes take a lock and replace the file whole.
Exit: 0 ok, 1 refused or problems found, 2 usage error or missing file.
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
. "$here/decide-lib.sh"
me=questions.sh
die() { echo "$me: $*" >&2; exit "${2:-1}"; }
SEP=$'\001' # joins a field's lines in the model

# model <list>: the list as records (lines of a field joined by \001):
#   H title feature for
#   Q id title ref context take decision note applied
#   O id key title detail recommended needs-note
model() {
	awk -v OFS='\t' '
	function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
	function v(s) { s = trim(s); return (s == "—" || s == "-") ? "" : s }
	function endq() { if (id != "") print "Q", id, qt, ref, ctx, take, dec, note, app; id = "" }
	{ sub(/\r$/, ""); if (NR == 1) sub(/^\357\273\277/, ""); gsub(/\t/, " ") }
	/^# / && !h { h = 1; title = substr($0, 3); next }
	/^## Q[0-9]+ / {
		if (!hp) { print "H", title, feature, forwhat; hp = 1 }
		endq(); id = $2; p = index($0, " — "); qt = p ? substr($0, p + length(" — ")) : ""
		ref = ""; ctx = ""; take = ""; dec = ""; note = ""; app = ""; mode = ""; next
	}
	id == "" && /^- \*\*Feature:\*\*/ { feature = v(substr($0, index($0, ":**") + 3)); next }
	id == "" && /^- \*\*For:\*\*/ { forwhat = v(substr($0, index($0, ":**") + 3)); next }
	id == "" { next }
	/^- \*\*[A-Za-z]+:\*\*/ {
		f = substr($0, 5); name = substr(f, 1, index(f, ":**") - 1); val = substr(f, index(f, ":**") + 3); mode = ""
		if (name == "Ref") ref = v(val)
		else if (name == "Context") { mode = "ctx"; if (v(val) != "") ctx = v(val) }
		else if (name == "Take") take = v(val)
		else if (name == "Options") mode = "opt"
		else if (name == "Decision") { dec = v(val); sub(/ .*/, "", dec) }
		else if (name == "Note") note = v(val)
		else if (name == "Applied") app = v(val)
		next
	}
	mode == "opt" && /^  - \*\*[^*]+\*\* — / {
		s = substr($0, 7); k = substr(s, 1, index(s, "**") - 1); r = substr(s, index(s, "**") + 2); sub(/^ — /, "", r)
		rec = (r ~ /\*\(recommended\)\*/); nn = (r ~ /\*\(needs a note\)\*/)
		gsub(/ *\*\((recommended|needs a note)\)\*/, "", r)
		p = index(r, ": "); t = p ? substr(r, 1, p - 1) : r; d = p ? substr(r, p + 2) : ""
		print "O", id, k, trim(t), trim(d), rec, nn; next
	}
	mode == "ctx" && /^  / { l = substr($0, 3); ctx = (ctx == "" ? l : ctx "\001" l); next }
	END { if (!hp) print "H", title, feature, forwhat; endq() }' "$1"
}

# render <model> <crlf> <bom>: the list's document
render() {
	awk -F'\t' -v cr="$2" -v bom="$3" '
	function out(s) { if (!started && bom == 1) s = "\357\273\277" s; started = 1; printf "%s%s\n", s, (cr == 1 ? "\r" : "") }
	function d(s) { return s == "" ? "—" : s }
	$1 == "H" { title = $2; feature = $3; forwhat = $4; next }
	$1 == "Q" { n++; q[n] = $0; ids[$2] = n; next }
	$1 == "O" { no[$2]++; o[$2, no[$2]] = $0 }
	END {
		for (i = 1; i <= n; i++) { split(q[i], f, "\t"); if (f[7] != "") decided++; if (f[9] != "") applied++ }
		status = (n == 0 || decided < n) ? "Open" : (applied < n) ? "Decided" : "Done"
		out("# " title); out("")
		if (feature != "") out("- **Feature:** " feature)
		if (forwhat != "") out("- **For:** " forwhat)
		out("- **Status:** " status); out("- **Decided:** " decided + 0 " of " n + 0)
		for (i = 1; i <= n; i++) {
			split(q[i], f, "\t"); id = f[2]
			out(""); out("## " id " — " f[3])
			if (f[4] != "") out("- **Ref:** " f[4])
			out("- **Context:**")
			m = split(f[5], cl, "\001"); for (j = 1; j <= m; j++) out("  " cl[j])
			if (f[6] != "") out("- **Take:** " f[6])
			out("- **Options:**")
			for (j = 1; j <= no[id]; j++) {
				split(o[id, j], g, "\t")
				out("  - **" g[3] "** — " g[4] (g[5] != "" ? ": " g[5] : "") (g[6] == 1 ? " *(recommended)*" : "") (g[7] == 1 ? " *(needs a note)*" : ""))
			}
			dt = ""; for (j = 1; j <= no[id]; j++) { split(o[id, j], g, "\t"); if (g[3] == f[7]) dt = g[4] }
			out("- **Decision:** " (f[7] == "" ? "—" : f[7] (dt != "" ? " (" dt ")" : "")))
			out("- **Note:** " d(f[8]))
			out("- **Applied:** " d(f[9]))
		}
	}' "$1"
}

# write <model file>: render it over the list
write() {
	local tmp="$list.tmp.$$"
	render "$1" "$(dl_crlf "$list")" "$(dl_bom "$list")" >"$tmp" || { rm -f "$tmp"; die "could not write $list"; }
	dl_put "$list" "$tmp"
}
qrec() { awk -F'\t' -v id="$2" '$1 == "Q" && $2 == id { print; exit }' "$1"; }
field() { printf '%s\n' "$1" | awk -F'\t' -v n="$2" '{ print $n }'; }
state_of() { if [ -z "$1" ]; then echo open; elif [ -z "$2" ]; then echo apply; else echo done; fi; }

# ---- arguments ----
cmd=${1:-}; [ $# -gt 0 ] && shift
tsv=0; note=""; title=""; forwhat=""; feature=""; args=()
while [ $# -gt 0 ]; do
	case $1 in
	--tsv) tsv=1 ;;
	--note) [ $# -ge 2 ] || { usage; exit 2; }; note=$2; shift ;;
	--title) [ $# -ge 2 ] || { usage; exit 2; }; title=$2; shift ;;
	--for) [ $# -ge 2 ] || { usage; exit 2; }; forwhat=$2; shift ;;
	--feature) [ $# -ge 2 ] || { usage; exit 2; }; feature=$2; shift ;;
	-h | --help) usage; exit 0 ;;
	*) args+=("$1") ;;
	esac
	shift
done
set -- "${args[@]+"${args[@]}"}"
case $cmd in
init | add | list | status | check) [ $# -eq 1 ] || { usage; exit 2; } ;;
decide) [ $# -eq 3 ] || { usage; exit 2; } ;;
show) [ $# -eq 2 ] || { usage; exit 2; } ;;
applied) [ $# -ge 2 ] && [ $# -le 3 ] || { usage; exit 2; } ;;
-h | --help) usage; exit 0 ;;
*) usage; exit 2 ;;
esac
list=$1
oneline() { printf '%s' "$1" | tr '\r\n\t' '   ' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print }'; }
note=$(oneline "$note")

if [ "$cmd" = init ]; then
	[ -e "$list" ] && die "the list already exists: $list"
	[ -n "$title" ] || die "init needs --title"
	mkdir -p "$(dirname "$list")" || die "cannot create $(dirname "$list")"
	m="$list.model.$$"
	printf 'H\t%s\t%s\t%s\n' "$(oneline "$title")" "$(oneline "$feature")" "$(oneline "$forwhat")" >"$m"
	render "$m" 0 0 >"$list"; rm -f "$m"
	echo "created $list"; exit 0
fi
[ -f "$list" ] || die "no such list: $list" 2
M="$list.model.$$"
DL_CLEAN='rm -f "$M" "$M.2"'
trap 'eval "$DL_CLEAN"' EXIT

case $cmd in
list)
	model "$list" | awk -F'\t' -v OFS='\t' -v tsv="$tsv" '$1 == "Q" {
		s = ($7 == "") ? "open" : ($9 == "") ? "apply" : "done"
		if (tsv) print $2, s, $7, $4, $3; else printf "%-4s %-6s %-10s %s\n", $2, s, ($7 == "" ? "—" : $7), $3 }' ;;
status)
	model "$list" | awk -F'\t' '$1 == "H" { t = $2; f = $4 } $1 == "Q" { n++; if ($7 == "") o++; else if ($9 == "") a++; else d++ }
		END { printf "total=%d\nopen=%d\napply=%d\ndone=%d\ntitle=%s\nfor=%s\n", n, o, a, d, t, f }' ;;
show)
	model "$list" >"$M"
	r=$(qrec "$M" "$2"); [ -n "$r" ] || die "no question $2 in $list"
	h=$(awk -F'\t' '$1 == "H"' "$M")
	printf '%s\n' "$r" | awk -F'\t' -v OFS='\t' '{ c = $5; gsub(/\001/, " / ", c)
		print "id", $2; print "title", $3; print "ref", $4; print "context", c; print "take", $6
		print "decision", $7; print "note", $8; print "applied", $9 }'
	printf 'state\t%s\n' "$(state_of "$(field "$r" 7)" "$(field "$r" 9)")"
	printf 'list\t%s\nfor\t%s\n' "$(field "$h" 2)" "$(field "$h" 4)"
	awk -F'\t' -v OFS='\t' -v id="$2" '$1 == "O" && $2 == id { print "option", $3, $4, $5, $6, $7 }' "$M" ;;
check)
	model "$list" >"$M"
	bad=$(awk -F'\t' '
		$1 == "H" && $2 == "" { print "the list has no title" }
		$1 == "Q" { if (seen[$2]++) print $2 ": the Q number is used twice"; ids[$2] = 1; dec[$2] = $7; ap[$2] = $9
			if ($3 == "") print $2 ": no title" }
		$1 == "O" { no[$2]++; if ($6 == 1) nr[$2]++; has[$2, $3] = 1; if (k[$2, $3]++) print $2 ": option " $3 " is there twice" }
		END { for (i in ids) {
			if (no[i] < 2) print i ": needs two or more options"
			if (nr[i] > 1) print i ": more than one option is recommended"
			if (dec[i] != "" && !has[i, dec[i]]) print i ": the decision \"" dec[i] "\" is not one of its options"
			if (ap[i] != "" && dec[i] == "") print i ": applied, but not decided" } }' "$M")
	if [ -n "$bad" ]; then printf '%s\n' "$bad" | sort; exit 1; fi
	echo ok ;;
add)
	spec=$(tr -d '\r')
	dl_lock "$list"
	model "$list" >"$M"
	next=$(awk -F'\t' '$1 == "Q" { n = substr($2, 2) + 0; if (n > m) m = n } END { print m + 1 }' "$M")
	# the spec, parsed into Q and O records numbered from $next (problems on lines starting "!")
	printf '%s\n---\n' "$spec" | awk -v OFS='\t' -v n="$next" '
		function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
		function flush(   i) {
			if (!any) return
			id = "Q" n
			if (t == "") print "!", "a question with no title"
			if (no < 2) print "!", (t == "" ? id : t) ": needs two or more options"
			if (nr > 1) print "!", t ": more than one option is recommended"
			print "Q", id, t, ref, ctx, take, "", "", ""
			for (i = 1; i <= no; i++) print "O", id, ok[i], ot[i], od[i], orec[i], onn[i]
			n++; any = 0; t = ""; ref = ""; ctx = ""; take = ""; no = 0; nr = 0; last = ""; split("", seen)
		}
		{ gsub(/\t/, " ") }
		/^---[ \t]*$/ { flush(); next }
		/^  / && last == "context" { ctx = ctx "\001" substr($0, 3); next }
		/^[ \t]*$/ { next }
		{
			p = index($0, ":"); if (!p) { print "!", "not a field: " $0; next }
			k = trim(substr($0, 1, p - 1)); val = trim(substr($0, p + 1)); any = 1; last = k
			if (k == "title") t = val
			else if (k == "ref") ref = val
			else if (k == "context") ctx = val
			else if (k == "take") take = val
			else if (k == "option") {
				m = split(val, c, "|"); for (i = 1; i <= m; i++) c[i] = trim(c[i])
				if (c[1] !~ /^[A-Za-z0-9-]+$/) { print "!", "an option key is letters, digits and -: \"" c[1] "\""; next }
				if (seen[c[1]]++) { print "!", "option " c[1] " is there twice"; next }
				no++; ok[no] = c[1]; ot[no] = c[2]; gsub(/: /, " - ", ot[no]); od[no] = c[3]; orec[no] = 0; onn[no] = 0
				for (i = 4; i <= m; i++) { if (c[i] == "recommended") { orec[no] = 1; nr++ } else if (c[i] == "note") onn[no] = 1 }
				if (ot[no] == "") print "!", "option " c[1] " has no title"
			}
			else print "!", "unknown field: " k
		}' >"$M.2"
	if grep -q '^!' "$M.2"; then grep '^!' "$M.2" | cut -f2 | sed 's/^/questions.sh: /' >&2; exit 1; fi
	added=$(awk -F'\t' '$1 == "Q" { printf "%s ", $2 }' "$M.2")
	[ -n "$added" ] || die "no questions on stdin"
	cat "$M.2" >>"$M"
	write "$M"
	echo "added $added" ;;
decide)
	id=$2; opt=$3
	dl_lock "$list"
	model "$list" >"$M"
	r=$(qrec "$M" "$id"); [ -n "$r" ] || die "no question $id in $list"
	[ -z "$(field "$r" 9)" ] || die "$id has been applied; it can't be decided again"
	o=$(awk -F'\t' -v id="$id" -v k="$opt" '$1 == "O" && $2 == id && $3 == k' "$M")
	[ -n "$o" ] || die "$id has no option $opt (its options: $(awk -F'\t' -v id="$id" '$1 == "O" && $2 == id { printf "%s ", $3 }' "$M"))"
	[ "$(field "$o" 7)" = 1 ] && [ -z "$note" ] && die "$opt needs --note: the person's words"
	Q_ID=$id Q_K=$opt Q_N=$note awk -F'\t' -v OFS='\t' '$1 == "Q" && $2 == ENVIRON["Q_ID"] { $7 = ENVIRON["Q_K"]; $8 = ENVIRON["Q_N"] } { print }' "$M" >"$M.2"
	write "$M.2"
	echo "$id: $opt" ;;
applied)
	id=$2; how=$(oneline "${3:-}")
	dl_lock "$list"
	model "$list" >"$M"
	r=$(qrec "$M" "$id"); [ -n "$r" ] || die "no question $id in $list"
	[ -n "$(field "$r" 7)" ] || die "$id has no decision yet"
	[ -z "$(field "$r" 9)" ] || die "$id is already applied"
	Q_ID=$id Q_A="$(dl_today)${how:+: $how}" awk -F'\t' -v OFS='\t' '$1 == "Q" && $2 == ENVIRON["Q_ID"] { $9 = ENVIRON["Q_A"] } { print }' "$M" >"$M.2"
	write "$M.2"
	echo "$id: applied" ;;
esac
