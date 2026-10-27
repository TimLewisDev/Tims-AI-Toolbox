#!/usr/bin/env bash
# session-handoff.sh: carry on a feature in a new Claude Code session. Works out
# the session's name ("<Feature> : <Stage>") and the command it starts with from
# where the folder's documents stand, then opens it with new-session.sh. Run it
# only when the engineer has said yes. Needs bash and awk only.
set -u

usage() {
	cat >&2 <<'EOF'
usage: session-handoff.sh [--show] [--entry tt-workflow|tt-workflow-lite] [--prefix <P>]
                          [--stage <label> --run "<command>"] <folder> [<repo root>]

Opens a new terminal tab running claude, named "<Prefix> : <stage>", started with
the command that carries on from where <folder> now stands. Write the state
(close the stage, set the status) before calling it: the stage in the name is the
one the new session will work on.

The start command is, in order:
  --entry given            /tt-workflow or /tt-workflow-lite (they read the folder link)
  folder linked            /tt-workflow-lite if lite.sh links it, else /tt-workflow
                           (both: /tt-workflow unless the phase belongs to the lite route)
  not linked               the next step's own command, e.g. /tt-adversarial-plan resume "<plan>"

--prefix picks the feature when the folder holds several.
A folder with no tt documents yet (a new task) has no step to name: with --entry (or
--run) the session is named "<folder name> : Start" and starts `/<entry> "<folder>"`,
which links the folder and asks its first question; without them it exits 2.
--stage and --run replace the stage label and the start command, for the rare
step the state alone can't name (for example writing up a confirmed
exploration: --stage "Familiarisation Doc" --run '/tt-familiarisation-doc "<log>"').
A name another open Claude session already has gets " (2)", " (3)", ... after it.
--show prints "Name:" and "Prompt:" and opens nothing (no claude command needed).
<repo root> is where the session starts; it defaults to the git root of the
current directory.
Exit: 0 opened (or --show), 1 no terminal could be opened (the command is
printed), 2 usage error, nothing left to run, or several features (they are listed).
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
. "$here/tt-path.sh"

show=0; entry=""; prefix=""; stage_over=""; run_over=""
while :; do
	case ${1:-} in
	--show) show=1; shift ;;
	--entry) [ $# -ge 2 ] || { usage; exit 2; }; entry=$2; shift 2 ;;
	--prefix) [ $# -ge 2 ] || { usage; exit 2; }; prefix=$2; shift 2 ;;
	--stage) [ $# -ge 2 ] || { usage; exit 2; }; stage_over=$2; shift 2 ;;
	--run) [ $# -ge 2 ] || { usage; exit 2; }; run_over=$2; shift 2 ;;
	-h | --help) usage; exit 0 ;;
	*) break ;;
	esac
done
case $entry in "" | tt-workflow | tt-workflow-lite) ;; *) echo "session-handoff.sh: --entry is tt-workflow or tt-workflow-lite" >&2; exit 2 ;; esac
[ $# -ge 1 ] && [ $# -le 2 ] || { usage; exit 2; }

# abs <dir>: absolute path with forward slashes, as workflow.sh stores links
abs() { (cd "$1" 2>/dev/null && { pwd -W 2>/dev/null || pwd; }); }
folder=$(abs "$1") || { echo "session-handoff.sh: no such folder: $1" >&2; exit 2; }
repo=${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}

rows=$(bash "$here/workflow-state.sh" --tsv "$folder" 2>/dev/null | awk -F'\t' '$2 == "primary"')
# A folder with no tt documents yet (a new task) has no step to read. With --entry
# (or --run) the new session just starts the entry skill on the folder, which links
# it and asks its usual first question; without either there is no command to give.
fresh=0
if [ -z "$rows" ] || [ "$(printf '%s\n' "$rows" | awk -F'\t' '{ print $3 }' | sort -u)" = empty ]; then
	if [ -n "$entry" ] || [ -n "$run_over" ]; then
		fresh=1
	else
		echo "session-handoff.sh: no tt documents in $folder (pass --entry to start the entry skill on it)" >&2
		exit 2
	fi
fi

if [ $fresh = 1 ]; then
	p=${prefix:-$(basename "$folder")}; phase=""; skill=""; verb=""; arg=""; hint=""
	stage=${stage_over:-Start}
else
	if [ -n "$prefix" ]; then
		rows=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$prefix" '$1 == p')
		[ -n "$rows" ] || { echo "session-handoff.sh: no feature '$prefix' in $folder" >&2; exit 2; }
	fi
	if [ "$(printf '%s\n' "$rows" | wc -l)" -gt 1 ]; then
		echo "session-handoff.sh: several features in $folder; pass --prefix:" >&2
		printf '%s\n' "$rows" | awk -F'\t' '{ print "  " $1 }' >&2
		exit 2
	fi

	# awk, not read: empty tab-separated fields must stay empty
	f() { printf '%s' "$rows" | awk -F'\t' -v n="$1" '{ print $n }'; }
	p=$(f 1); phase=$(f 3); skill=$(f 4); verb=$(f 5); arg=$(f 6); hint=$(f 8); stage=$(f 9)
	[ "$skill" != "-" ] || { echo "session-handoff.sh: nothing left to run in $folder" >&2; exit 2; }
	[ -n "$p" ] || p=$(basename "$folder")
	[ -z "$stage_over" ] || stage=$stage_over
	[ -n "$stage" ] || stage=Next
fi
name="$p : $stage"

# Claude Code adds a random suffix to a name another live session already has.
# Live sessions keep a <pid>.json with their name (removed when they exit), so
# put a counter on the name instead: "<Prefix> : <Stage> (2)", "(3)", ...
sessions="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
taken() { grep -qF -- "\"name\":\"$1\"" "$sessions"/*.json 2>/dev/null; }
base=$name; n=2
while taken "$name"; do name="$base ($n)"; n=$((n + 1)); done

# linked_by <script>: does that entry skill's folder link point at this folder?
linked_by() {
	local l
	[ -f "$1" ] || return 1
	l=$(bash "$1" linked 2>/dev/null) || return 1
	[ "$(abs "$l" 2>/dev/null)" = "$folder" ]
}

if [ -z "$entry" ]; then
	full=0; lite=0
	# The entry skills belong to engineering, which may not be installed.
	wf=$(tt_find tt-workflow) && linked_by "$wf/scripts/workflow.sh" && full=1
	wl=$(tt_find tt-workflow-lite) && linked_by "$wl/scripts/lite.sh" && lite=1
	if [ $full = 1 ] && [ $lite = 1 ]; then
		case $phase in lite-* | debugging | debug-done | debugged) entry=tt-workflow-lite ;; *) entry=tt-workflow ;; esac
	elif [ $lite = 1 ]; then entry=tt-workflow-lite
	elif [ $full = 1 ]; then entry=tt-workflow
	fi
fi

if [ -n "$run_over" ]; then
	prompt=$run_over
elif [ -n "$entry" ]; then
	prompt="/$entry"
	[ $fresh = 0 ] || prompt="$prompt \"$folder\""  # a new task: the entry skill links this folder
else
	prompt="/$skill"
	[ -n "$verb" ] && prompt="$prompt $verb"
	[ -n "$arg" ] && prompt="$prompt \"$arg\""
	[ -n "$hint" ] && prompt="$prompt $hint"
fi

if [ "$show" = 1 ]; then
	printf 'Name: %s\nPrompt: %s\n' "$name" "$prompt"
	exit 0
fi
exec bash "$here/new-session.sh" --name "$name" "$repo" "$prompt"
