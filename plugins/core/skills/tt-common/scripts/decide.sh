#!/usr/bin/env bash
# decide.sh: one way in to the decisions a feature folder is waiting on, for the
# skills and for any front end. It finds the script-owned decision documents in a
# folder, shows an item with the options it can take, and records a choice
# through the document's own writer. Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: decide.sh mode
       decide.sh pending [--tsv] <folder>
       decide.sh status <folder>
       decide.sh show <doc> <id>
       decide.sh set <doc> <id> <option> [--note <text>]

mode     Where pre-written questions are answered: "chat" (the session asks
         them, one at a time) or "elsewhere" (the session records them and
         ends its turn; the person answers outside the chat, then says to
         continue). Read from TT_DECIDE; chat when unset.
pending  Every item in the folder that is waiting: open (no decision yet) or
         apply (decided, waiting for the session to carry it out). --tsv prints
           doc kind id state group severity title
         doc is the document's path; kind is "challenge" (group: its stage;
         severity: blocking, significant or minor) or "proposal" (group: its
         type; severity: blocking for a Blocking decision, else its status) or
         "question" (a question list's: group: the list's title; severity: its
         ref, such as "WU3 check 2", or empty).
status   open=, apply= (counts across the folder) and docs= (how many
         documents hold items).
show     One item as "<field><TAB><value>" lines, then its options as
         option<TAB>key<TAB>title<TAB>detail<TAB>recommended 0|1<TAB>needs-note 0|1
set      Records the choice through the document's writer.

Documents read: "<Prefix> - Challenges.md" (challenges.sh),
"<Prefix> - Tech Proposals.md" (proposals.sh) and the question lists in
".tt/<Prefix> - Questions/" (questions.sh).
Exit: 0 ok, 1 refused, 2 usage error or unknown document.
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
me=decide.sh
die() { echo "$me: $*" >&2; exit "${2:-1}"; }

# writer_of <doc>: the script that owns it, or nothing
writer_of() {
	case $(basename "$1") in
	*" - Challenges.md") echo "$here/challenges.sh" ;;
	*" - Tech Proposals.md") echo "$here/proposals.sh" ;;
	*.md) case $1 in */.tt/*" - Questions/"*) echo "$here/questions.sh" ;; esac ;;
	esac
}

cmd=${1:-}; [ $# -gt 0 ] && shift
tsv=0; note=""; hasnote=0; args=()
while [ $# -gt 0 ]; do
	case $1 in
	--tsv) tsv=1 ;;
	--note) [ $# -ge 2 ] || { usage; exit 2; }; note=$2; hasnote=1; shift ;;
	-h | --help) usage; exit 0 ;;
	*) args+=("$1") ;;
	esac
	shift
done
set -- "${args[@]+"${args[@]}"}"

case $cmd in
mode)
	[ $# -eq 0 ] || { usage; exit 2; }
	case ${TT_DECIDE:-chat} in
	elsewhere) echo elsewhere ;;
	*) echo chat ;;
	esac ;;
pending | status)
	[ $# -eq 1 ] || { usage; exit 2; }
	dir=${1%/}; [ -n "$dir" ] || dir=/
	[ -d "$dir" ] || die "no such folder: $dir" 2
	rows=""
	for f in "$dir"/*" - Challenges.md"; do
		[ -f "$f" ] || continue
		r=$(bash "$here/challenges.sh" list --tsv "$f" | awk -F'\t' -v OFS='\t' -v doc="$f" '$6 != "done" { print doc, "challenge", $1, $6, $2, $3, $7 }')
		[ -n "$r" ] && rows="$rows$r"$'\n'
	done
	for f in "$dir"/*" - Tech Proposals.md"; do
		[ -f "$f" ] || continue
		# proposals.sh list --tsv: id type status state recommended chosen question
		r=$(bash "$here/proposals.sh" list --tsv "$f" | awk -F'\t' -v OFS='\t' -v doc="$f" '$4 != "done" { print doc, "proposal", $1, $4, $2, ($2 == "Blocking decision" ? "blocking" : tolower($3)), $7 }')
		[ -n "$r" ] && rows="$rows$r"$'\n'
	done
	for f in "$dir"/.tt/*" - Questions"/*.md; do
		[ -f "$f" ] || continue
		# questions.sh list --tsv: id state decision ref title; the group is the list's title
		g=$(bash "$here/questions.sh" status "$f" | sed -n 's/^title=//p')
		r=$(bash "$here/questions.sh" list --tsv "$f" | awk -F'\t' -v OFS='\t' -v doc="$f" -v g="$g" '$2 != "done" { print doc, "question", $1, $2, g, $4, $5 }')
		[ -n "$r" ] && rows="$rows$r"$'\n'
	done
	if [ "$cmd" = status ]; then
		printf '%s' "$rows" | awk -F'\t' 'NF { if ($4 == "open") o++; else a++; d[$1] = 1 } END { n = 0; for (k in d) n++; printf "open=%d\napply=%d\ndocs=%d\n", o, a, n }'
	elif [ "$tsv" = 1 ]; then
		printf '%s' "$rows"
	else
		printf '%s' "$rows" | awk -F'\t' 'NF { n = $1; sub(/.*\//, "", n); printf "%-6s %-5s %-12s %s  (%s)\n", $3, $4, $6, $7, n }'
	fi ;;
show)
	[ $# -eq 2 ] || { usage; exit 2; }
	[ -f "$1" ] || die "no such document: $1" 2
	w=$(writer_of "$1"); [ -n "$w" ] || die "not a decision document: $1" 2
	bash "$w" show "$1" "$2" ;;
set)
	[ $# -eq 3 ] || { usage; exit 2; }
	[ -f "$1" ] || die "no such document: $1" 2
	w=$(writer_of "$1"); [ -n "$w" ] || die "not a decision document: $1" 2
	if [ "$hasnote" = 1 ]; then bash "$w" decide "$1" "$2" "$3" --note "$note"; else bash "$w" decide "$1" "$2" "$3"; fi ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
