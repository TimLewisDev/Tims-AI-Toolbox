#!/usr/bin/env bash
# llms.sh: which LLM command-line tools are connected (claude, copilot, codex)
# and which models they offer. The connections are machine-wide, not per
# project. Models are generated from each tool's own --help (and from any
# lines you add in models.d/, and for Claude from claude-models.tsv, the
# specific versions kept by hand). Needs bash and awk only.
# It never signs in or handles a token: sign-in is the tool's own.
set -u

usage() {
	cat >&2 <<'EOF'
usage: llms.sh status [--tsv]                      each provider: connected, available, missing or not installed
       llms.sh connect <provider>                  connect an installed tool and generate its models
       llms.sh disconnect <provider>               forget a connection and its models (claude stays connected)
       llms.sh refresh [provider]                  generate the models again for the connected tools
       llms.sh models [--runnable] [--tsv] [--provider <p>]
                                                   the models of the connected tools
       llms.sh versions [<family>] [--tsv]         claude's specific versions by family (sonnet, opus, haiku,
                                                   fable), newest first, for the backend in use: family, label, id

providers: claude | copilot | codex
A model is runnable when a tt-* skill can use it for a subagent. Only claude
models are runnable today; the others are listed so they can be picked later.
Claude's models are its aliases (sonnet, opus, haiku, fable), each followed by
its specific versions (claude-models.tsv, next to scripts/; Bedrock ids when
Claude Code runs on Bedrock). A version has scope "session": `claude --model`
takes it, but the Agent tool, so a tt-* subagent, takes aliases only.
Extra models for a provider go in <home>/models.d/<provider>.tsv, one per line:
  <id> TAB <label> TAB <efforts, comma separated or -> TAB <yes|no> TAB <session, optional>

State lives in ${TT_LLMS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-llms}
TT_CLAUDE_BIN, TT_COPILOT_BIN and TT_CODEX_BIN name the executables.
--tsv output: models: provider, id, label, efforts, runnable, scope (any | session);
              status: provider, state, version, models, runnable models.
Exit: 0 ok, 1 refused or not installed, 2 usage error.
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
home=${TT_LLMS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-llms}
conns="$home/connections.tsv"
modelsf="$home/models.tsv"
extras="$home/models.d"
PROVIDERS="claude copilot codex"
DEFAULT_EFFORTS="low,medium,high,xhigh,max"
TAB=$'\t'

die() { echo "llms.sh: $*" >&2; exit 2; }
valid_provider() { case " $PROVIDERS " in *" $1 "*) return 0 ;; esac; return 1; }

# bin_name <provider>: the executable to look for
bin_name() {
	case $1 in
	claude) echo "${TT_CLAUDE_BIN:-claude}" ;;
	copilot) echo "${TT_COPILOT_BIN:-copilot}" ;;
	codex) echo "${TT_CODEX_BIN:-codex}" ;;
	esac
}

# bin_path <provider>: the executable's path, or return 1
bin_path() { command -v "$(bin_name "$1")" 2>/dev/null; }

# is_connected <provider>: claude always is (it hosts the skills); the others when connected
is_connected() {
	[ "$1" = claude ] && return 0
	[ -f "$conns" ] && awk -F'\t' -v p="$1" '{ sub(/\r$/, "") } $1 == p && $2 == 1 { f = 1 } END { exit !f }' "$conns"
}

conn_field() { # conn_field <provider> <column>
	[ -f "$conns" ] && awk -F'\t' -v p="$1" -v c="$2" '{ sub(/\r$/, "") } $1 == p { print $c; exit }' "$conns"
}

set_conn() { # set_conn <provider> <enabled> <bin> <version>
	local tmp
	mkdir -p "$home" || die "cannot create $home"
	tmp=$(mktemp "$conns.XXXXXX") || die "cannot write $conns"
	{
		[ -f "$conns" ] && awk -F'\t' -v p="$1" '{ sub(/\r$/, "") } $1 != p' "$conns"
		printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$(date +%F)"
	} >"$tmp" && mv "$tmp" "$conns"
}

