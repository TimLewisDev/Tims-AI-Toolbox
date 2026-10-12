#!/usr/bin/env bash
# workflow.sh: the link between a project and its feature folder, for tt-workflow.
# Remembers one folder per project in a user-level file; works out where that
# folder stands with tt-common/scripts/workflow-state.sh. Needs bash and awk only.
# Writes nothing but the link file and, for "new", the new folder.
set -u

usage() {
	cat >&2 <<'EOF'
usage: workflow.sh start                    Tatty, then this project's linked folder and where it stands
       workflow.sh state [folder]           where the linked (or given) folder stands, and the next command
       workflow.sh link <folder>            link a folder to this project, replacing any old link
       workflow.sh unlink                   forget this project's link
       workflow.sh new <parent> <name>      create <parent>/<name>, link it, print its folder and prefix

The link is kept per project (the git root of the current directory) in
${TT_WORKFLOW_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-workflow}/${TT_WORKFLOW_LINKS:-links.tsv}
Exit: 0 ok, 1 nothing linked, 2 usage or environment error (a missing folder is one).
EOF
}

here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
common="$(dirname "$(dirname "$here")")/tt-common/scripts"
home=${TT_WORKFLOW_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-workflow}
links="$home/${TT_WORKFLOW_LINKS:-links.tsv}"

# abs <dir>: the folder's absolute path, with forward slashes
abs() { (cd "$1" 2>/dev/null && { pwd -W 2>/dev/null || pwd; }); }

key=$(git rev-parse --show-toplevel 2>/dev/null) || key=$PWD

# linked: this project's linked folder, or nothing
linked() { [ -f "$links" ] && awk -F'\t' -v k="$key" '{ sub(/\r$/, "") } $1 == k { print $2; exit }' "$links"; }

# setlink <folder>: replace this project's row (empty folder: remove it)
setlink() {
	mkdir -p "$home" || exit 2
	local tmp="$links.$$"
	{ [ -f "$links" ] && awk -F'\t' -v k="$key" '$1 != k' "$links"; [ -n "$1" ] && printf '%s\t%s\t%s\n' "$key" "$1" "$(date +%F)"; } >"$tmp"
	mv "$tmp" "$links"
}

need_link() {
	folder=$(linked)
	[ -n "$folder" ] || { echo "No folder linked for this project."; return 1; }
	[ -d "$folder" ] || { echo "The linked folder is missing: $folder"; return 2; }
}

state() {
	local folder=${1:-}
	if [ -z "$folder" ]; then need_link || return; fi
	bash "$common/workflow-state.sh" "$folder"
	[ $? -le 1 ] # no tt documents is a state, not a failure
}

cmd=${1:-start}
[ $# -gt 0 ] && shift
case $cmd in
start)
	bash "$common/tatty.sh" banner
	echo
	if need_link; then
		echo "Linked folder: $folder"
		state "$folder"
	fi
	exit 0
	;;
state) state "$@" ;;
link)
	[ $# -eq 1 ] || { usage; exit 2; }
	d=$(abs "$1") || { echo "workflow.sh: no such folder: $1" >&2; exit 2; }
	setlink "$d" && echo "Linked: $d"
	;;
unlink)
	old=$(linked)
	[ -n "$old" ] || { echo "Nothing linked for this project."; exit 1; }
	setlink "" && echo "Unlinked: $old"
	;;
new)
	[ $# -eq 2 ] || { usage; exit 2; }
	case $2 in
	"" | . | .. | *[/\\:*?\"\<\>\|]*) echo "workflow.sh: not a usable folder name: $2" >&2; exit 2 ;;
	esac
	p=$(abs "$1") || { echo "workflow.sh: no such parent folder: $1" >&2; exit 2; }
	if [ -e "$p/$2" ] && { [ ! -d "$p/$2" ] || [ -n "$(ls -A "$p/$2")" ]; }; then
		echo "workflow.sh: $p/$2 already exists and isn't empty. Link it instead." >&2
		exit 2
	fi
	mkdir -p "$p/$2" || exit 2
	setlink "$p/$2" && printf 'Folder: %s\nPrefix: %s\n' "$p/$2" "$2"
	;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
