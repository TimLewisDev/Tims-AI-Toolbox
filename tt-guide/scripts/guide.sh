#!/usr/bin/env bash
# guide.sh: Tatty, the tt toolbox guide. Says hello, works out where the tt
# documents in a folder stand and which command comes next, and prints README
# sections on request. Needs bash and awk only. Writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: guide.sh [hello]          the greeting, then "where ."
       guide.sh where [dir]      where the tt documents in dir stand, and the next command
       guide.sh start            the README's "Where to start" table
       guide.sh about [name]     a skill's README entry, or a topic (documents, ids, work units, ...);
                                 with no name, the list of topics
       guide.sh quip             one quip

TT_GUIDE_ASCII=1 draws Tatty without box-drawing characters.
Exit: 0 ok, 1 "about" found nothing, 2 usage error.
EOF
}

# Resolve the ~/.claude/skills link to the clone, where the README is. Git Bash's
# cd -P doesn't follow Windows junctions, but readlink -f does.
here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
skill=$(dirname "$here")
root=$(dirname "$skill")
readme="$root/README.md"
MD="$root/tt-common/scripts/md-section.sh"
[ -f "$MD" ] || MD="$(cd "$(dirname "$0")/../.." && pwd)/tt-common/scripts/md-section.sh"

quip() {
	local n
	n=$(awk 'NF && !/^#/' "$skill/quips.txt" 2>/dev/null | wc -l | tr -d ' ')
	[ "${n:-0}" -gt 0 ] || { echo "Hello. I'd tell a joke, but my quips file is missing."; return; }
	awk -v k=$((RANDOM % n + 1)) '{ sub(/\r$/, "") } NF && !/^#/ && ++i == k { print; exit }' "$skill/quips.txt"
}

art() {
	if [ "${TT_GUIDE_ASCII:-}" = 1 ]; then
		cat <<EOF
    [-o-]
   +-----+
   | o o |   Tatty
   |  v  |   "$1"
   +-+-+-+
     | |
EOF
	else
		cat <<EOF
    [¬º-°]¬
   ┌─────┐
   │ ◉ ◉ │   Tatty
   │  ▽  │   "$1"
   └┬───┬┘
    ╨   ╨
EOF
	fi
}

# rel <path>: the path as the user would type it
rel() { case $1 in ./*) printf '%s' "${1#./}" ;; *) printf '%s' "$1" ;; esac; }

# field <file> <regex>: the first line matching the regex, without CR
field() { awk -v re="$2" '{ sub(/\r$/, "") } $0 ~ re { print; exit }' "$1"; }

# stage <plan>: "<stage> (<status>)" for the first Stages row not Closed or Skipped
stage() {
	awk -F'|' '{ sub(/\r$/, "") }
		/^\*\*Stages\*\*/ { on = 1; next }
		on && /^\|/ {
			s = $2; t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
			if (s == "Stage" || s ~ /^-+$/) next
			if (t != "Closed" && t != "Skipped") { print s " (" t ")"; exit }
			next
		}
		on && NF && !/^\|/ { exit }' "$1"
}

