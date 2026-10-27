#!/usr/bin/env bash
# workflow-state.sh: works out where the tt documents in a folder stand and which
# skill comes next. Used by tt-workflow and tt-guide. Needs bash and awk only.
# Writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: workflow-state.sh [--tsv] <folder>

Prints, for each feature (documents sharing a "<Prefix> - " name) in the folder,
where it stands and the command to run next:

  Demo: building (In Progress; 2/5 tasks). Next: T03 ...
    → /tt-execute "Demo - Task Status.md"

--tsv prints one row per finding instead, tab-separated:
  prefix  kind  phase  skill  verb  arg  text  hint  stage
  kind: primary (the next step), alt (another sensible step), warn (a problem)
  stage: the stage the next session works on (Familiarise, Planning, or the
         open planning stage such as Scope, Task Breakdown, Build, Lite Brief,
         Debug, Debug Report, Fix); empty when nothing is left to run
  phase: exploring explored planning signed-off breakdown-draft breakdown-written
         building complete breakdown-orphan empty
         lite-focus lite-brief debugging debug-done debugged (the lite route)
  skill is "-" when nothing is left to run (complete).

Exit: 0 found something, 1 no tt documents in the folder, 2 usage error.
EOF
}

tsv=0
[ "${1:-}" = --tsv ] && { tsv=1; shift; }
case ${1:-} in -h | --help) usage; exit 0 ;; esac
[ $# -eq 1 ] || { usage; exit 2; }
dir=$1; [ "${dir%/}" != "" ] && dir=${dir%/}
[ -d "$dir" ] || { echo "workflow-state.sh: no such folder: $dir" >&2; exit 2; }

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

# stage_of <phase>: the label of the stage the next session works on
stage_of() {
	case $1 in
	empty | explored) echo "Planning" ;;
	exploring | lite-exploring) echo "Familiarise" ;;
	planning) echo "Planning" ;;
	signed-off | breakdown-draft | breakdown-written | breakdown-orphan) echo "Task Breakdown" ;;
	building | lite-brief) echo "Build" ;;
	lite-focus) echo "Lite Brief" ;;
	debugging) echo "Debug" ;;
	debug-done) echo "Debug Report" ;;
	debugged) echo "Fix" ;;
	esac
}

# row <prefix> <kind> <phase> <skill> <verb> <arg> <text> [hint] [stage]
# stage defaults to the phase's label (stage_of); "complete" has none.
rows=""
row() { rows+=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${8:-}" "${9:-$(stage_of "$3")}")$'\n'; }

prefixes=$(
	for f in "$dir"/*" - "*.md; do
		[ -f "$f" ] || continue
		b=${f##*/}
		case $b in
		*" - Comprehensive Tech Plan.md" | *" - Task Status.md" | *" - Task Breakdown.md" | *" - Familiarisation.md" | *" - Lite Brief.md" | *" - Debug Report.md")
			echo "${b% - *}" ;;
		esac
	done
	for d in "$dir"/.tt/*" - Familiarisation"; do
		[ -f "$d/focus-log.md" ] && b=${d##*/} && echo "${b% - Familiarisation}"
	done
	for d in "$dir"/.tt/*" - Debug"; do
		[ -f "$d/debug-log.md" ] && b=${d##*/} && echo "${b% - Debug}"
	done
)
prefixes=$(printf '%s\n' "$prefixes" | awk 'NF' | sort -u)

if [ -z "$prefixes" ]; then
	if [ "$dir" = . ]; then here="here"; else here="in $(rel "$dir")"; fi
	row "" primary empty tt-adversarial-plan "" "" "No tt documents $here." "<idea, spec or ticket>"
