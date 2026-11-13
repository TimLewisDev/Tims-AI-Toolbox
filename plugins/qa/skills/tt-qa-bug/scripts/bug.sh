#!/usr/bin/env bash
# bug.sh: the only writer of a bug document, for tt-qa-bug (and any tool that
# shows bugs). One file per bug, "BUG-NN - <title>.md" in a bugs folder, always
# laid out the same way: the model gives facts in a spec, this script writes
# the file. Needs bash, awk and mv only; it reads a bug, or every bug, with one
# awk (a process costs about 0.1s on Windows, so the count of them is the cost).
set -u
export LC_ALL=C

usage() {
	cat >&2 <<'EOF'
usage: bug.sh new <folder> <spec>
       bug.sh validate <spec>
       bug.sh edit <folder> <BUG-id> <spec> [--if <hash>]
       bug.sh set <folder> <BUG-id> severity|status|feature|area|source|environment|jira <value> [--if <hash>]
       bug.sh show <folder> <BUG-id> [--tsv]
       bug.sh list <folder> --tsv
       bug.sh check <folder>

new       Write a bug into <folder> (made if missing) and print its ID
          (BUG-NN, one above the highest number in the folder).
validate  Read a spec and exit 0 when "new" would accept it; otherwise print
          why. Writes nothing.
edit      Change the fields the spec gives; the rest is kept.
set       Change one header field. Severity: Critical|Major|Minor|Trivial.
          Status: New|Confirmed|Fixed|Verified|Closed|Wont fix. Jira is a
          ticket key or "none".
show      The bug's file, or with --tsv its record (as one list row plus the
          text sections, tab-separated, \ = \\, tab = \t, newline = \n).
list      One row per bug, tab-separated:
            <id> <title> <severity> <status> <feature> <area> <source> <jira>
            <created> <updated> <hash> <file name>
          <hash> changes whenever the bug does: pass it back with --if to
          refuse a change to a bug that moved since you read it.
check     Exit 0 when every bug is in the template's layout; otherwise print
          "problem: ..." lines.

A spec is a small text file, or - to read it from stdin (a quoted heredoc):
  title: <short title, what is wrong>
  severity: Critical|Major|Minor|Trivial     (default Major)
  feature: <feature under test>
  area: <area of the feature>
  source: <the test it came from, e.g. A2.3>
  environment: <build, platform, device, account ...>
  jira: <KEY>
  summary:
    <one or two sentences, every line indented two spaces>
  steps:
    1. <step>
    2. <step>
  expected:
    <what should happen>
  actual:
    <what happens>
  evidence:
    <links, file paths, log lines>
new needs title, summary, steps, expected and actual. Steps are numbered by
this script (a leading "1." or "-" is dropped). A one-line value may sit after
the colon instead of on indented lines.

Exit: 0 done, 1 refused input (a bad spec, an unknown bug), 2 usage error or a
missing file, 3 the bug changed since it was read (--if).
EOF
	exit 2
}

die() {
	echo "bug.sh: $1" >&2
	exit "${2:-1}"
}

SEVERITIES=" Critical Major Minor Trivial "
FIELDS=" title severity status feature area source environment jira summary steps expected actual evidence "

declare -A V # the bug being written, one entry per field

# --- reading: one awk per call --------------------------------------------

