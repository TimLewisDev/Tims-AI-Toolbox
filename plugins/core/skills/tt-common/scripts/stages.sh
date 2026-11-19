#!/usr/bin/env bash
# stages.sh: which stages a feature's workflow includes. Keeps a small profile in
# the feature folder and is the only writer of it. Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: stages.sh show [--tsv] [--phase <phase>] <folder>
       stages.sh set [--phase <phase>] <folder> <stage> on|off
       stages.sh check <folder>
       stages.sh skip-challenge [--check] <folder> <stage> [reason]

The profile is <folder>/.tt/workflow-stages.tsv: one "<stage><TAB>off" line per
stage left out; no file means every stage is included.

Stages (key, in workflow order):
  explore       Explore (Familiarisation)      can be left out
  plan          Plan                           leaves out the Breakdown too: a Lite
                                               Brief replaces both (the lite route)
  requirements  Requirements                   always included
  scope         Scope & Constraints            can be left out
  approach      Approach                       can be left out
  design        Technical Design               always included
  whole-plan    Whole plan challenge           can be left out
  signoff       Sign-off                       always included
  breakdown     Task Breakdown                 follows Plan
  build         Build                          always included
  review        Review                         can be left out

A stage is locked once its work has begun. set refuses a locked stage, a stage
that cannot be left out, or an unknown stage (exit 1; the reason on stderr).

skip-challenge closes a stage of the draft plan whose adversary challenge is
pending (explore, requirements, scope, approach, design, whole-plan) without
running it: its Stages row becomes "Closed (challenge skipped: <reason>)". Only
for the engineer's own choice. --check says whether it could (exit 0), changing
nothing; exit 1 with the reason when the challenge isn't pending.

show --tsv prints, per stage: key label level on locked why
  level: top, or plan for the planning stages (their parent is Plan)
  on: on or off (off while Plan is off); locked: 1 or 0; why: the reason if locked

--phase gives the phase workflow-state.sh would report for the folder, so this
script does not run it. The accepted values are exploring, explored, planning,
signed-off, breakdown-draft, breakdown-written, building, complete,
breakdown-orphan, empty, lite-focus, lite-brief, debugging, debug-done and
debugged; anything else is a usage error.

Exit: 0 ok, 1 refused or findings, 2 usage error.
EOF
}

here=${0%[/\\]*}
[ "$here" = "$0" ] && here=.
KEYS="explore plan requirements scope approach design whole-plan signoff breakdown build review"

# The lookups below set a global (LABEL, TITLE, LEVEL) rather than print, so the
# show loop starts no process.
label_of() {
	LABEL=""
	case $1 in
	explore) LABEL="Familiarisation" ;;
	plan) LABEL="Plan" ;;
	requirements) LABEL="Requirements" ;;
	scope) LABEL="Scope & Constraints" ;;
	approach) LABEL="Approach" ;;
	design) LABEL="Technical Design" ;;
	whole-plan) LABEL="Whole plan" ;;
	signoff) LABEL="Sign-off" ;;
	breakdown) LABEL="Task Breakdown" ;;
	build) LABEL="Build" ;;
	review) LABEL="Review" ;;
	esac
}
# the name shown to a person for a top-level row
title_of() { case $1 in explore) TITLE="Explore" ;; *) label_of "$1"; TITLE=$LABEL ;; esac; }
level_of() { case $1 in requirements | scope | approach | design | whole-plan | signoff) LEVEL=plan ;; *) LEVEL=top ;; esac; }
valid_key() { case " $KEYS " in *" $1 "*) return 0 ;; esac; return 1; }