else
	while IFS= read -r p; do
		plan="$dir/$p - Comprehensive Tech Plan.md"; st="$dir/$p - Task Status.md"
		bd="$dir/$p - Task Breakdown.md"; tp="$dir/$p - Tech Plan.md"
		fam="$dir/$p - Familiarisation.md"; log="$dir/.tt/$p - Familiarisation/focus-log.md"
		lb="$dir/$p - Lite Brief.md"; dlog="$dir/.tt/$p - Debug/debug-log.md"; drep="$dir/$p - Debug Report.md"
		if [ -f "$st" ]; then
			state=$(field "$st" '^- State:'); state=${state#- State: }
			prog=$(field "$st" '^- Progress:'); prog=${prog#- Progress: }
			next=$(field "$st" '^4[.] Next action:'); next=${next#4. Next action: }
			if [ "$state" = Complete ]; then
				row "$p" primary complete - "" "" "built and validated ($prog). Commit it yourself, then review the branch."
				row "$p" alt complete tt-branch-review "" "" "review the branch:" "[branch]"
			else
				if [ -f "$lb" ]; then ex=tt-execute-lite; exa=$(rel "$lb"); else ex=tt-execute; exa=$(rel "$st"); fi
				row "$p" primary building "$ex" "" "$exa" "building (${state:-state unknown}${prog:+; $prog}).${next:+ Next: $next}"
			fi
		elif [ -f "$lb" ]; then
			row "$p" primary lite-brief tt-execute-lite "" "$(rel "$lb")" "lite brief written; not started."
		elif [ -f "$plan" ]; then
			status=$(field "$plan" 'Status:')
			if printf '%s' "$status" | grep -q Draft; then
				s=$(stage "$plan")
				row "$p" primary planning tt-adversarial-plan resume "$(rel "$plan")" "planning, draft plan${s:+ at $s}." "" "${s% (*}"
			elif [ -d "$dir/.tt/$p - Task Breakdown" ]; then
				row "$p" primary breakdown-draft tt-task-breakdown "" "$(rel "$plan")" "signed off; a breakdown is part-written." "(picks up the draft)"
			elif [ -f "$bd" ]; then
				row "$p" primary breakdown-written tt-task-status "" "$(rel "$bd")" "breakdown written, but no Task Status yet."
			else
				row "$p" primary signed-off tt-task-breakdown "" "$(rel "$plan")" "plan signed off; ready to break down."
				row "$p" alt signed-off tt-tech-plan-review "" "$(rel "$plan")" "or review or change the plan first:"
			fi
			rev=$(field "$plan" 'Revision:' | sed -n 's/.*Revision:[* ]*\([0-9][0-9]*\).*/\1/p')
			if [ -f "$tp" ] && [ -n "$rev" ]; then
				mir=$(field "$tp" 'Mirrors revision' | sed -n 's/.*Mirrors revision:[* ]*\([0-9][0-9]*\).*/\1/p')
				[ -n "$mir" ] && [ "$mir" -lt "$rev" ] &&
					row "$p" warn signed-off tt-tech-plan "" "$(rel "$plan")" "The Tech Plan mirrors revision $mir; the plan is at $rev."
			fi
		elif [ -f "$fam" ]; then
			row "$p" primary explored tt-adversarial-plan "" "$(rel "$fam")" "explored and written up; no plan yet."
		elif [ -f "$log" ] && grep -q 'Mode:\*\* lite' "$log"; then
			if grep -q '^- \*\*Status:\*\* *Focus confirmed' "$log"; then
				row "$p" primary lite-focus tt-lite-brief "" "$(rel "$log")" "lite exploration done; ready for the brief."
			else
				row "$p" primary exploring tt-familiarise resume "$(rel "$log")" "exploring (lite; the focus is not yet confirmed)."
			fi
		elif [ -f "$log" ]; then
			row "$p" primary exploring tt-familiarise resume "$(rel "$log")" "exploring (a Focus Log, not yet written up)."
			row "$p" alt exploring tt-familiarisation-doc "" "$(rel "$log")" "or write it up:"
		elif [ -f "$drep" ]; then
			row "$p" primary debugged - "" "" "debugged; the report is written."
			if [ -f "$dlog" ] && field "$dlog" '^- [*][*]Status:[*][*]' | grep -q 'Root cause confirmed'; then
				row "$p" alt debugged tt-lite-brief "" "$(rel "$dlog")" "or fix it:"
			fi
		elif [ -f "$dlog" ]; then
			dst=$(field "$dlog" '^- [*][*]Status:[*][*]')
			if printf '%s' "$dst" | grep -Eq 'Root cause confirmed|Unresolved'; then
				row "$p" primary debug-done tt-debug-doc "" "$(rel "$dlog")" "debugging finished; no report yet."
				printf '%s' "$dst" | grep -q 'Root cause confirmed' &&
					row "$p" alt debug-done tt-lite-brief "" "$(rel "$dlog")" "or fix it:"
			else
				row "$p" primary debugging tt-debug resume "$(rel "$dlog")" "debugging (the root cause is not yet confirmed)."
			fi
		elif [ -f "$bd" ]; then
			row "$p" primary breakdown-orphan tt-task-status "" "$(rel "$bd")" "a Task Breakdown with no plan or Task Status beside it."
		fi
		# A fix may be planned or built before the debugging is written up: keep offering the report.
		if [ -f "$lb" ] && [ -f "$dlog" ] && [ ! -f "$drep" ] &&
			field "$dlog" '^- [*][*]Status:[*][*]' | grep -Eq 'Root cause confirmed|Unresolved'; then
			row "$p" alt debug-done tt-debug-doc "" "$(rel "$dlog")" "or write up the debugging:"
		fi
	done <<<"$prefixes"
fi

if [ "$tsv" = 1 ]; then
	printf '%s' "$rows"
else
	printf '%s' "$rows" | awk -F'\t' '
		function cmd(    c) {
			c = "/" $4
			if ($5 != "") c = c " " $5
			if ($6 != "") c = c " \"" $6 "\""
			if ($8 != "") c = c " " $8
			return c
		}
		$2 == "primary" {
			print ($1 == "" ? "" : $1 ": ") $7
			if ($4 != "-") print "  → " cmd()
			next
		}
		$2 == "alt" { print "  → " $7 " " cmd(); next }
		$2 == "warn" { print "  ! " $7 " → " cmd() }'
fi
[ "$prefixes" != "" ]
