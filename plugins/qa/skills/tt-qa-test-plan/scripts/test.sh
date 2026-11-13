#!/usr/bin/env bash
# test.sh: the only writer of a Test Plan document and its results, for
# tt-qa-test-plan, tt-qa-test-run (and any tool that shows them). The plan
# lists areas to validate, each with test items (how to test, what to expect);
# results go in a separate append-only file beside it, so the plan text stays
# stable while testing goes on. Needs bash, awk, sed and cksum only.
set -u
export LC_ALL=C

usage() {
	cat >&2 <<'EOF'
usage: test.sh init <plan.md> --feature <name> [--title <text>]
       test.sh area add <plan> <spec>
       test.sh item add <plan> <A-id> <spec>
       test.sh edit <plan> <A-id|A.n-id> <spec>
       test.sh remove <plan> <A-id|A.n-id> [--force]
       test.sh status <plan> Draft|Ready
       test.sh check <plan> <A.n-id> pass|fail|blocked|skip|reset [--note <text>] [--bug <BUG-id>]
       test.sh list <plan> --tsv
       test.sh summary <plan> --tsv
       test.sh verify <plan>

init      Write a new plan: the header and no areas. <plan.md> is the plan;
          its results go to "<plan without .md> - Results.tsv".
area add  Add an area to validate and print its ID (A1, A2 ...).
item add  Add a test item to an area and print its ID (A1.1, A1.2 ...).
          IDs are never reused, even after remove.
edit      Change the fields the spec gives (an area has title and why; an
          item has title, how and expect). The rest is kept.
remove    Remove an area (and its items) or one item. Refused when it has
          results, unless --force; the results rows stay in the results file.
status    Set the header's Status line.
check     Record a result for an item: pass, fail, blocked, skip, or reset
          (back to untested). --note and --bug are kept with the row.
list      The plan with each item's latest result, tab-separated:
            meta  feature|status|updated  <value>
            area  <id> <title> <why>
            item  <id> <area id> <title> <how> <expect> <result> <date> <bug> <note>
          In every field \ is \\, a tab \t and a newline \n. <result> is
          untested until an item has one.
summary   Counts, tab-separated:
            total <items> <pass> <fail> <blocked> <skip> <untested>
            area  <id> <title> <items> <pass> <fail> <blocked> <skip> <untested>
verify    Exit 0 when the plan is in the template's layout; otherwise print
          "problem: ..." lines.

A spec is a small text file, or - to read it from stdin (a quoted heredoc):
  title: <short name>
  why:                          (area only: why this area needs testing)
    <text, every line indented two spaces>
  how:                          (item only: the steps, one per line)
    1. <step>
    2. <step>
  expect:                       (item only: what a pass looks like)
    <text>
A one-line value may sit after the colon. Steps are numbered by this script.
An area needs a title; an item needs title, how and expect.

Exit: 0 done, 1 refused input (a bad spec, an unknown ID, an item with
results), 2 usage error or a missing file.
EOF
	exit 2
}

die() {
	echo "test.sh: $1" >&2
	exit "${2:-1}"
}

today() { date +%Y-%m-%d; }

in_list() {
	local w
	for w in $2; do [ "$w" = "$1" ] && return 0; done
	return 1
}

# parse_spec <file|-> <array name> <allowed fields>
parse_spec() {
	local src=$1 line key val cur="" n=0
	local -n tgt=$2
	local allowed=$3
	if [ "$src" != "-" ]; then
		[ -r "$src" ] || die "no such spec file: $src" 2
		exec 3<"$src"
	else
		exec 3<&0
	fi
	while IFS= read -r line <&3 || [ -n "$line" ]; do
		line=${line%$'\r'}
		n=$((n + 1))
		if [[ $line =~ ^([a-z_]+):[[:space:]]*(.*)$ ]]; then
			key=${BASH_REMATCH[1]}
			val=${BASH_REMATCH[2]}
			in_list "$key" "$allowed" || die "spec line $n: unknown field \"$key\" (allowed: $allowed)"
			tgt[$key]=$val
			cur=$key
		elif [[ $line == "  "* ]]; then
			[ -n "$cur" ] || die "spec line $n: indented text before any field"
			tgt[$cur]+="${tgt[$cur]:+$'\n'}${line:2}"
		elif [[ -z ${line//[[:space:]]/} ]]; then
			:
		else
			die "spec line $n: cannot read \"$line\""
		fi
	done
	exec 3<&-
}

# text_ok <field name> <text>: text can't break the document's headings.
text_ok() {
	case $2 in
	*$'\n#'* | '#'* | *$'\n**How to test**'* | *$'\n**Expected**'*) die "$1 can't have a line starting with # or a bold section marker" ;;
	esac
}

one_line_ok() {
	case $2 in *$'\n'*) die "$1 must be one line" ;; esac
	case $2 in *[\|]*) : ;; esac
}