cmd=${1:-}
[ $# -gt 0 ] && shift
tsv=0
PHASE=""
have_phase=0
# Options come right after the command word, in any order, up to the first
# argument that is not one. --tsv is for show only; --phase for show and set.
# On any other command they are positional arguments, as they always were.
if [ "$cmd" = show ] || [ "$cmd" = set ]; then
	while [ $# -gt 0 ]; do
		case $1 in
		--tsv)
			[ "$cmd" = show ] || break
			[ $tsv = 0 ] || { usage; exit 2; }
			tsv=1; shift ;;
		--phase)
			[ $have_phase = 0 ] || { usage; exit 2; }
			[ $# -ge 2 ] || { usage; exit 2; }
			# The accepted phases are the ones workflow-state.sh reports; keep this
			# list in step with it.
			case $2 in
			exploring | explored | planning | signed-off | breakdown-draft | breakdown-written | building | complete | breakdown-orphan | empty | lite-focus | lite-brief | debugging | debug-done | debugged) ;;
			*)
				echo "stages.sh: unknown phase: $2 (use one of: exploring, explored, planning, signed-off, breakdown-draft, breakdown-written, building, complete, breakdown-orphan, empty, lite-focus, lite-brief, debugging, debug-done, debugged)" >&2
				exit 2 ;;
			esac
			PHASE=$2; have_phase=1
			shift 2 ;;
		*) break ;;
		esac
	done
fi
CHECK=0
if [ "$cmd" = skip-challenge ] && [ "${1:-}" = --check ]; then CHECK=1; shift; fi
case $cmd in -h | --help) usage; exit 0 ;; show | check) [ $# -eq 1 ] || { usage; exit 2; } ;; set) [ $# -eq 3 ] || { usage; exit 2; } ;; skip-challenge) { [ $# -eq 2 ] || [ $# -eq 3 ]; } || { usage; exit 2; } ;; *) usage; exit 2 ;; esac
dir=$1; [ "${dir%/}" != "" ] && dir=${dir%/}
[ -d "$dir" ] || { echo "stages.sh: no such folder: $dir" >&2; exit 2; }
profile="$dir/.tt/workflow-stages.tsv"

# The profile, read once: OFF holds a tab-wrapped list of the stages left out.
OFF=""
if [ -f "$profile" ]; then
	while IFS= read -r l || [ -n "$l" ]; do
		l=${l%$'\r'}
		case $l in *$'\t'*) ;; *) continue ;; esac
		first=${l%%$'\t'*}
		rest=${l#*$'\t'}
		second=${rest%%$'\t'*}
		[ "$second" = off ] && OFF="$OFF"$'\t'"$first"$'\t'
	done <"$profile"
fi

# is_off <key>: the profile leaves the stage out
is_off() { case $OFF in *$'\t'"$1"$'\t'*) return 0 ;; esac; return 1; }

# PHASE: where the folder's documents stand (workflow-state.sh's first primary
# row). Looked up only when a stage needs it, and not at all when --phase gave it.
get_phase() {
	[ -n "$PHASE" ] && return 0
	local out l r r2 third
	out=$(bash "$here/workflow-state.sh" --tsv "$dir" 2>/dev/null)
	PHASE=empty
	while IFS= read -r l || [ -n "$l" ]; do
		case $l in *$'\t'*) ;; *) continue ;; esac
		r=${l#*$'\t'}
		case $r in *$'\t'*) ;; *) continue ;; esac
		if [ "${r%%$'\t'*}" = primary ]; then
			r2=${r#*$'\t'}
			third=${r2%%$'\t'*}
			[ -n "$third" ] && PHASE=$third
			break
		fi
	done <<<"$out"
}

