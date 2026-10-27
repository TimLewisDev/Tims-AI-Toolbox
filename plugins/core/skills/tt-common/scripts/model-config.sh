#!/usr/bin/env bash
# model-config.sh: which model and thinking effort each tt-* stage uses, and
# the named modes that hold a set of choices. Used by the skills at spawn time
# (`get`) and by tt-config (everything else). Needs bash and awk only.
# State lives in ~/.claude/tt-config (override with TT_CONFIG_DIR), never in git.
set -u

usage() {
	cat >&2 <<'EOF'
usage: model-config.sh get <role>                    model=<m> effort=<e> for the active mode
       model-config.sh list [--mode <name>] [--tsv]  the ranked table, highest value first (--tsv: one row per role
                                                     for a program: role kind tier used-by label model effort
                                                     default-model default-effort)
       model-config.sh set <role> <model> <effort>   change one role in the active mode
       model-config.sh modes                         list modes; * marks the active one
       model-config.sh use <mode>                    make a mode the active one
       model-config.sh save <name> [--force]         snapshot the active mode as a new mode and switch to it
       model-config.sh reset <mode>                  drop your edits to a shipped mode
       model-config.sh delete <mode>                 delete a mode you saved
       model-config.sh stage-note <skill>            one line for a main-thread stage, if configured
       model-config.sh args [--model m] [--effort e]  the flags that start claude on that model and effort
                                                     (values left out come from the `session` role)
       model-config.sh status                        active mode, changes, warnings

model: sonnet | opus | haiku | fable | -     effort: low | medium | high | xhigh | max | -
"-" leaves the choice to the session. Roles are in tt-common/model-roles.tsv.
The models offered are the runnable ones of the connected LLMs (tt-connections: llms.sh models);
without that script, the Claude aliases above.
TT_CONFIG_DIR overrides the state folder (default ~/.claude/tt-config).
Exit: 0 ok, 1 nothing to report / refused, 2 usage or environment error.
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
common=$(dirname "$here")
REG="$common/model-roles.tsv"
SHIPPED="$common/modes"
CFG="${TT_CONFIG_DIR:-$HOME/.claude/tt-config}"
USERMODES="$CFG/modes"
MODELS="sonnet opus haiku fable -"
EFFORTS="low medium high xhigh max -"
DEFAULT_MODE=recommended

die() { echo "model-config: $*" >&2; exit 2; }
in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# The models a skill can use come from the connected LLMs (tt-connections'
# llms.sh); when that script isn't there, the Claude aliases above stand in.
. "$here/tt-path.sh"
LLMS=""
if conn=$(tt_find tt-connections) && [ -f "$conn/scripts/llms.sh" ]; then LLMS="$conn/scripts/llms.sh"; fi

# runnable_rows: provider, id, label, efforts, runnable, one per line
runnable_rows() {
	[ -n "$LLMS" ] && bash "$LLMS" models --runnable --tsv 2>/dev/null | tr -d '\r' | awk -F'\t' 'NF >= 5' && return 0
	return 1
}

# model_ids: the ids that may be set, "-" included
model_ids() {
	local ids
	ids=$(runnable_rows | awk -F'\t' '{ printf "%s ", $2 }') || ids=""
	[ -n "$ids" ] && echo "$ids-" || echo "$MODELS"
}

# effort_list <model>: the efforts that model accepts, "-" included
effort_list() {
	local e=""
	[ "$1" != "-" ] && e=$(runnable_rows | awk -F'\t' -v m="$1" '$2 == m && $4 != "-" { gsub(/,/, " ", $4); print $4; exit }')
	[ -n "$e" ] && echo "$e -" || echo "$EFFORTS"
}

[ -f "$REG" ] || die "role registry not found: $REG"

active_mode() {
	local m=""
	[ -f "$CFG/active" ] && m=$(tr -d '\r\n' <"$CFG/active")
	[ -n "$m" ] && mode_exists "$m" || m=$DEFAULT_MODE
	echo "$m"
}
shipped_file() { echo "$SHIPPED/$1.tsv"; }
user_file() { echo "$USERMODES/$1.tsv"; }
mode_exists() { [ -f "$(shipped_file "$1")" ] || [ -f "$(user_file "$1")" ]; }
valid_name() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9_-]*$'; }