numbered() {
	local line i=0
	while IFS= read -r line; do
		[ -n "${line//[[:space:]]/}" ] || continue
		line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*([0-9]+[.)]|[-*])[[:space:]]+//')
		i=$((i + 1))
		printf '%d. %s\n' "$i" "$line"
	done <<<"$1"
}

results_of() { printf '%s - Results.tsv' "${1%.md}"; }

need_plan() { [ -f "$1" ] || die "no such plan: $1" 2; }

# The one awk program that reads a plan (and its results) into records.
# -v mode=list|summary. Fields come out already escaped.
READER='
function esc(s) { gsub(/\\/, "\\\\", s); gsub(/\t/, "\\t", s); return s }
function trimnl(s) { sub(/^\n+/, "", s); sub(/\n+$/, "", s); return s }
function flat(s) { s = trimnl(s); gsub(/\n/, "\\n", s); return s }
function flush() {
	if (kind == "area") { aid[++na] = id; atitle[id] = title; awhy[id] = flat(why) }
	else if (kind == "item") {
		iid[++ni] = id; iarea[id] = area; ititle[id] = title; ihow[id] = flat(how); iexp[id] = flat(expv)
	}
	kind = ""
}
FILENAME == ARGV[1] {
	n = split($0, f, "\t")
	if (n >= 3) { res[f[2]] = f[3]; rdate[f[2]] = f[1]; rbug[f[2]] = f[4]; rnote[f[2]] = f[5] }
	next
}
{ sub(/\r$/, "") }
/^# / && !title0 { title0 = 1; next }
/^- \*\*Feature:\*\* / { sub(/^- \*\*Feature:\*\* /, ""); meta_feature = $0; next }
/^- \*\*Status:\*\* /  { sub(/^- \*\*Status:\*\* /, ""); meta_status = $0; next }
/^- \*\*Updated:\*\* / { sub(/^- \*\*Updated:\*\* /, ""); meta_updated = $0; next }
/^## [A-Z][0-9]+ - / {
	flush(); kind = "area"; line = $0; sub(/^## /, "", line)
	id = line; sub(/ - .*/, "", id); title = line; sub(/^[^ ]+ - /, "", title)
	why = ""; mode = "why"; next
}
/^### [A-Z][0-9]+\.[0-9]+ - / {
	flush(); kind = "item"; line = $0; sub(/^### /, "", line)
	id = line; sub(/ - .*/, "", id); title = line; sub(/^[^ ]+ - /, "", title)
	area = id; sub(/\..*/, "", area); how = ""; expv = ""; mode = ""; next
}
kind == "item" && $0 == "**How to test**" { mode = "how"; next }
kind == "item" && $0 == "**Expected**" { mode = "expv"; next }
kind == "area" && mode == "why" { why = why "\n" $0; next }
kind == "item" && mode == "how" { how = how "\n" $0; next }
kind == "item" && mode == "expv" { expv = expv "\n" $0; next }
END {
	flush()
	for (i = 1; i <= ni; i++) {
		id = iid[i]; r = (id in res) ? res[id] : "untested"; if (r == "reset") r = "untested"
		a = iarea[id]; tot[a]++; T++
		cnt[a, r]++; C[r]++
	}
	if (out == "list") {
		print "meta\tfeature\t" esc(meta_feature); print "meta\tstatus\t" esc(meta_status); print "meta\tupdated\t" esc(meta_updated)
		for (i = 1; i <= na; i++) {
			a = aid[i]; print "area\t" a "\t" esc(atitle[a]) "\t" awhy[a]
			for (j = 1; j <= ni; j++) {
				id = iid[j]; if (iarea[id] != a) continue
				r = (id in res) ? res[id] : "untested"; if (r == "reset") r = "untested"
				print "item\t" id "\t" a "\t" esc(ititle[id]) "\t" ihow[id] "\t" iexp[id] "\t" r "\t" ((id in res && r != "untested") ? rdate[id] : "") "\t" ((r != "untested") ? rbug[id] : "") "\t" ((r != "untested") ? esc(rnote[id]) : "")
			}
		}
	} else {
		print "total\t" T + 0 "\t" C["pass"] + 0 "\t" C["fail"] + 0 "\t" C["blocked"] + 0 "\t" C["skip"] + 0 "\t" C["untested"] + 0
		for (i = 1; i <= na; i++) {
			a = aid[i]
			print "area\t" a "\t" esc(atitle[a]) "\t" tot[a] + 0 "\t" cnt[a, "pass"] + 0 "\t" cnt[a, "fail"] + 0 "\t" cnt[a, "blocked"] + 0 "\t" cnt[a, "skip"] + 0 "\t" cnt[a, "untested"] + 0
		}
	}
}
'