tool_version() { "$1" --version 2>/dev/null </dev/null | tr -d '\r' | head -1; }

# help_choices <bin> <flag>: the values a flag lists in --help, space separated.
# Reads `(choices: "a", "b")` and `(a, b, c)` after the flag, up to 3 lines.
help_choices() {
	"$1" --help 2>/dev/null </dev/null | awk -v f="$2" '
		{ sub(/\r$/, "") }
		!on && index($0, f) { on = 1 }
		on && n < 3 { buf = buf " " $0; n++ }
		END {
			s = ""
			if (match(buf, /choices: *[^)]*/)) s = substr(buf, RSTART + 8, RLENGTH - 8)
			else if (match(buf, /\([a-z0-9_.-]+(, *[a-z0-9_.-]+)+\)/)) s = substr(buf, RSTART + 1, RLENGTH - 2)
			gsub(/["\047,]/, " ", s); gsub(/ +/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
			print s
		}'
}

# alias_target <alias>: the model id an alias resolves to through
# ANTHROPIC_DEFAULT_<ALIAS>_MODEL (env, then ~/.claude/settings.json), if set
alias_target() {
	local var v settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
	var="ANTHROPIC_DEFAULT_$(printf '%s' "$1" | tr 'a-z' 'A-Z')_MODEL"
	v=${!var:-}
	if [ -z "$v" ] && [ -f "$settings" ]; then
		v=$(sed -n "s/.*\"$var\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$settings" | head -1)
	fi
	printf '%s\n' "$v"
}

csv() { echo "$*" | tr ' ' ','; }

# on_bedrock: Claude Code is set to run on Amazon Bedrock (env, then settings.json)
on_bedrock() {
	# the environment decides when it says (Claude Code sets it from settings.json itself)
	[ -n "${CLAUDE_CODE_USE_BEDROCK+x}" ] && { [ "$CLAUDE_CODE_USE_BEDROCK" = 1 ]; return; }
	local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
	[ -f "$settings" ] && grep -q '"CLAUDE_CODE_USE_BEDROCK"[[:space:]]*:[[:space:]]*"\{0,1\}1' "$settings"
}

# versions_of <family>: the pinned versions of a family from claude-models.tsv, as
# `label TAB id` for the backend in use (rows with no id there are left out)
versions_of() {
	local list="$here/../claude-models.tsv" col=3
	[ -f "$list" ] || return 0
	on_bedrock && col=4
	awk -F'\t' -v OFS='\t' -v f="$1" -v c=$col '
		{ sub(/\r$/, "") }
		/^#/ || $1 != f { next }
		$c != "" && $c != "-" { print $2, $c }' "$list"
}

# gen_claude: claude has no model list command, so the models are its aliases,
# each followed by its specific versions (claude-models.tsv). The sixth column is
# the scope: an alias is "any" (a session or a subagent can use it); a version is
# "session" (only `claude --model` takes it, the Agent tool takes aliases only).
gen_claude() {
	local bin eff a t label vl vid
	eff=$DEFAULT_EFFORTS
	if bin=$(bin_path claude); then
		e=$(help_choices "$bin" --effort)
		[ -n "$e" ] && eff=$(csv "$e")
	fi
	for a in sonnet opus haiku fable; do
		t=$(alias_target "$a")
		label=$a
		[ -n "$t" ] && label="$a ($t)"
		printf 'claude\t%s\t%s\t%s\tyes\tany\n' "$a" "$label" "$eff"
		versions_of "$a" | while IFS=$'\t' read -r vl vid; do
			printf 'claude\t%s\t%s\t%s\tyes\tsession\n' "$vid" "$vl" "$eff"
		done
	done
}

# gen_other <provider>: the models the tool's --help lists for --model, if any
gen_other() {
	local p=$1 bin ms eff m e
	bin=$(bin_path "$p") || return 0
	ms=$(help_choices "$bin" --model)
	eff="-"
	for f in --reasoning-effort --effort; do
		e=$(help_choices "$bin" "$f")
		[ -n "$e" ] && { eff=$(csv "$e"); break; }
	done
	for m in $ms; do printf '%s\t%s\t%s\t%s\tno\tany\n' "$p" "$m" "$m" "$eff"; done
}

# extra_rows <provider>: lines from models.d/<provider>.tsv as full model rows;
# an optional fifth column "session" marks a model only a session can use
extra_rows() {
	[ -f "$extras/$1.tsv" ] || return 0
	awk -F'\t' -v OFS='\t' -v p="$1" '
		{ sub(/\r$/, "") }
		/^#/ || $1 == "" { next }
		{ print p, $1, ($2 == "" ? $1 : $2), ($3 == "" ? "-" : $3), (p == "claude" && $4 == "" ? "yes" : ($4 == "yes" ? "yes" : "no")), ($5 == "session" ? "session" : "any") }' "$extras/$1.tsv"
}

# refresh_one <provider>: replace its rows in models.tsv
refresh_one() {
	local p=$1 tmp
	mkdir -p "$home" || die "cannot create $home"
	tmp=$(mktemp "$modelsf.XXXXXX") || die "cannot write $modelsf"
	{
		[ -f "$modelsf" ] && awk -F'\t' -v p="$p" '{ sub(/\r$/, "") } $1 != p' "$modelsf"
		if [ "$p" = claude ]; then gen_claude; else gen_other "$p"; fi
	} >"$tmp" && mv "$tmp" "$modelsf"
}

# ensure_claude: models.tsv always has claude's rows, even before anyone connects.
# Rows from before the scope column (five fields) are generated again.
ensure_claude() {
	[ -f "$modelsf" ] && awk -F'\t' '$1 == "claude" { f = 1; if (NF < 6) old = 1 } END { exit !(f && !old) }' "$modelsf" && return 0
	refresh_one claude
}

# all_models: generated rows plus models.d rows of the connected providers, once per provider+id.
# Six columns: provider, id, label, efforts, runnable, scope (any | session).
all_models() {
	local p
	ensure_claude
	{
		for p in $PROVIDERS; do
			is_connected "$p" || continue
			[ -f "$modelsf" ] && awk -F'\t' -v OFS='\t' -v p="$p" '{ sub(/\r$/, "") } $1 == p { if (NF < 6) $6 = "any"; print }' "$modelsf"
			extra_rows "$p"
		done
	} | awk -F'\t' '!seen[$1 FS $2]++'
}

cmd_models() {
	local runnable=0 tsv=0 prov=""
	while [ $# -gt 0 ]; do
		case $1 in
		--runnable) runnable=1 ;;
		--tsv) tsv=1 ;;
		--provider) shift; [ $# -ge 1 ] && valid_provider "$1" || die "--provider needs claude, copilot or codex"; prov=$1 ;;
		*) usage; exit 2 ;;
		esac
		shift
	done
	all_models | awk -F'\t' -v OFS='\t' -v r=$runnable -v p="$prov" -v tsv=$tsv '
		(r && $5 != "yes") || (p != "" && $1 != p) { next }
		tsv { print; next }
		{
			if (!n++) printf "%-9s %-22s %-32s %-26s %s\n", "Provider", "Id", "Label", "Efforts", "Runnable"
			printf "%-9s %-22s %-32s %-26s %s\n", $1, $2, $3, $4, $5
		}
		END { if (!n && !tsv) print (p != "" ? "No models found in " p "'"'"'s --help. Add some in models.d/" p ".tsv." : "No models yet. Connect a tool: llms.sh connect <provider>") }'
}

cmd_versions() {
	local tsv=0 fam="" list="$here/../claude-models.tsv" col=3
	while [ $# -gt 0 ]; do
		case $1 in
		--tsv) tsv=1 ;;
		sonnet | opus | haiku | fable) fam=$1 ;;
		*) usage; exit 2 ;;
		esac
		shift
	done
	[ -f "$list" ] || return 0
	on_bedrock && col=4
	awk -F'\t' -v OFS='\t' -v f="$fam" -v c=$col -v tsv=$tsv '
		{ sub(/\r$/, "") }
		/^#/ || $1 == "" || (f != "" && $1 != f) { next }
		$c != "" && $c != "-" { if (tsv) print $1, $2, $c; else printf "%-7s %-14s %s\n", $1, $2, $c }' "$list"
}