# resolve <mode>: one row per role, ordered by tier:
#   role kind tier used-by label model effort default-model default-effort
resolve() {
	local mode=$1 sf uf
	sf=$(shipped_file "$mode"); uf=$(user_file "$mode")
	{
		[ -f "$sf" ] && sed 's/\r$//; s/^/S\t/' "$sf"
		[ -f "$uf" ] && sed 's/\r$//; s/^/S\t/' "$uf"
		sed 's/\r$//; s/^/R\t/' "$REG"
	} | awk -F'\t' -v OFS='\t' '
		$2 ~ /^#/ || $2 == "" { next }
		$1 == "S" { m[$2] = $3; e[$2] = $4; next }
		$1 == "R" {
			role = $2
			mo = (role in m) ? m[role] : $7
			ef = (role in e) ? e[role] : $8
			print role, $3, $4, $5, $6, mo, ef, $7, $8
		}' | sort -s -t "$(printf '\t')" -k3,3n
}

cmd_get() {
	[ $# -eq 1 ] || { usage; exit 2; }
	local row
	row=$(resolve "$(active_mode)" | awk -F'\t' -v r="$1" '$1 == r { print "model=" $6 " effort=" $7; found = 1 } END { exit !found }') ||
		die "unknown role '$1' (see tt-common/model-roles.tsv)"
	echo "$row"
}

cmd_list() {
	local mode tsv=0
	mode=$(active_mode)
	while [ $# -gt 0 ]; do
		case $1 in
		--mode) [ -n "${2:-}" ] && mode_exists "$2" || die "unknown mode '${2:-}'"; mode=$2; shift ;;
		--tsv) tsv=1 ;;
		*) usage; exit 2 ;;
		esac
		shift
	done
	# --tsv: one row per role, tab-separated, for a program to read:
	# role kind tier used-by label model effort default-model default-effort
	[ $tsv -eq 1 ] && { resolve "$mode"; return 0; }
	echo "Mode: $mode"
	resolve "$mode" | awk -F'\t' '
		BEGIN { printf "  %-4s %-20s %-9s %-8s %-7s %s\n", "Tier", "Role", "Kind", "Model", "Effort", "Used by" }
		{
			ch = ($6 != $8 || $7 != $9) ? "*" : " "
			kind = ($2 == "main") ? "advisory" : "subagent"
			printf "%s %-4s %-20s %-9s %-8s %-7s %s\n", ch, $3, $1, kind, $6, $7, $4
		}
		END { print "\n* = differs from the recommended defaults. advisory = runs in your session: set with /model and /effort." }'
}

write_override() { # write_override <file> <role> <model> <effort>
	local f=$1 tmp
	mkdir -p "$(dirname "$f")" || die "cannot create $(dirname "$f")"
	tmp=$(mktemp "$f.XXXXXX") || die "cannot write $f"
	{
		[ -f "$f" ] && awk -F'\t' -v r="$2" '$1 != r' "$f"
		printf '%s\t%s\t%s\n' "$2" "$3" "$4"
	} >"$tmp" && mv "$tmp" "$f"
}

# check_pair <model> <effort>: exit 2 unless both are allowed together
check_pair() {
	local ids efforts
	ids=$(model_ids); efforts=$(effort_list "$1")
	in_list "$1" "$ids" || die "model must be one of: $ids"
	in_list "$2" "$efforts" || die "effort for '$1' must be one of: $efforts"
}