# The awk that reads bug files. -v out=list|show|load. A file's hash is a
# polynomial over its bytes, so it needs no cksum process.
READER='
BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
function esc(s) { gsub(/\\/, "\\\\", s); gsub(/\t/, "\\t", s); gsub(/\n/, "\\n", s); return s }
function trim(s) { sub(/^\n+/, "", s); sub(/\n+$/, "", s); return s }
function flush(   k, row, US) {
	if (!have) return
	for (k in sec) sec[k] = trim(sec[k])
	for (k in hd) if (hd[k] == "none") hd[k] = ""
	row = id "\t" esc(title) "\t" hd["Severity"] "\t" hd["Status"] "\t" esc(hd["Feature"]) "\t" esc(hd["Area"]) "\t" esc(hd["Source test"]) "\t" (hd["Jira"] == "" ? "none" : hd["Jira"]) "\t" hd["Created"] "\t" hd["Updated"] "\t" h "\t" base
	if (out == "list") print row
	else if (out == "show") print row "\t" esc(sec["Summary"]) "\t" esc(sec["Steps to reproduce"]) "\t" esc(sec["Expected result"]) "\t" esc(sec["Actual result"]) "\t" esc(hd["Environment"]) "\t" esc(sec["Evidence"] == "none" ? "" : sec["Evidence"])
	else {
		US = sprintf("%c", 31)
		printf "%s", id US title US hd["Severity"] US hd["Status"] US hd["Feature"] US hd["Area"] US hd["Source test"] US hd["Environment"] US hd["Jira"] US hd["Created"] US hd["Updated"] US sec["Summary"] US sec["Steps to reproduce"] US sec["Expected result"] US sec["Actual result"] US (sec["Evidence"] == "none" ? "" : sec["Evidence"]) US h
	}
	have = 0
}
FNR == 1 {
	flush(); delete hd; delete sec; h = 0; cur = ""; have = 0; id = ""; title = ""
	base = FILENAME; sub(/.*\//, "", base)
}
{
	line = $0; sub(/\r$/, "", line)
	n = length($0)
	for (i = 1; i <= n; i++) h = (h * 31 + ord[substr($0, i, 1)]) % 2147483647
	h = (h * 31 + 10) % 2147483647
	if (FNR == 1) {
		if (match(line, /^# BUG-[0-9]+: /)) { id = substr(line, 3, RLENGTH - 4); title = substr(line, RLENGTH + 1); have = 1 }
		else { id = "?"; title = line; have = 1 }
		next
	}
	if (line ~ /^## /) { cur = substr(line, 4); next }
	if (cur == "" && match(line, /^- \*\*[^:]+:\*\* /)) {
		key = substr(line, 5); sub(/:\*\*.*/, "", key)
		hd[key] = substr(line, RLENGTH + 1)
		next
	}
	if (cur != "") sec[cur] = sec[cur] "\n" line
}
END { flush() }
'

# load <file>: fills V (and BUG_ID, BUG_HASH) from an existing bug: one awk.
load() {
	local all id
	local IFS=$'\x1f'
	all=$(awk -v out=load "$READER" "$1")
	[ -n "$all" ] || die "$1: empty"
	read -r -d '' id V[title] V[severity] V[status] V[feature] V[area] V[source] V[environment] V[jira] V[created] V[updated] \
		V[summary] V[steps] V[expected] V[actual] V[evidence] BUG_HASH <<<"$all"
	[ "${id#BUG-}" != "$id" ] || die "$1: no \"# BUG-NN: title\" line"
	BUG_ID=$id
	BUG_HASH=${BUG_HASH%$'\n'}
}

# --- specs ----------------------------------------------------------------

# parse_spec <file|-> <array name>: fills the array from a spec.
parse_spec() {
	local src=$1 line key val cur="" n=0
	local -n tgt=$2
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
			[[ $FIELDS == *" $key "* ]] || die "spec line $n: unknown field \"$key\""
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

one_line() { # one_line <field>: refuse text that would break the header
	case ${V[$1]:-} in *$'\n'*) die "$1 must be one line" ;; esac
}

# numbered <text>: the steps, one per line, numbered 1., 2., ... (no forks)
numbered() {
	local line i=0
	while IFS= read -r line; do
		[ -n "${line//[[:space:]]/}" ] || continue
		if [[ $line =~ ^[[:space:]]*([0-9]+[.\)]|[-*])[[:space:]]+(.*)$ ]]; then line=${BASH_REMATCH[2]}; fi
		i=$((i + 1))
		printf '%d. %s\n' "$i" "$line"
	done <<<"$1"
}

orelse() { printf '%s' "${1:-$2}"; }

# render <id>: the whole document from V.
render() {
	local id=$1
	printf '# %s: %s\n\n' "$id" "${V[title]}"
	printf -- '- **Severity:** %s\n' "${V[severity]}"
	printf -- '- **Status:** %s\n' "${V[status]}"
	printf -- '- **Feature:** %s\n' "$(orelse "${V[feature]:-}" none)"
	printf -- '- **Area:** %s\n' "$(orelse "${V[area]:-}" none)"
	printf -- '- **Source test:** %s\n' "$(orelse "${V[source]:-}" none)"
	printf -- '- **Environment:** %s\n' "$(orelse "${V[environment]:-}" none)"
	printf -- '- **Jira:** %s\n' "$(orelse "${V[jira]:-}" none)"
	printf -- '- **Created:** %s\n- **Updated:** %s\n\n' "${V[created]}" "${V[updated]}"
	printf '## Summary\n\n%s\n\n' "${V[summary]}"
	printf '## Steps to reproduce\n\n%s\n\n' "$(numbered "${V[steps]}")"
	printf '## Expected result\n\n%s\n\n' "${V[expected]}"
	printf '## Actual result\n\n%s\n\n' "${V[actual]}"
	printf '## Evidence\n\n%s\n' "$(orelse "${V[evidence]:-}" none)"
}

validate() {
	local k
	for k in title summary steps expected actual; do
		[ -n "${V[$k]:-}" ] || die "$k is required"
	done
	for k in title severity status feature area source environment jira; do one_line "$k"; done
	[[ $SEVERITIES == *" ${V[severity]} "* ]] || die "severity must be one of:$SEVERITIES"
	case ${V[status]} in New | Confirmed | Fixed | Verified | Closed | "Wont fix") ;; *) die "status must be one of: New, Confirmed, Fixed, Verified, Closed, Wont fix" ;; esac
	case ${V[title]} in *[/\\:\*\?\"\<\>\|]*) die "title can't hold / \\ : * ? \" < > |" ;; esac
	[ ${#V[title]} -le 120 ] || die "title is over 120 characters"
	for k in summary steps expected actual evidence; do
		case $'\n'${V[$k]:-} in *$'\n#'*) die "$k can't have a line starting with #" ;; esac
	done
}

write_file() { # write_file <path> <id>: render to a temp file then move it in
	local tmp="$1.tmp.$$"
	render "$2" >"$tmp" || { rm -f "$tmp"; die "could not write $1"; }
	mv -f "$tmp" "$1"
}

file_name() { printf '%s - %s.md' "$1" "${V[title]}"; }

# find_bug <folder> <id>: sets BUG_PATH, or dies.
find_bug() {
	local f
	for f in "$1/$2 - "*.md; do
		[ -f "$f" ] && { BUG_PATH=$f; return 0; }
	done
	die "no such bug: $2"
}

next_number() { # one above the highest number in the file names (no forks)
	local f n max=0
	for f in "$1"/BUG-*.md; do
		[ -f "$f" ] || continue
		n=${f##*/BUG-}
		n=${n%% - *}
		[[ $n =~ ^[0-9]+$ ]] && [ "$((10#$n))" -gt "$max" ] && max=$((10#$n))
	done
	echo $((max + 1))
}

cmd_new() {
	[ $# -eq 2 ] || usage
	local dir=$1 num id path tries=0
	parse_spec "$2" V
	V[severity]=${V[severity]:-Major}
	V[status]=New
	V[created]=$(date +%Y-%m-%d)
	V[updated]=${V[created]}
	validate
	mkdir -p "$dir" || die "can't make $dir" 2
	while :; do
		num=$(next_number "$dir")
		id=$(printf 'BUG-%02d' "$num")
		path="$dir/$(file_name "$id")"
		# the empty file claims the number; a second writer fails here
		if (set -C; : >"$path") 2>/dev/null; then break; fi
		tries=$((tries + 1))
		[ $tries -lt 10 ] || die "can't claim a bug number in $dir" 2
	done
	write_file "$path" "$id"
	echo "$id"
}

cmd_validate() {
	[ $# -eq 1 ] || usage
	parse_spec "$1" V
	V[severity]=${V[severity]:-Major}
	V[status]=New
	validate
	echo ok
}

take_if() { # take_if <args...>: sets IF_HASH and REST from args
	IF_HASH=""
	REST=()
	while [ $# -gt 0 ]; do
		if [ "$1" = "--if" ]; then
			[ $# -ge 2 ] || usage
			IF_HASH=$2
			shift 2
		else
			REST+=("$1")
			shift
		fi
	done
}

guard() { # guard <hash read now>: exit 3 when --if doesn't match
	[ -z "$IF_HASH" ] || [ "$1" = "$IF_HASH" ] || die "the bug changed since it was read" 3
}

cmd_edit() {
	take_if "$@"
	[ ${#REST[@]} -eq 3 ] || usage
	local dir=${REST[0]} id=${REST[1]} spec=${REST[2]} path old k
	local -A S=()
	parse_spec "$spec" S
	find_bug "$dir" "$id"
	path=$BUG_PATH
	load "$path"
	guard "$BUG_HASH"
	for k in "${!S[@]}"; do V[$k]=${S[$k]}; done
	V[updated]=$(date +%Y-%m-%d)
	validate
	old=$path
	path="$dir/$(file_name "$id")"
	write_file "$path" "$id"
	[ "$old" = "$path" ] || rm -f "$old"
	echo "$id"
}

cmd_set() {
	take_if "$@"
	[ ${#REST[@]} -ge 4 ] || usage
	local dir=${REST[0]} id=${REST[1]} field=${REST[2]} value="${REST[*]:3}" path
	[[ " severity status feature area source environment jira " == *" $field "* ]] || die "can't set \"$field\" (use edit for text)"
	find_bug "$dir" "$id"
	path=$BUG_PATH
	load "$path"
	guard "$BUG_HASH"
	V[$field]=$value
	V[updated]=$(date +%Y-%m-%d)
	validate
	write_file "$path" "$id"
	echo "$id"
}

cmd_list() {
	[ $# -eq 2 ] && [ "$2" = "--tsv" ] || usage
	[ -d "$1" ] || return 0
	local files=("$1"/BUG-*.md)
	[ -f "${files[0]}" ] || return 0
	awk -v out=list "$READER" "${files[@]}"
}

cmd_show() {
	[ $# -ge 2 ] || usage
	find_bug "$1" "$2"
	if [ "${3:-}" = "--tsv" ]; then
		awk -v out=show "$READER" "$BUG_PATH"
	else
		cat "$BUG_PATH"
	fi
}

cmd_check() {
	[ $# -eq 1 ] || usage
	[ -d "$1" ] || return 0
	local files=("$1"/BUG-*.md) bad=0 report
	[ -f "${files[0]}" ] || return 0
	report=$(awk -v out=show "$READER" "${files[@]}" | awk -F'\t' '
		{ b = $12
		  if ($1 !~ /^BUG-/) print "problem: " b ": the first line must be \"# BUG-NN: title\""
		  if ($2 == "") print "problem: " b ": no title"
		  if ($3 == "") print "problem: " b ": no Severity line"
		  if ($4 == "") print "problem: " b ": no Status line"
		  if ($9 == "") print "problem: " b ": no Created line"
		  if ($13 == "") print "problem: " b ": empty \"Summary\" section"
		  if ($14 == "") print "problem: " b ": empty \"Steps to reproduce\" section"
		  if ($15 == "") print "problem: " b ": empty \"Expected result\" section"
		  if ($16 == "") print "problem: " b ": empty \"Actual result\" section" }')
	[ -z "$report" ] || { echo "$report"; bad=1; }
	return $bad
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case $cmd in
new) cmd_new "$@" ;;
validate) cmd_validate "$@" ;;
edit) cmd_edit "$@" ;;
set) cmd_set "$@" ;;
show) cmd_show "$@" ;;
list) cmd_list "$@" ;;
check) cmd_check "$@" ;;
-h | --help | help) usage ;;
*) usage ;;
esac