# the draft plan, if there is one
draft=""
for f in "$dir"/*" - Comprehensive Tech Plan.md"; do
	[ -f "$f" ] || continue
	while IFS= read -r l || [ -n "$l" ]; do
		l=${l%$'\r'}
		case $l in
		*Status:*)
			case $l in *Draft*) draft=$f ;; esac
			break ;;
		esac
	done <"$f"
	[ -n "$draft" ] && break
done

# the draft plan's Stages table, read once
ST_N=0
if [ -n "$draft" ]; then
	on=0
	while IFS= read -r l || [ -n "$l" ]; do
		l=${l%$'\r'}
		case $l in
		'**Stages**'*) on=1; continue ;;
		'|'*)
			[ $on = 1 ] || continue
			rest=${l#'|'}
			s=${rest%%'|'*}
			t=""
			case $rest in *'|'*) r2=${rest#*'|'}; t=${r2%%'|'*} ;; esac
			s=${s#"${s%%[! ]*}"}; s=${s%"${s##*[! ]}"}
			t=${t#"${t%%[! ]*}"}; t=${t%"${t##*[! ]}"}
			ST_LABEL[$ST_N]=$s
			ST_STATUS[$ST_N]=$t
			ST_N=$((ST_N + 1)) ;;
		'') ;;
		*) [ $on = 1 ] && break ;;
		esac
	done <"$draft"
fi

# row_status <stage name>: sets ROWST to the Status cell of that Stages row in the draft plan
row_status() {
	local i=0
	ROWST=""
	while [ $i -lt $ST_N ]; do
		if [ "${ST_LABEL[$i]}" = "$1" ]; then ROWST=${ST_STATUS[$i]}; return 0; fi
		i=$((i + 1))
	done
}

plan_off() { is_off plan; }

# lock_of <key>: sets WHY to the reason the stage cannot change now; empty when it can
lock_of() {
	local k=$1 st
	WHY=""
	case $k in
	build) WHY="Build is always part of the workflow."; return ;;
	requirements | design | signoff) WHY="Always included: the breakdown depends on what this stage writes."; return ;;
	esac
	[ "$k" = review ] && return
	get_phase
	case $PHASE in building | complete) WHY="Building has started."; return ;; esac
	case $k in
	plan | breakdown)
		[ "$PHASE" = empty ] || WHY="Work has started; the route cannot change now."
		return ;;
	explore)
		if plan_off; then WHY="The lite route always explores."; return; fi
		case $PHASE in
		empty) return ;;
		planning)
			row_status Familiarisation; st=$ROWST
			case $st in "Not started" | Skipped*) return ;; esac
			WHY="Familiarisation has started." ;;
		*) WHY="Familiarisation has started." ;;
		esac
		return ;;
	scope | approach | whole-plan)
		if plan_off; then WHY="Off with Plan (the lite route has no planning stages)."; return; fi
		case $PHASE in
		empty | exploring | explored) return ;;
		planning)
			label_of "$k"; row_status "$LABEL"; st=$ROWST
			case $st in "Not started" | Skipped*) return ;; esac
			WHY="This stage has started." ;;
		*) WHY="The plan is past this stage." ;;
		esac
		return ;;
	esac
}

# effective <key>: sets EFF to on or off as the workflow will treat it
effective() {
	case $1 in
	requirements | scope | approach | design | whole-plan | signoff | breakdown) plan_off && { EFF=off; return; } ;;
	esac
	case $1 in build | requirements | design | signoff) EFF=on; return ;; esac
	if [ "$1" = explore ] && plan_off; then EFF=on; return; fi
	if is_off "$1"; then EFF=off; else EFF=on; fi
}

case $cmd in
show)
	for k in $KEYS; do
		lock_of "$k"; title_of "$k"; level_of "$k"; effective "$k"
		lock=0; [ -n "$WHY" ] && lock=1
		if [ "$tsv" = 1 ]; then
			printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$TITLE" "$LEVEL" "$EFF" "$lock" "$WHY"
		else
			mark="[x]"; [ "$EFF" = off ] && mark="[ ]"
			ind=""; [ "$LEVEL" = plan ] && ind="    "
			printf '%s%s %s%s\n' "$ind" "$mark" "$TITLE" "${WHY:+  ($WHY)}"
		fi
	done ;;
check)
	bad=0
	if [ -f "$profile" ]; then
		while IFS=$'\t' read -r k v; do
			k=${k%$'\r'}; v=${v%$'\r'}
			[ -n "$k" ] || continue
			if ! valid_key "$k"; then echo "unknown stage: $k"; bad=1; continue; fi
			case $v in on | off) ;; *) echo "$k: value must be on or off, not '$v'"; bad=1; continue ;; esac
			case $k in
			build | requirements | design | signoff) [ "$v" = off ] && { echo "$k cannot be left out"; bad=1; } ;;
			esac
		done <"$profile"
		if is_off plan && ! is_off breakdown || { ! is_off plan && is_off breakdown; }; then
			echo "plan and breakdown must both be on or both off"; bad=1
		fi
	fi
	[ $bad = 0 ] && echo "ok" || exit 1 ;;
set)
	k=$2; want=$3
	valid_key "$k" || { echo "stages.sh: unknown stage: $k" >&2; exit 1; }
	case $want in on | off) ;; *) usage; exit 2 ;; esac
	[ "$k" = breakdown ] && k=plan
	effective "$k"; cur=$EFF
	if [ "$cur" = "$want" ]; then echo "$k is already $want"; exit 0; fi
	lock_of "$k"; why=$WHY
	if [ -n "$why" ]; then echo "stages.sh: cannot turn $k $want: $why" >&2; exit 1; fi

	mkdir -p "$dir/.tt" || exit 1
	tmp="$profile.tmp.$$"
	{
		[ -f "$profile" ] && awk -F'\t' -v a="$k" '{ sub(/\r$/, "") } NF && $1 != a && !($1 == "breakdown" && a == "plan") { print }' "$profile"
		if [ "$want" = off ]; then
			printf '%s\toff\n' "$k"
			[ "$k" = plan ] && printf 'breakdown\toff\n'
		fi
	} >"$tmp"
	if [ -s "$tmp" ]; then mv "$tmp" "$profile"; else rm -f "$tmp" "$profile"; fi

	# keep the draft plan's Stages table in step (only the rows that can be left out)
	rowname=""
	case $k in explore | scope | approach | whole-plan) label_of "$k"; rowname=$LABEL ;; esac
	if [ -n "$rowname" ] && [ -n "$draft" ]; then
		if [ "$want" = off ]; then from="Not started"; to="Skipped: not selected"; else from="Skipped: not selected"; to="Not started"; fi
		tmp="$draft.tmp.$$"
		# Some awks drop the CR on reading, so note once whether the file is CRLF.
		crlf=0; [ "$(tr -cd '\r' <"$draft" | wc -c | tr -d ' ')" -gt 0 ] && crlf=1
		awk -F'|' -v OFS='|' -v want="$rowname" -v from="$from" -v to="$to" -v on_="$want" -v cr="$crlf" '
			{ sub(/\r$/, "") }
			/^\*\*Stages\*\*/ { on = 1 }
			on && /^\|/ {
				s = $2; t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
				if (s == want && (t == from || (on_ == "on" && t ~ /^Skipped/))) $3 = " " to " "
			}
			on && NF && !/^\|/ && !/^\*\*Stages\*\*/ { on = 0 }
			{ print $0 (cr ? "\r" : "") }' "$draft" >"$tmp" && cat "$tmp" >"$draft"
		rm -f "$tmp"
	fi
	echo "$k is now $want" ;;