read_plan() { # read_plan <plan> list|summary
	local res
	res=$(results_of "$1")
	[ -f "$res" ] || : >"$res.empty.$$"
	awk -v out="$2" "$READER" "$( [ -f "$res" ] && printf '%s' "$res" || printf '%s' "$res.empty.$$")" "$1"
	rm -f "$res.empty.$$"
}

touch_updated() { # touch_updated <plan>
	sed -i "s/^- \*\*Updated:\*\* .*/- **Updated:** $(today)/" "$1"
}

tidy_file() { # one blank line between blocks, one newline at the end
	local tmp="$1.tmp.$$"
	awk 'NF { for (; b > 0; b--) print ""; print; started = 1; next } started { b = 1 }' "$1" >"$tmp" && mv -f "$tmp" "$1"
}

cmd_init() {
	[ $# -ge 3 ] || usage
	local plan=$1 feature="" title=""
	shift
	while [ $# -gt 0 ]; do
		case $1 in
		--feature) feature=${2:-}; shift 2 ;;
		--title) title=${2:-}; shift 2 ;;
		*) usage ;;
		esac
	done
	[ -n "$feature" ] || usage
	[ ! -e "$plan" ] || die "$plan exists already"
	mkdir -p "$(dirname "$plan")" || die "can't make the folder" 2
	{
		printf '# %s - Test Plan\n\n' "${title:-$feature}"
		printf -- '- **Feature:** %s\n- **Status:** Draft\n- **Updated:** %s\n' "$feature" "$(today)"
	} >"$plan"
	echo "$plan"
}

render_area_head() { # render_area_head <id> <title> <why>
	printf '## %s - %s\n\n' "$1" "$2"
	[ -z "$3" ] || printf '%s\n\n' "$3"
}

render_item() { # render_item <id> <title> <how> <expect>
	printf '### %s - %s\n\n**How to test**\n\n%s\n\n**Expected**\n\n%s\n\n' "$1" "$2" "$(numbered "$3")" "$4"
}

