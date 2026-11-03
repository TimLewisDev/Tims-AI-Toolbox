#!/usr/bin/env bash
# stages.sh: which stages a feature's workflow includes. Keeps a small profile in
# the feature folder and is the only writer of it. Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: stages.sh show [--tsv] <folder>
       stages.sh set <folder> <stage> on|off
       stages.sh check <folder>

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

show --tsv prints, per stage: key label level on locked why
  level: top, or plan for the planning stages (their parent is Plan)
  on: on or off (off while Plan is off); locked: 1 or 0; why: the reason if locked

Exit: 0 ok, 1 refused or findings, 2 usage error.
EOF
}

here=$(cd "$(dirname "$0")" && pwd)
KEYS="explore plan requirements scope approach design whole-plan signoff breakdown build review"

label_of() {
	case $1 in
	explore) echo "Familiarisation" ;;
	plan) echo "Plan" ;;
	requirements) echo "Requirements" ;;
	scope) echo "Scope & Constraints" ;;
	approach) echo "Approach" ;;
	design) echo "Technical Design" ;;
	whole-plan) echo "Whole plan" ;;
	signoff) echo "Sign-off" ;;
	breakdown) echo "Task Breakdown" ;;
	build) echo "Build" ;;
	review) echo "Review" ;;
	esac
}
# the name shown to a person for a top-level row
title_of() { case $1 in explore) echo "Explore" ;; *) label_of "$1" ;; esac; }
level_of() { case $1 in requirements | scope | approach | design | whole-plan | signoff) echo plan ;; *) echo top ;; esac; }
valid_key() { case " $KEYS " in *" $1 "*) return 0 ;; esac; return 1; }

cmd=${1:-}
[ $# -gt 0 ] && shift
tsv=0
if [ "$cmd" = show ] && [ "${1:-}" = --tsv ]; then tsv=1; shift; fi
case $cmd in -h | --help) usage; exit 0 ;; show | check) [ $# -eq 1 ] || { usage; exit 2; } ;; set) [ $# -eq 3 ] || { usage; exit 2; } ;; *) usage; exit 2 ;; esac
dir=$1; [ "${dir%/}" != "" ] && dir=${dir%/}
[ -d "$dir" ] || { echo "stages.sh: no such folder: $dir" >&2; exit 2; }
profile="$dir/.tt/workflow-stages.tsv"

# is_off <key>: the profile leaves the stage out
is_off() { [ -f "$profile" ] && awk -F'\t' -v k="$1" '{ sub(/\r$/, "") } $1 == k && $2 == "off" { f = 1 } END { exit !f }' "$profile"; }

# phase: where the folder's documents stand (workflow-state.sh's first primary row)
phase=$(bash "$here/workflow-state.sh" --tsv "$dir" 2>/dev/null | awk -F'\t' '$2 == "primary" { print $3; exit }')
[ -n "$phase" ] || phase=empty

# the draft plan, if there is one
draft=""
for f in "$dir"/*" - Comprehensive Tech Plan.md"; do
	[ -f "$f" ] || continue
	if awk '{ sub(/\r$/, "") } /Status:/ { if ($0 ~ /Draft/) f = 1; exit } END { exit !f }' "$f"; then draft=$f; break; fi
done

# row_status <stage name>: the Status cell of that Stages row in the draft plan
row_status() {
	[ -n "$draft" ] || return 0
	awk -F'|' -v want="$1" '{ sub(/\r$/, "") }
		/^\*\*Stages\*\*/ { on = 1; next }
		on && /^\|/ { s = $2; t = $3; gsub(/^ +| +$/, "", s); gsub(/^ +| +$/, "", t)
			if (s == want) { print t; exit }; next }
		on && NF && !/^\|/ { exit }' "$draft"
}

plan_off() { is_off plan; }

# lock_of <key>: the reason the stage cannot change now; empty when it can
lock_of() {
	local k=$1 st
	case $k in
	build) echo "Build is always part of the workflow."; return ;;
	requirements | design | signoff) echo "Always included: the breakdown depends on what this stage writes."; return ;;
	esac
	[ "$k" = review ] && return
	case $phase in building | complete) echo "Building has started."; return ;; esac
	case $k in
	plan | breakdown)
		[ "$phase" = empty ] || echo "Work has started; the route cannot change now."
		return ;;
	explore)
		if plan_off; then echo "The lite route always explores."; return; fi
		case $phase in
		empty) return ;;
		planning)
			st=$(row_status Familiarisation)
			case $st in "Not started" | Skipped*) return ;; esac
			echo "Familiarisation has started." ;;
		*) echo "Familiarisation has started." ;;
		esac
		return ;;
	scope | approach | whole-plan)
		if plan_off; then echo "Off with Plan (the lite route has no planning stages)."; return; fi
		case $phase in
		empty | exploring | explored) return ;;
		planning)
			st=$(row_status "$(label_of "$k")")
			case $st in "Not started" | Skipped*) return ;; esac
			echo "This stage has started." ;;
		*) echo "The plan is past this stage." ;;
		esac
		return ;;
	esac
}

# effective <key>: on or off as the workflow will treat it
effective() {
	case $1 in
	requirements | scope | approach | design | whole-plan | signoff | breakdown) plan_off && { echo off; return; } ;;
	esac
	case $1 in build | requirements | design | signoff) echo on; return ;; esac
	if [ "$1" = explore ] && plan_off; then echo on; return; fi
	is_off "$1" && echo off || echo on
}

case $cmd in
show)
	for k in $KEYS; do
		why=$(lock_of "$k"); lock=0; [ -n "$why" ] && lock=1
		if [ "$tsv" = 1 ]; then
			printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$(title_of "$k")" "$(level_of "$k")" "$(effective "$k")" "$lock" "$why"
		else
			mark="[x]"; [ "$(effective "$k")" = off ] && mark="[ ]"
			ind=""; [ "$(level_of "$k")" = plan ] && ind="    "
			printf '%s%s %s%s\n' "$ind" "$mark" "$(title_of "$k")" "${why:+  ($why)}"
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
	cur=$(effective "$k")
	if [ "$cur" = "$want" ]; then echo "$k is already $want"; exit 0; fi
	why=$(lock_of "$k")
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
	case $k in explore | scope | approach | whole-plan) rowname=$(label_of "$k") ;; esac
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
esac
