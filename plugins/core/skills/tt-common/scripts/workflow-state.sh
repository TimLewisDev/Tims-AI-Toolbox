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
  A lite Focus Log whose header has "**Pace:** quick" (tt-workflow-quick) names
  tt-workflow-quick, with the folder as its argument, in place of tt-lite-brief
  (focus confirmed) or tt-familiarise resume (not yet confirmed).

Exit: 0 found something, 1 no tt documents in the folder, 2 usage error.
EOF
}

tsv=0
[ "${1:-}" = --tsv ] && { tsv=1; shift; }
case ${1:-} in -h | --help) usage; exit 0 ;; esac
[ $# -eq 1 ] || { usage; exit 2; }
dir=$1; [ "${dir%/}" != "" ] && dir=${dir%/}
[ -d "$dir" ] || { echo "workflow-state.sh: no such folder: $dir" >&2; exit 2; }

here=${0%[/\\]*}
[ "$here" = "$0" ] && here=.
. "$here/decide-lib.sh"

# field <file> <regex>: sets REPLY to the first line matching the regex, without
# CR (empty when none does)
field() {
	local l
	REPLY=""
	while IFS= read -r l || [ -n "$l" ]; do
		l=${l%$'\r'}
		if [[ $l =~ $2 ]]; then REPLY=$l; return 0; fi
	done <"$1"
	return 0
}

# num_after <label>: sets REPLY to the digits after the last "<label>" on the
# line in REPLY (after any * or space); if that one has none, the one before it
num_after() {
	local s=$REPLY re='^[* ]*([0-9]+)' after
	REPLY=""
	while [[ $s == *"$1"* ]]; do
		after=${s##*"$1"}
		if [[ $after =~ $re ]]; then REPLY=${BASH_REMATCH[1]}; return 0; fi
		s=${s%"$1"*}
	done
	return 0
}

# left_out <stage>: the folder's stage profile (stages.sh) leaves this stage out
left_out() { [ -f "$dir/.tt/workflow-stages.tsv" ] && awk -F'\t' -v k="$1" '{ sub(/\r$/, "") } $1 == k && $2 == "off" { f = 1 } END { exit !f }' "$dir/.tt/workflow-stages.tsv"; }

# stage <plan>: "<stage> (<status>)" for the first Stages row not Closed or Skipped
# (either may carry a note: "Skipped: known area", "Closed (challenge skipped: small)")
stage() {
	awk -F'|' '{ sub(/\r$/, "") }
		/^\*\*Stages\*\*/ { on = 1; next }
		on && /^\|/ {
			s = $2; t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
			if (s == "Stage" || s ~ /^-+$/) next
			if (t !~ /^(Closed|Skipped)/) { print s " (" t ")"; exit }
			next
		}
		on && NF && !/^\|/ { exit }' "$1"
}

# stage_of <phase>: sets REPLY to the label of the stage the next session works on
stage_of() {
	REPLY=""
	case $1 in
	empty | explored) REPLY="Planning" ;;
	exploring | lite-exploring) REPLY="Familiarise" ;;
	planning) REPLY="Planning" ;;
	signed-off | breakdown-draft | breakdown-written | breakdown-orphan) REPLY="Task Breakdown" ;;
	building | lite-brief) REPLY="Build" ;;
	lite-focus) REPLY="Lite Brief" ;;
	debugging) REPLY="Debug" ;;
	debug-done) REPLY="Debug Report" ;;
	debugged) REPLY="Fix" ;;
	esac
}

# row <prefix> <kind> <phase> <skill> <verb> <arg> <text> [hint] [stage]
# stage defaults to the phase's label (stage_of); "complete" has none.
rows=""
row() {
	local line stage=${9:-}
	if [ -z "$stage" ]; then stage_of "$3"; stage=$REPLY; fi
	printf -v line '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${8:-}" "$stage"
	rows+=$line$'\n'
}

