#!/usr/bin/env bash
# breaks.sh: the break points of a workflow, when the engineer answers them outside the chat.
# A skill that would stop and ask "Continue, or stop here?" (or "run the adversary challenge?")
# records the wait here instead, says so in one line and ends its turn; the engineer's answer is
# given with `answer` (by a person at a button, or by another program), and the skill reads it
# with `take` when it is next started. With TT_BREAK unset the skills ask in the chat as they
# always did and none of this is used. Needs bash and awk only. See tt-common/breaks.md.
set -u

usage() {
	cat >&2 <<'EOF'
usage: breaks.sh mode
       breaks.sh wait <folder> --kind challenge|stage|skill --step <step> --label <words>
                      [--prefix <Prefix>] [--skill <name>]
       breaks.sh show [--tsv] <folder>
       breaks.sh answer <folder> continue|skip|stop
       breaks.sh take <folder>
       breaks.sh clear <folder>

mode prints elsewhere when TT_BREAK=elsewhere (the engineer answers outside the chat), else chat.

wait records that the workflow is stopped at a break, in <folder>/.tt/break, and writes a
workflow.waiting event to the ledger (see tt-event.sh). kind says what comes next:
  challenge  the adversary challenge of a planning stage; step is the stage key
             (explore, requirements, scope, approach, design, whole-plan)
  stage      a stage of the workflow; step is its stage key (see stages.sh)
  skill      a skill that is about to run; step is its name (tt-task-breakdown, ...)
It works out whether the engineer may skip that step, and why not.

show prints the wait, or nothing when none is recorded. --tsv prints one line:
  waiting <kind> <step> <label> <skippable 1|0> <why> <answer>

answer records the engineer's choice. skip carries it out at once, by the owning script
(stages.sh skip-challenge, or stages.sh set <stage> off), and is refused (exit 1, the reason on
stderr) when the step can't be skipped. The skill takes it up when it is next started.

take prints what the engineer chose (continue, skip or stop) and removes the wait; prints
waiting while there is no answer yet (the wait stays), none when nothing is recorded.

clear removes a wait without an answer (the workflow went on another way).

Exit: 0 ok, 1 refused (reason on stderr), 2 usage error.
EOF
}

here=${0%[/\\]*}
[ "$here" = "$0" ] && here=.

die() { echo "breaks.sh: $1" >&2; exit "${2:-1}"; }

cmd=${1:-}
[ $# -gt 0 ] && shift

# one-line text: no tabs or line breaks
oneline() { printf '%s' "$1" | tr '\t\r\n' '   '; }

# rec_get <key>: the value of key in the wait record (empty when absent)
rec_get() { awk -v k="$1" '{ sub(/\r$/, "") } index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$rec"; }

# rec_put <key> <value>: set key in the wait record
rec_put() {
	local tmp="$rec.tmp.$$"
	awk -v k="$1" -v v="$2" '{ sub(/\r$/, "") } index($0, k "=") == 1 { print k "=" v; done = 1; next } { print } END { if (!done) print k "=" v }' "$rec" >"$tmp" && mv "$tmp" "$rec"
}

# the stage key a skill's work belongs to ("" when it has none that can be left out)
stage_of_skill() {
	case $1 in
	tt-familiarise | tt-familiarisation-doc) echo explore ;;
	tt-task-breakdown) echo breakdown ;;
	tt-execute | tt-execute-lite) echo build ;;
	tt-branch-review) echo review ;;
	*) echo "" ;;
	esac
}

# stage_skip <key>: sets SKIP (1|0) and WHY for leaving a stage out now
stage_skip() {
	local key=$1 row k l lv on lock why
	SKIP=0; WHY=""
	[ -n "$key" ] || { WHY="This step can't be skipped."; return; }
	row=$(bash "$here/stages.sh" show --tsv "$dir" 2>/dev/null | awk -F'\t' -v k="$key" '$1 == k { print; exit }')
	[ -n "$row" ] || { WHY="This step can't be skipped."; return; }
	IFS=$'\t' read -r k l lv on lock why <<<"$row"
	why=${why%$'\r'}
	if [ "$lock" = 1 ]; then WHY=$why; return; fi
	if [ "$on" = off ]; then WHY="It is already left out."; return; fi
	case $key in
	explore | scope | approach | whole-plan | review) SKIP=1 ;;
	*) WHY="This stage can't be left out." ;;
	esac
}

# can_skip <kind> <step>: sets SKIP and WHY
can_skip() {
	local err
	case $1 in
	challenge)
		SKIP=0; WHY=""
		if err=$(bash "$here/stages.sh" skip-challenge --check "$dir" "$2" 2>&1); then SKIP=1; else WHY=${err#stages.sh: }; fi ;;
	stage) stage_skip "$2" ;;
	skill) stage_skip "$(stage_of_skill "$2")" ;;
	esac
}

