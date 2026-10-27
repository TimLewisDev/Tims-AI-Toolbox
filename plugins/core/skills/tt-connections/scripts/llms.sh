#!/usr/bin/env bash
# llms.sh: which LLM command-line tools are connected (claude, copilot, codex)
# and which models they offer. The connections are machine-wide, not per
# project. Models are generated from each tool's own --help (and from any
# lines you add in models.d/), never from this repo. Needs bash and awk only.
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

providers: claude | copilot | codex
A model is runnable when a tt-* skill can use it for a subagent. Only claude
models are runnable today; the others are listed so they can be picked later.
Extra models for a provider go in <home>/models.d/<provider>.tsv, one per line:
  <id> TAB <label> TAB <efforts, comma separated or -> TAB <yes|no>

State lives in ${TT_LLMS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-llms}
TT_CLAUDE_BIN, TT_COPILOT_BIN and TT_CODEX_BIN name the executables.
--tsv output: models: provider, id, label, efforts, runnable;
              status: provider, state, version, models, runnable models.
Exit: 0 ok, 1 refused or not installed, 2 usage error.
EOF
}

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

# gen_claude: claude has no model list command, so the models are its aliases
gen_claude() {
	local bin eff a t label
	eff=$DEFAULT_EFFORTS
	if bin=$(bin_path claude); then
		e=$(help_choices "$bin" --effort)
		[ -n "$e" ] && eff=$(csv "$e")
	fi
	for a in sonnet opus haiku fable; do
		t=$(alias_target "$a")
		label=$a
		[ -n "$t" ] && label="$a ($t)"
		printf 'claude\t%s\t%s\t%s\tyes\n' "$a" "$label" "$eff"
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
	for m in $ms; do printf '%s\t%s\t%s\t%s\tno\n' "$p" "$m" "$m" "$eff"; done
}

# extra_rows <provider>: lines from models.d/<provider>.tsv as full model rows
extra_rows() {
	[ -f "$extras/$1.tsv" ] || return 0
	awk -F'\t' -v OFS='\t' -v p="$1" '
		{ sub(/\r$/, "") }
		/^#/ || $1 == "" { next }
		{ print p, $1, ($2 == "" ? $1 : $2), ($3 == "" ? "-" : $3), (p == "claude" && $4 == "" ? "yes" : ($4 == "yes" ? "yes" : "no")) }' "$extras/$1.tsv"
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

# ensure_claude: models.tsv always has claude's rows, even before anyone connects
ensure_claude() {
	[ -f "$modelsf" ] && awk -F'\t' '$1 == "claude" { f = 1 } END { exit !f }' "$modelsf" && return 0
	refresh_one claude
}

# all_models: generated rows plus models.d rows of the connected providers, once per provider+id
all_models() {
	local p
	ensure_claude
	{
		for p in $PROVIDERS; do
			is_connected "$p" || continue
			[ -f "$modelsf" ] && awk -F'\t' -v p="$p" '{ sub(/\r$/, "") } $1 == p' "$modelsf"
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
	-h | --help | help | "") usage; [ -n "$cmd" ] && exit 0 || exit 2 ;;
	*) usage; exit 2 ;;
esac