skip-challenge)
	# Close a stage whose adversary challenge is pending without running it, on the engineer's say-so:
	# its Stages row becomes "Closed (challenge skipped: <reason>)", as tt-adversarial-plan records it.
	k=$2
	reason=$(printf '%s' "${3:-skipped by the engineer}" | tr -d '|\r\n')
	case $k in
	explore | requirements | scope | approach | design | whole-plan) ;;
	*) echo "stages.sh: $k has no challenge to skip" >&2; exit 1 ;;
	esac
	[ -n "$draft" ] || { echo "stages.sh: there is no draft plan: only a plan being drafted has challenges" >&2; exit 1; }
	label_of "$k"; rowname=$LABEL
	row_status "$rowname"
	[ "$ROWST" = "Challenge pending" ] || { echo "stages.sh: the challenge of $rowname is not pending (its row says: ${ROWST:-no such row})" >&2; exit 1; }
	if [ $CHECK = 1 ]; then echo "ok"; exit 0; fi
	tmp="$draft.tmp.$$"
	crlf=0; [ "$(tr -cd '\r' <"$draft" | wc -c | tr -d ' ')" -gt 0 ] && crlf=1
	awk -F'|' -v OFS='|' -v want="$rowname" -v to="Closed (challenge skipped: $reason)" -v cr="$crlf" '
		{ sub(/\r$/, "") }
		/^\*\*Stages\*\*/ { on = 1 }
		on && /^\|/ {
			s = $2; t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
			if (s == want && t == "Challenge pending") $3 = " " to " "
		}
		on && NF && !/^\|/ && !/^\*\*Stages\*\*/ { on = 0 }
		{ print $0 (cr ? "\r" : "") }' "$draft" >"$tmp" && cat "$tmp" >"$draft"
	rm -f "$tmp"
	echo "$k: challenge skipped" ;;
esac