# emit_closed <stage key>: the ledger's plan.<stage>_closed event, for a challenge that was skipped
emit_closed() {
	local e
	case $1 in
	explore) e=familiarisation ;; whole-plan) e=whole ;; requirements | scope | approach | design) e=$1 ;; *) return 0 ;;
	esac
	bash "$here/tt-event.sh" emit "plan.${e}_closed" --prefix "$(rec_get prefix)" --folder "$dir" --skill tt-adversarial-plan >/dev/null 2>&1 || true
}

case $cmd in
-h | --help) usage; exit 0 ;;
mode)
	[ $# -eq 0 ] || { usage; exit 2; }
	case ${TT_BREAK:-chat} in elsewhere) echo elsewhere ;; *) echo chat ;; esac
	exit 0 ;;
wait | show | answer | take | clear) ;;
*) usage; exit 2 ;;
esac

tsv=0; kind=""; step=""; label=""; prefix=""; skill=""; choice=""
if [ "$cmd" = show ] && [ "${1:-}" = --tsv ]; then tsv=1; shift; fi
[ $# -ge 1 ] || { usage; exit 2; }
dir=${1%/}; [ -n "$dir" ] || dir=/
shift
[ -d "$dir" ] || die "no such folder: $dir" 2
rec="$dir/.tt/break"

case $cmd in
wait)
	while [ $# -gt 0 ]; do
		[ $# -ge 2 ] || { usage; exit 2; }
		case $1 in
		--kind) kind=$2 ;; --step) step=$2 ;; --label) label=$2 ;; --prefix) prefix=$2 ;; --skill) skill=$2 ;;
		*) usage; exit 2 ;;
		esac
		shift 2
	done
	case $kind in challenge | stage | skill) ;; *) usage; exit 2 ;; esac
	[ -n "$step" ] && [ -n "$label" ] || { usage; exit 2; }
	[ -n "$prefix" ] || prefix=$(basename "$dir")
	can_skip "$kind" "$step"
	mkdir -p "$dir/.tt" || die "can't write $dir/.tt"
	tmp="$rec.tmp.$$"
	{
		printf 'kind=%s\n' "$kind"
		printf 'step=%s\n' "$(oneline "$step")"
		printf 'label=%s\n' "$(oneline "$label")"
		printf 'skippable=%s\n' "$SKIP"
		printf 'why=%s\n' "$(oneline "$WHY")"
		printf 'prefix=%s\n' "$(oneline "$prefix")"
		printf 'skill=%s\n' "$(oneline "$skill")"
		printf 'answer=\n'
	} >"$tmp" && mv "$tmp" "$rec"
	bash "$here/tt-event.sh" emit workflow.waiting --prefix "$prefix" --folder "$dir" --qualifier "$kind:$step" ${skill:+--skill "$skill"} >/dev/null 2>&1 || true
	echo "waiting: $label" ;;
show)
	[ -f "$rec" ] || exit 0
	if [ $tsv = 1 ]; then
		printf 'waiting\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(rec_get kind)" "$(rec_get step)" "$(rec_get label)" "$(rec_get skippable)" "$(rec_get why)" "$(rec_get answer)"
	else
		echo "Waiting at a break: $(rec_get label) ($(rec_get kind): $(rec_get step))"
		if [ "$(rec_get skippable)" = 1 ]; then echo "It can be skipped."; else echo "It can't be skipped: $(rec_get why)"; fi
		[ -n "$(rec_get answer)" ] && echo "Answer: $(rec_get answer)"
	fi
	exit 0 ;;
answer)
	[ $# -eq 1 ] || { usage; exit 2; }
	choice=$1
	case $choice in continue | skip | stop) ;; *) usage; exit 2 ;; esac
	[ -f "$rec" ] || die "nothing is waiting at a break in $dir"
	[ -z "$(rec_get answer)" ] || die "already answered: $(rec_get answer)"
	if [ "$choice" = skip ]; then
		[ "$(rec_get skippable)" = 1 ] || die "can't skip: $(rec_get why)"
		kind=$(rec_get kind); step=$(rec_get step)
		case $kind in
		challenge)
			bash "$here/stages.sh" skip-challenge "$dir" "$step" "skipped by the engineer" >/dev/null || die "couldn't skip the challenge of $step"
			emit_closed "$step" ;;
		stage) bash "$here/stages.sh" set "$dir" "$step" off >/dev/null || die "couldn't leave $step out" ;;
		skill)
			key=$(stage_of_skill "$step")
			bash "$here/stages.sh" set "$dir" "$key" off >/dev/null || die "couldn't leave $step out" ;;
		esac
	fi
	rec_put answer "$choice"
	echo "answered: $choice" ;;
take)
	[ -f "$rec" ] || { echo none; exit 0; }
	a=$(rec_get answer)
	if [ -z "$a" ]; then echo waiting; exit 0; fi
	rm -f "$rec"
	echo "$a" ;;
clear)
	rm -f "$rec"
	echo cleared ;;
esac