# splice <plan> <kind> <id> <newfile>: kind area-head|area-full|item. An empty
# newfile removes the block.
splice() {
	local tmp="$1.tmp.$$"
	awk -v kind="$2" -v id="$3" -v newfile="$4" '
		{ line = $0; sub(/\r$/, "", line) }
		function startsblock(l) { return l ~ /^## / || l ~ /^### / }
		skip {
			if (kind == "area-full" && l_is_area(line)) skip = 0
			else if (kind != "area-full" && startsblock(line)) skip = 0
		}
		function l_is_area(l) { return l ~ /^## / }
		!skip && ((kind == "item" && index(line, "### " id " - ") == 1) || (kind != "item" && index(line, "## " id " - ") == 1)) {
			if (newfile != "") { while ((getline l < newfile) > 0) print l; close(newfile) }
			skip = 1
		}
		!skip { print $0 }
	' "$1" >"$tmp" && mv -f "$tmp" "$1"
	tidy_file "$1"
}

# insert_item <plan> <area id> <newfile>: before the next area, or at the end.
insert_item() {
	local tmp="$1.tmp.$$"
	awk -v area="$2" -v newfile="$3" '
		function put(  l) { print ""; while ((getline l < newfile) > 0) print l; close(newfile); done = 1 }
		{ line = $0; sub(/\r$/, "", line) }
		line ~ /^## / {
			if (inarea && !done) put()
			inarea = (index(line, "## " area " - ") == 1)
		}
		{ print $0 }
		END { if (inarea && !done) put() }
	' "$1" >"$tmp" && mv -f "$tmp" "$1"
	tidy_file "$1"
}

area_exists() { grep -q "^## $2 - " "$1"; }
item_exists() { grep -q "^### $2 - " "$1"; }

cmd_area() {
	[ $# -eq 3 ] && [ "$1" = add ] || usage
	local plan=$2 num id nf="$2.new.$$"
	need_plan "$plan"
	local -A S=()
	parse_spec "$3" S "title why"
	[ -n "${S[title]:-}" ] || die "title is required"
	one_line_ok title "${S[title]}"
	text_ok why "${S[why]:-}"
	num=$({
		grep -o '^## A[0-9]*' "$plan" | sed 's/^## A//'
		cut -f2 "$(results_of "$plan")" 2>/dev/null | grep -o '^A[0-9]*' | sed 's/^A//'
	} | sort -n | tail -n 1)
	num=$(( ${num:-0} + 1 ))
	id="A$num"
	render_area_head "$id" "${S[title]}" "${S[why]:-}" >"$nf"
	{ [ -s "$plan" ] && printf '\n'; cat "$nf"; } >>"$plan"
	rm -f "$nf"
	tidy_file "$plan"
	touch_updated "$plan"
	echo "$id"
}

cmd_item() {
	[ $# -eq 4 ] && [ "$1" = add ] || usage
	local plan=$2 area=$3 num id nf="$2.new.$$"
	need_plan "$plan"
	area_exists "$plan" "$area" || die "no such area: $area"
	local -A S=()
	parse_spec "$4" S "title how expect"
	local k
	for k in title how expect; do [ -n "${S[$k]:-}" ] || die "$k is required"; done
	one_line_ok title "${S[title]}"
	text_ok how "${S[how]}"
	text_ok expect "${S[expect]}"
	num=$({
		grep -o "^### $area\.[0-9]*" "$plan"
		cut -f2 "$(results_of "$plan")" 2>/dev/null | grep -o "^$area\.[0-9]*"
	} | sed "s/^[#]* *$area\.//" | sort -n | tail -n 1)
	num=$(( ${num:-0} + 1 ))
	id="$area.$num"
	render_item "$id" "${S[title]}" "${S[how]}" "${S[expect]}" >"$nf"
	insert_item "$plan" "$area" "$nf"
	rm -f "$nf"
	touch_updated "$plan"
	echo "$id"
}

get_field() { # get_field <plan> <id> <column index in the list record>
	read_plan "$1" list | awk -F'\t' -v id="$2" -v col="$3" '($1 == "item" || $1 == "area") && $2 == id { print $col }'
}

unesc() { printf '%s' "$1" | sed -e 's/\\n/\n/g' -e 's/\\t/\t/g' -e 's/\\\\/\\/g'; }

cmd_edit() {
	[ $# -eq 3 ] || usage
	local plan=$1 id=$2 nf="$1.new.$$" t h e w
	need_plan "$plan"
	local -A S=()
	if [[ $id == *.* ]]; then
		item_exists "$plan" "$id" || die "no such item: $id"
		parse_spec "$3" S "title how expect"
		t=${S[title]:-$(unesc "$(get_field "$plan" "$id" 4)")}
		h=${S[how]:-$(unesc "$(get_field "$plan" "$id" 5)")}
		e=${S[expect]:-$(unesc "$(get_field "$plan" "$id" 6)")}
		one_line_ok title "$t"
		text_ok how "$h"
		text_ok expect "$e"
		render_item "$id" "$t" "$h" "$e" >"$nf"
		splice "$plan" item "$id" "$nf"
	else
		area_exists "$plan" "$id" || die "no such area: $id"
		parse_spec "$3" S "title why"
		t=${S[title]:-$(unesc "$(get_field "$plan" "$id" 3)")}
		w=${S[why]:-$(unesc "$(get_field "$plan" "$id" 4)")}
		one_line_ok title "$t"
		text_ok why "$w"
		render_area_head "$id" "$t" "$w" >"$nf"
		splice "$plan" area-head "$id" "$nf"
	fi
	rm -f "$nf"
	touch_updated "$plan"
	echo "$id"
}

has_results() { # has_results <plan> <id or area id>: some item there is not back to untested
	local res
	res=$(results_of "$1")
	[ -f "$res" ] || return 1
	awk -F'	' -v id="$2" '
		$2 == id || index($2, id ".") == 1 { last[$2] = $3 }
		END { for (k in last) if (last[k] != "reset") found = 1; exit found ? 0 : 1 }' "$res"
}

cmd_remove() {
	[ $# -ge 2 ] || usage
	local plan=$1 id=$2 force=0
	[ "${3:-}" = "--force" ] && force=1
	need_plan "$plan"
	if [[ $id == *.* ]]; then
		item_exists "$plan" "$id" || die "no such item: $id"
		[ $force -eq 1 ] || ! has_results "$plan" "$id" || die "$id has results (use --force)"
		splice "$plan" item "$id" ""
	else
		area_exists "$plan" "$id" || die "no such area: $id"
		[ $force -eq 1 ] || ! has_results "$plan" "$id" || die "$id has items with results (use --force)"
		splice "$plan" area-full "$id" ""
	fi
	touch_updated "$plan"
	echo "$id"
}

cmd_status() {
	[ $# -eq 2 ] || usage
	need_plan "$1"
	case $2 in Draft | Ready) ;; *) die "status must be Draft or Ready" ;; esac
	sed -i "s/^- \*\*Status:\*\* .*/- **Status:** $2/" "$1"
	touch_updated "$1"
	echo "$2"
}

cmd_check() {
	[ $# -ge 3 ] || usage
	local plan=$1 id=$2 result=$3 note="" bug="" res
	shift 3
	while [ $# -gt 0 ]; do
		case $1 in
		--note) note=${2:-}; shift 2 ;;
		--bug) bug=${2:-}; shift 2 ;;
		*) usage ;;
		esac
	done
	need_plan "$plan"
	item_exists "$plan" "$id" || die "no such item: $id"
	case $result in pass | fail | blocked | skip | reset) ;; *) die "result must be pass, fail, blocked, skip or reset" ;; esac
	case $note$bug in *$'\n'* | *$'\t'*) die "note and bug must be one line without tabs" ;; esac
	res=$(results_of "$plan")
	printf '%s\t%s\t%s\t%s\t%s\n' "$(today)" "$id" "$result" "$bug" "$note" >>"$res"
	touch_updated "$plan"
	echo "$id $result"
}