cmd_status() {
	local tsv=0 p state ver bin n r
	[ "${1:-}" = "--tsv" ] && tsv=1
	ensure_claude
	[ $tsv -eq 1 ] || printf '%-9s %-14s %-24s %s\n' "Provider" "State" "Version" "Models (runnable)"
	for p in $PROVIDERS; do
		bin=$(bin_path "$p") || bin=""
		if is_connected "$p"; then
			if [ -n "$bin" ]; then state=connected; else state=missing; fi
		else
			if [ -n "$bin" ]; then state=available; else state="not installed"; fi
		fi
		ver=""
		[ -n "$bin" ] && ver=$(conn_field "$p" 4)
		[ -z "$ver" ] && [ -n "$bin" ] && ver=$(tool_version "$bin")
		n=0; r=0
		if is_connected "$p"; then
			n=$(all_models | awk -F'\t' -v p="$p" '$1 == p' | wc -l | tr -d ' ')
			r=$(all_models | awk -F'\t' -v p="$p" '$1 == p && $5 == "yes"' | wc -l | tr -d ' ')
		fi
		if [ $tsv -eq 1 ]; then printf '%s\t%s\t%s\t%s\t%s\n' "$p" "$state" "$ver" "$n" "$r"
		else printf '%-9s %-14s %-24s %s (%s)\n' "$p" "$state" "${ver:--}" "$n" "$r"; fi
	done
	return 0
}