list=()
for f in "$dir"/*" - "*.md; do
	[ -f "$f" ] || continue
	b=${f##*/}
	case $b in
	*" - Comprehensive Tech Plan.md" | *" - Task Status.md" | *" - Task Breakdown.md" | *" - Familiarisation.md" | *" - Lite Brief.md" | *" - Debug Report.md")
		list+=("${b% - *}") ;;
	esac
done
for d in "$dir"/.tt/*" - Familiarisation"; do
	[ -f "$d/focus-log.md" ] && b=${d##*/} && list+=("${b% - Familiarisation}")
done
for d in "$dir"/.tt/*" - Debug"; do
	[ -f "$d/debug-log.md" ] && b=${d##*/} && list+=("${b% - Debug}")
done
kept=()
if [ ${#list[@]} -gt 0 ]; then
	for b in "${list[@]}"; do
		[[ $b =~ [^[:space:]] ]] && kept+=("$b")
	done
fi
prefixes=""
if [ ${#kept[@]} -gt 0 ]; then prefixes=$(printf '%s\n' "${kept[@]}" | sort -u); fi

if [ -z "$prefixes" ]; then
	if [ "$dir" = . ]; then at="here"; else at="in ${dir#./}"; fi
	row "" primary empty tt-adversarial-plan "" "" "No tt documents $at." "<idea, spec or ticket>"
else
	dl_waiting_all "$dir"
	while IFS= read -r p; do
		plan="$dir/$p - Comprehensive Tech Plan.md"; st="$dir/$p - Task Status.md"
		bd="$dir/$p - Task Breakdown.md"; tp="$dir/$p - Tech Plan.md"
		fam="$dir/$p - Familiarisation.md"; log="$dir/.tt/$p - Familiarisation/focus-log.md"
		lb="$dir/$p - Lite Brief.md"; dlog="$dir/.tt/$p - Debug/debug-log.md"; drep="$dir/$p - Debug Report.md"
		if [ -f "$st" ]; then
			field "$st" '^- State:'; state=${REPLY#- State: }
			field "$st" '^- Progress:'; prog=${REPLY#- Progress: }
			field "$st" '^4[.] Next action:'; next=${REPLY#4. Next action: }
			if [ "$state" = Complete ]; then
				row "$p" primary complete - "" "" "built and validated ($prog). Commit it yourself, then review the branch."
				left_out review || row "$p" alt complete tt-branch-review "" "" "review the branch:" "[branch]"
			else
				if [ -f "$lb" ]; then ex=tt-execute-lite; exa=${lb#./}; else ex=tt-execute; exa=${st#./}; fi
				row "$p" primary building "$ex" "" "$exa" "building (${state:-state unknown}${prog:+; $prog}).${next:+ Next: $next}${DL_WAIT[$p]-}"
			fi
		elif [ -f "$lb" ]; then
			row "$p" primary lite-brief tt-execute-lite "" "${lb#./}" "lite brief written; not started.${DL_WAIT[$p]-}"
		elif [ -f "$plan" ]; then
			field "$plan" 'Status:'; status=$REPLY
			if [[ $status == *Draft* ]]; then
				s=$(stage "$plan")
				row "$p" primary planning tt-adversarial-plan resume "${plan#./}" "planning, draft plan${s:+ at $s}.${DL_WAIT[$p]-}" "" "${s% (*}"
			elif [ -d "$dir/.tt/$p - Task Breakdown" ]; then
				row "$p" primary breakdown-draft tt-task-breakdown "" "${plan#./}" "signed off; a breakdown is part-written." "(picks up the draft)"
			elif [ -f "$bd" ]; then
				row "$p" primary breakdown-written tt-task-status "" "${bd#./}" "breakdown written, but no Task Status yet."
			else
				row "$p" primary signed-off tt-task-breakdown "" "${plan#./}" "plan signed off; ready to break down.${DL_WAIT[$p]-}"
				row "$p" alt signed-off tt-tech-plan-review "" "${plan#./}" "or review or change the plan first:"
			fi
			field "$plan" 'Revision:'; num_after 'Revision:'; rev=$REPLY
			if [ -f "$tp" ] && [ -n "$rev" ]; then
				field "$tp" 'Mirrors revision'; num_after 'Mirrors revision:'; mir=$REPLY
				[ -n "$mir" ] && [ "$mir" -lt "$rev" ] &&
					row "$p" warn signed-off tt-tech-plan "" "${plan#./}" "The Tech Plan mirrors revision $mir; the plan is at $rev."
			fi
		elif [ -f "$fam" ]; then
			row "$p" primary explored tt-adversarial-plan "" "${fam#./}" "explored and written up; no plan yet."
		elif [ -f "$log" ] && { field "$log" 'Mode:[*][*] lite'; [ -n "$REPLY" ]; }; then
			# A log marked **Pace:** quick belongs to tt-workflow-quick, which carries it on without a conversation.
			field "$log" '^- [*][*]Pace:[*][*] *quick'; quick=$REPLY
			field "$log" '^- [*][*]Status:[*][*] *Focus confirmed'
			if [ -n "$REPLY" ]; then
				if [ -n "$quick" ]; then
					row "$p" primary lite-focus tt-workflow-quick "" "${dir#./}" "quick exploration done; ready for the brief.${DL_WAIT[$p]-}"
				else
					row "$p" primary lite-focus tt-lite-brief "" "${log#./}" "lite exploration done; ready for the brief.${DL_WAIT[$p]-}"
				fi
			elif [ -n "$quick" ]; then
				row "$p" primary exploring tt-workflow-quick "" "${dir#./}" "exploring (quick; the go-ahead is not yet given)."
			else
				row "$p" primary exploring tt-familiarise resume "${log#./}" "exploring (lite; the focus is not yet confirmed)."
			fi
		elif [ -f "$log" ]; then
			row "$p" primary exploring tt-familiarise resume "${log#./}" "exploring (a Focus Log, not yet written up)."
			row "$p" alt exploring tt-familiarisation-doc "" "${log#./}" "or write it up:"
		elif [ -f "$drep" ]; then
			row "$p" primary debugged - "" "" "debugged; the report is written."
			if [ -f "$dlog" ] && { field "$dlog" '^- [*][*]Status:[*][*]'; [[ $REPLY == *'Root cause confirmed'* ]]; }; then
				row "$p" alt debugged tt-lite-brief "" "${dlog#./}" "or fix it:"
			fi
		elif [ -f "$dlog" ]; then
			field "$dlog" '^- [*][*]Status:[*][*]'; dst=$REPLY
			if [[ $dst == *'Root cause confirmed'* || $dst == *Unresolved* ]]; then
				row "$p" primary debug-done tt-debug-doc "" "${dlog#./}" "debugging finished; no report yet."
				[[ $dst == *'Root cause confirmed'* ]] &&
					row "$p" alt debug-done tt-lite-brief "" "${dlog#./}" "or fix it:"
			else
				row "$p" primary debugging tt-debug resume "${dlog#./}" "debugging (the root cause is not yet confirmed)."
			fi
		elif [ -f "$bd" ]; then
			row "$p" primary breakdown-orphan tt-task-status "" "${bd#./}" "a Task Breakdown with no plan or Task Status beside it."
		fi
		# A fix may be planned or built before the debugging is written up: keep offering the report.
		if [ -f "$lb" ] && [ -f "$dlog" ] && [ ! -f "$drep" ] &&
			field "$dlog" '^- [*][*]Status:[*][*]' &&
		[[ $REPLY == *'Root cause confirmed'* || $REPLY == *Unresolved* ]]; then
			row "$p" alt debug-done tt-debug-doc "" "${dlog#./}" "or write up the debugging:"
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