# cmd_args [--model m] [--effort e]: the flags that start claude on a model and
# effort, e.g. `--model opus --effort high`. A value left out comes from the
# `session` role; "-" or nothing leaves that flag off (the session decides).
cmd_args() {
	local m e row
	row=$(resolve "$(active_mode)" | awk -F'\t' '$1 == "session" { print $6 "\t" $7 }')
	m=${row%%$'\t'*}; e=${row##*$'\t'}
	[ -n "$row" ] || { m="-"; e="-"; }
	while [ $# -gt 0 ]; do
		case $1 in
		--model) [ $# -ge 2 ] || { usage; exit 2; }; m=$2; shift ;;
		--effort) [ $# -ge 2 ] || { usage; exit 2; }; e=$2; shift ;;
		*) usage; exit 2 ;;
		esac
		shift
	done
	[ -n "$m" ] || m="-"; [ -n "$e" ] || e="-"
	check_pair "$m" "$e"
	local out=""
	[ "$m" = "-" ] || out="--model $m"
	[ "$e" = "-" ] || out="${out:+$out }--effort $e"
	[ -z "$out" ] || printf '%s\n' "$out"
}

cmd_set() {
	[ $# -eq 3 ] || { usage; exit 2; }
	local role=$1 model=$2 effort=$3 mode
	awk -F'\t' -v r="$role" '$1 !~ /^#/ && $1 == r { f = 1 } END { exit !f }' "$REG" || die "unknown role '$role'"
	check_pair "$model" "$effort"
	mode=$(active_mode)
	write_override "$(user_file "$mode")" "$role" "$model" "$effort"
	echo "set $role: model=$model effort=$effort (mode $mode)"
}

cmd_modes() {
	local active n s u
	active=$(active_mode)
	{
		for f in "$SHIPPED"/*.tsv "$USERMODES"/*.tsv; do
			[ -f "$f" ] && basename "$f" .tsv
		done
	} | sort -u | while read -r n; do
		s=""; u=""
		[ -f "$(shipped_file "$n")" ] && s=1
		[ -f "$(user_file "$n")" ] && u=1
		if [ -n "$s" ] && [ -n "$u" ]; then k="shipped, edited"
		elif [ -n "$s" ]; then k="shipped"
		else k="saved"; fi
		printf '%s %s (%s)\n' "$([ "$n" = "$active" ] && echo '*' || echo ' ')" "$n" "$k"
	done
}

cmd_use() {
	[ $# -eq 1 ] || { usage; exit 2; }
	mode_exists "$1" || die "unknown mode '$1' (model-config.sh modes)"
	mkdir -p "$CFG" && printf '%s\n' "$1" >"$CFG/active" || die "cannot write $CFG/active"
	echo "active mode: $1"
}

cmd_save() {
	[ $# -ge 1 ] || { usage; exit 2; }
	local name=$1 force=0 src
	[ "${2:-}" = "--force" ] && force=1
	valid_name "$name" || die "mode names are lowercase letters, digits, - and _"
	if [ $force -eq 0 ] && mode_exists "$name"; then
		echo "model-config: mode '$name' already exists (use --force to replace it)" >&2
		exit 1
	fi
	[ -f "$(shipped_file "$name")" ] && die "'$name' is a shipped mode name; pick another"
	src=$(active_mode)
	mkdir -p "$USERMODES" || die "cannot create $USERMODES"
	{
		echo "# saved from $src. Overrides only: role, model, effort."
		resolve "$src" | awk -F'\t' -v OFS='\t' '$6 != $8 || $7 != $9 { print $1, $6, $7 }'
	} >"$(user_file "$name")"
	# A shipped mode stays as shipped: drop edits made to it, they now live in the new mode.
	[ -f "$(shipped_file "$src")" ] && rm -f "$(user_file "$src")"
	printf '%s\n' "$name" >"$CFG/active"
	echo "saved mode: $name (from $src); active mode: $name"
}

cmd_reset() {
	[ $# -eq 1 ] || { usage; exit 2; }
	[ -f "$(shipped_file "$1")" ] || die "'$1' is not a shipped mode; use delete"
	if [ -f "$(user_file "$1")" ]; then rm -f "$(user_file "$1")"; echo "reset $1 to its shipped values"
	else echo "$1 has no edits"; fi
}

cmd_delete() {
	[ $# -eq 1 ] || { usage; exit 2; }
	[ -f "$(shipped_file "$1")" ] && die "'$1' is a shipped mode; use reset to drop your edits"
	[ -f "$(user_file "$1")" ] || die "no saved mode '$1'"
	rm -f "$(user_file "$1")"
	[ -f "$CFG/active" ] && [ "$(tr -d '\r\n' <"$CFG/active")" = "$1" ] && printf '%s\n' "$DEFAULT_MODE" >"$CFG/active"
	echo "deleted mode: $1"
}

cmd_stage_note() {
	[ $# -eq 1 ] || { usage; exit 2; }
	local mode row m e cmds=""
	mode=$(active_mode)
	row=$(resolve "$mode" | awk -F'\t' -v r="$1" '$1 == r && $2 == "main" { print $6 "\t" $7 }')
	[ -n "$row" ] || exit 0
	m=${row%%$'\t'*}; e=${row##*$'\t'}
	[ "$m" = "-" ] && [ "$e" = "-" ] && exit 0
	[ "$m" != "-" ] && cmds="/model $m"
	[ "$e" != "-" ] && cmds="${cmds:+$cmds and }/effort $e"
	echo "Configured for this stage (mode $mode): model ${m/#-/session default}, effort ${e/#-/session default}. To match, run $cmds."
}

cmd_status() {
	local mode kind changed opus settings=~/.claude/settings.json bedrock="" alias=""
	mode=$(active_mode)
	if [ -f "$(shipped_file "$mode")" ] && [ -f "$(user_file "$mode")" ]; then kind="shipped, edited"
	elif [ -f "$(shipped_file "$mode")" ]; then kind="shipped"
	else kind="saved"; fi
	changed=$(resolve "$mode" | awk -F'\t' '$6 != $8 || $7 != $9' | wc -l | tr -d ' ')
	echo "active mode: $mode ($kind)"
	echo "roles differing from the recommended defaults: $changed"
	opus=$(resolve "$mode" | awk -F'\t' '$2 == "sub" && $6 == "opus" { printf "%s%s", s, $1; s = ", " }')
	[ -n "$opus" ] && echo "subagent roles on opus: $opus"
	if [ -n "$opus" ]; then
		[ "${CLAUDE_CODE_USE_BEDROCK:-}" = 1 ] && bedrock=1
		[ -f "$settings" ] && grep -q '"CLAUDE_CODE_USE_BEDROCK"[[:space:]]*:[[:space:]]*"1"' "$settings" && bedrock=1
		[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ] && alias=1
		[ -f "$settings" ] && grep -q '"ANTHROPIC_DEFAULT_OPUS_MODEL"' "$settings" && alias=1
		if [ -n "$bedrock" ] && [ -z "$alias" ]; then
			echo "warning: this looks like Bedrock and ANTHROPIC_DEFAULT_OPUS_MODEL is not set, so the 'opus' alias may not resolve."
			echo "         Set it in the env block of ~/.claude/settings.json to a model ID your account serves (e.g. us.anthropic.claude-opus-5-5)."
			echo "         If an opus subagent fails to start, the skills re-run it on the session model."
		fi
	fi
	return 0
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case "$cmd" in
	get) cmd_get "$@" ;;
	list) cmd_list "$@" ;;
	set) cmd_set "$@" ;;
	modes) cmd_modes ;;
	use) cmd_use "$@" ;;
	save) cmd_save "$@" ;;
	reset) cmd_reset "$@" ;;
	delete) cmd_delete "$@" ;;
	stage-note) cmd_stage_note "$@" ;;
	args) cmd_args "$@" ;;
	status) cmd_status ;;
	-h | --help | help | "") usage; [ -n "$cmd" ] && exit 0 || exit 2 ;;
	*) usage; exit 2 ;;
esac