cmd_connect() {
	[ $# -eq 1 ] && valid_provider "$1" || { usage; exit 2; }
	local p=$1 bin ver
	if ! bin=$(bin_path "$p"); then
		echo "$p is not installed: '$(bin_name "$p")' is not on the PATH. Install it, then run: llms.sh connect $p" >&2
		return 1
	fi
	ver=$(tool_version "$bin")
	set_conn "$p" 1 "$bin" "$ver"
	refresh_one "$p"
	echo "connected $p ${ver:+($ver)}"
	cmd_models --provider "$p"
	[ "$p" = claude ] || echo "If $p asks you to sign in, run '$(bin_name "$p")' once in a terminal and follow its prompts."
}

cmd_disconnect() {
	[ $# -eq 1 ] && valid_provider "$1" || { usage; exit 2; }
	if [ "$1" = claude ]; then echo "claude stays connected: it runs the tt-* skills." >&2; return 1; fi
	set_conn "$1" 0 "" ""
	if [ -f "$modelsf" ]; then
		local tmp
		tmp=$(mktemp "$modelsf.XXXXXX") && awk -F'\t' -v p="$1" '{ sub(/\r$/, "") } $1 != p' "$modelsf" >"$tmp" && mv "$tmp" "$modelsf"
	fi
	echo "disconnected $1"
}

cmd_refresh() {
	local p
	if [ $# -ge 1 ]; then
		valid_provider "$1" || die "unknown provider '$1'"
		is_connected "$1" || { echo "$1 is not connected (llms.sh connect $1)" >&2; return 1; }
		refresh_one "$1"; echo "refreshed $1"; return 0
	fi
	for p in $PROVIDERS; do
		is_connected "$p" && { refresh_one "$p"; echo "refreshed $p"; }
	done
	return 0
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case "$cmd" in
	status) cmd_status "$@" ;;
	connect) cmd_connect "$@" ;;
	disconnect) cmd_disconnect "$@" ;;
	refresh) cmd_refresh "$@" ;;
	models) cmd_models "$@" ;;
	versions) cmd_versions "$@" ;;
	-h | --help | help | "") usage; [ -n "$cmd" ] && exit 0 || exit 2 ;;
	*) usage; exit 2 ;;
esac