where() {
	local dir=${1:-.}
	[ -d "$dir" ] || { echo "guide.sh: no such folder: $dir" >&2; exit 2; }
	local prefixes f b d
	prefixes=$(
		for f in "$dir"/*" - "*.md; do
			[ -f "$f" ] || continue
			b=${f##*/}
			case $b in
			*" - Comprehensive Tech Plan.md" | *" - Task Status.md" | *" - Task Breakdown.md" | *" - Familiarisation.md")
				echo "${b% - *}" ;;
			esac
		done
		for d in "$dir"/.tt/*" - Familiarisation"; do
			[ -f "$d/focus-log.md" ] && b=${d##*/} && echo "${b% - Familiarisation}"
		done
	)
	prefixes=$(printf '%s\n' "$prefixes" | awk 'NF' | sort -u)
	if [ -z "$prefixes" ]; then
		if [ "$dir" = . ]; then echo "No tt documents here."; else echo "No tt documents in $(rel "$dir")."; fi
		echo "  New here? Explore with /tt-familiarise <topic>, or plan with /tt-adversarial-plan <idea or ticket>."
		echo "  Docs in a vault or another folder? Ask me to look there (guide.sh where <folder>)."
		return 0
	fi
	local p plan st bd tp fam log state prog next status rev mir s
	while IFS= read -r p; do
		plan="$dir/$p - Comprehensive Tech Plan.md"; st="$dir/$p - Task Status.md"
		bd="$dir/$p - Task Breakdown.md"; tp="$dir/$p - Tech Plan.md"
		fam="$dir/$p - Familiarisation.md"; log="$dir/.tt/$p - Familiarisation/focus-log.md"
		if [ -f "$st" ]; then
			state=$(field "$st" '^- State:'); state=${state#- State: }
			prog=$(field "$st" '^- Progress:'); prog=${prog#- Progress: }
			next=$(field "$st" '^4[.] Next action:'); next=${next#4. Next action: }
			if [ "$state" = Complete ]; then
				echo "$p: built and validated ($prog). Commit it yourself, then review the MR."
				echo "  → /tt-mr-review [MR number or branch]"
			else
				echo "$p: building (${state:-state unknown}${prog:+; $prog}).${next:+ Next: $next}"
				echo "  → /tt-execute \"$(rel "$st")\""
			fi
		elif [ -f "$plan" ]; then
			status=$(field "$plan" 'Status:')
			if printf '%s' "$status" | grep -q Draft; then
				s=$(stage "$plan")
				echo "$p: planning, draft plan${s:+ at $s}."
				echo "  → /tt-adversarial-plan resume \"$(rel "$plan")\""
			elif [ -d "$dir/.tt/$p - Task Breakdown" ]; then
				echo "$p: signed off; a breakdown is part-written."
				echo "  → /tt-task-breakdown \"$(rel "$plan")\"   (picks up the draft)"
			elif [ -f "$bd" ]; then
				echo "$p: breakdown written, but no Task Status yet."
				echo "  → /tt-task-status \"$(rel "$bd")\""
			else
				echo "$p: plan signed off; ready to break down."
				echo "  → /tt-task-breakdown \"$(rel "$plan")\""
			fi
			rev=$(field "$plan" 'Revision:' | sed -n 's/.*Revision:[* ]*\([0-9][0-9]*\).*/\1/p')
			if [ -f "$tp" ] && [ -n "$rev" ]; then
				mir=$(field "$tp" 'Mirrors revision' | sed -n 's/.*Mirrors revision:[* ]*\([0-9][0-9]*\).*/\1/p')
				[ -n "$mir" ] && [ "$mir" -lt "$rev" ] &&
					echo "  ! The Tech Plan mirrors revision $mir; the plan is at $rev. → /tt-tech-plan \"$(rel "$plan")\""
			fi
		elif [ -f "$fam" ]; then
			echo "$p: explored and written up; no plan yet."
			echo "  → /tt-adversarial-plan \"$(rel "$fam")\""
		elif [ -f "$log" ]; then
			echo "$p: exploring (a Focus Log, not yet written up)."
			echo "  → /tt-familiarise resume \"$(rel "$log")\""
			echo "  → or write it up: /tt-familiarisation-doc \"$(rel "$log")\""
		elif [ -f "$bd" ]; then
			echo "$p: a Task Breakdown with no plan or Task Status beside it."
			echo "  → /tt-task-status \"$(rel "$bd")\""
		fi
	done <<<"$prefixes"
}

need_readme() {
	[ -f "$readme" ] && [ -f "$MD" ] && return 0
	echo "(I can't find the toolbox README beside this skill, so here's the short version.)"
	cat <<'EOF'
  explore code ............ /tt-familiarise <topic>
  plan a feature .......... /tt-adversarial-plan [idea, doc, spec or ticket]
  resume planning ......... /tt-adversarial-plan resume <draft plan>
  review or change a plan . /tt-tech-plan-review [tech plan]
  break it into tasks ..... /tt-task-breakdown <comprehensive tech plan>
  build ................... /tt-execute <task status>
  small change, no plan ... /tt-coder <plan, spec or ticket>
  review an MR ............ /tt-mr-review [MR or branch]
EOF
	return 1
}

# sections <starts|contains> <text>: README headings (level 2-4) whose text
# starts with or contains the text, ignoring case (a fixed string, not a regex)
sections() {
	bash "$MD" index "$readme" | Q="$2" awk -F'\t' -v m="$1" '
		BEGIN { q = tolower(ENVIRON["Q"]) }
		$2 >= 2 && $2 <= 4 { i = index(tolower($4), q); if (m == "starts" ? i == 1 : i > 0) print }'
}

# topics: the README headings that aren't a skill's entry
topics() { sections contains "" | awk -F'\t' '$4 !~ /^\[`tt-/ { print "  " $4 }'; }

# show <index lines>: print each section
show() {
	local line ln end
	while IFS=$'\t' read -r ln _ end _; do
		sed -n "${ln},${end}p" "$readme" | tr -d '\r'
		echo
	done <<<"$1"
}

about() {
	need_readme || return 0
	local q hits row
	q=$(printf '%s' "$*" | tr '[:upper:]' '[:lower:]')
	if [ -z "$q" ]; then
		echo "Ask me about any tt-* skill, or one of these:"
		topics
		return 0
	fi
	case $q in docs | doc) q=documents ;; id | revisions) q=ids ;; units | wu | tasks) q="work units" ;;
		metrics | tokens) q="token log" ;; stages) q="planning stages" ;; esac
	local name=${q#tt-}
	if [ -d "$root/tt-$name" ]; then
		row=$(grep -F "| [\`tt-$name\`]" "$readme" | head -1 | tr -d '\r')
		[ -n "$row" ] && printf '%s\n\n' "$row"
		hits=$(sections starts "[\`tt-$name\`]")
		case $name in requirements | scope | approach | technical-design | plan-signoff)
			hits=$(sections starts "the planning stages") ;; esac
		if [ -n "$hits" ]; then
			show "$hits"
		elif [ -z "$row" ]; then
			field "$root/tt-$name/SKILL.md" '^name:'
			awk '/^description:/ { on = 1; next } on && /^[a-z-]+:/ { exit } on { sub(/^  /, ""); print }' "$root/tt-$name/SKILL.md"
		fi
		return 0
	fi
	hits=$(sections contains "$q")
	if [ -n "$hits" ]; then
		show "$hits"
		return 0
	fi
	echo "Nothing in the README about \"$*\". Try a skill name (tt-scope, execute, ...) or one of:"
	topics
	return 1
}

cmd=${1:-hello}
[ $# -gt 0 ] && shift
case $cmd in
hello)
	art "$(quip)"
	echo
	echo "Where things stand in $(pwd):"
	where .
	echo
	echo "Ask me anything about the toolbox: which skill to run, what a document is for, how to resume."
	;;
where) where "$@" ;;
start) if need_readme; then bash "$MD" get "$readme" "Where to start" | tr -d '\r'; fi ;;
about) about "$@" ;;
quip) quip ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