cmd_verify() {
	[ $# -eq 1 ] || usage
	need_plan "$1"
	local bad=0 line
	sed -n 1p "$1" | tr -d '\r' | grep -q '^# .* - Test Plan$' || { echo "problem: the first line must be \"# <name> - Test Plan\""; bad=1; }
	for line in Feature Status Updated; do
		grep -q "^- \*\*$line:\*\* ." "$1" || { echo "problem: no $line line"; bad=1; }
	done
	line=$(read_plan "$1" list | awk -F'\t' '
		$1 == "area" { a = $2; items[a] = 0 }
		$1 == "item" { items[$3]++; if ($5 == "" || $6 == "") print "problem: " $2 " needs How to test and Expected" }
		END { for (a in items) if (items[a] == 0) print "problem: area " a " has no items" }
	')
	[ -z "$line" ] || { echo "$line"; bad=1; }
	return $bad
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case $cmd in
init) cmd_init "$@" ;;
area) cmd_area "$@" ;;
item) cmd_item "$@" ;;
edit) cmd_edit "$@" ;;
remove) cmd_remove "$@" ;;
status) cmd_status "$@" ;;
check) cmd_check "$@" ;;
list)
	[ $# -eq 2 ] && [ "$2" = "--tsv" ] || usage
	need_plan "$1"
	read_plan "$1" list
	;;
summary)
	[ $# -eq 2 ] && [ "$2" = "--tsv" ] || usage
	need_plan "$1"
	read_plan "$1" summary
	;;
verify) cmd_verify "$@" ;;
-h | --help | help) usage ;;
*) usage ;;
esac
