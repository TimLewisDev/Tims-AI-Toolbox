#!/usr/bin/env bash
# record-session.sh: Claude Code SessionEnd hook. Records the ending session's
# token use in the token log when it used a tt-* skill and logging has been
# switched on (/tt-metrics on). Never fails or delays the session. Needs
# bash, sed and awk only.

case "${1:-}" in
	-h | --help)
		cat >&2 <<'EOF'
usage: record-session.sh < <SessionEnd hook input JSON>

Install as a SessionEnd hook in ~/.claude/settings.json:
  "hooks": { "SessionEnd": [ { "hooks": [ { "type": "command",
    "command": "bash \"<skills repo>/tools/metrics/record-session.sh\"" } ] } ] }

Reads transcript_path from the hook input, then runs
transcript-metrics.sh --record in the background and returns at once.

Records only while the flag file exists: switch it with /tt-metrics on|off.

Environment:
  TT_METRICS        off | 0 | false | no: record nothing, flag or not
  TT_METRICS_HOME   state directory (default: ~/.claude/tt-metrics)
  TT_METRICS_LOG    the log to write (default: token-log.md in the state directory)
  TT_METRICS_LABEL  label for the row (default: none)
  TT_METRICS_MATCH  ERE the session's skills must match (default: (^|,)tt-)

Always exits 0.
EOF
		exit 0 ;;
esac

case "${TT_METRICS:-on}" in off | OFF | 0 | false | no) exit 0 ;; esac

here=$(cd "$(dirname "$0")" && pwd) || exit 0
home=${TT_METRICS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-metrics}
[ -f "$home/enabled" ] || exit 0
log=${TT_METRICS_LOG:-$home/token-log.md}
match=${TT_METRICS_MATCH:-(^|,)tt-}

# The hook input is one JSON object; JSON escapes Windows backslashes as \\.
# Any run of backslashes becomes one forward slash.
input=$(cat 2>/dev/null) || exit 0
tp=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's#\\\+#/#g')
[ -n "$tp" ] && [ -f "$tp" ] || exit 0

args=(--record "$log" --match "$match")
[ -n "${TT_METRICS_LABEL:-}" ] && args+=(--label "$TT_METRICS_LABEL")

# Detached, so the session can exit while the transcript is read.
nohup bash "$here/../transcript-metrics.sh" "${args[@]}" "$tp" </dev/null >/dev/null 2>&1 &

# Also write a per-thread detail TSV for drill-down in the viz.
mkdir -p "$home/sessions"
fullid=$(basename "$tp" .jsonl)
shortid=${fullid:0:8}
detailfile="$home/sessions/$shortid.tsv"
[ -f "$detailfile" ] || \
    nohup bash "$here/../transcript-metrics.sh" --detail "$fullid" "$tp" \
        </dev/null >"$detailfile" 2>/dev/null &
exit 0
