#!/usr/bin/env bash
# debug-temp.sh: find the temporary logging tt-debug adds while debugging. Every
# such line carries the marker TT-DEBUG-TEMP, so none can be left behind.
set -u

usage() {
	cat >&2 <<'EOF'
usage: debug-temp.sh list|check [<repo>]

Searches the repo's working tree (tracked and untracked files, never ignored
ones, any .tt folder, or a Debug Report) for the marker TT-DEBUG-TEMP, which tt-debug writes on
every line it adds for debugging, as a comment or inside the log message.

list    print path:line: text for each hit, then a count; always exit 0
check   the same, but exit 1 while any remain

<repo> defaults to the current directory's repo. Binary files are skipped.
Exit: 0 none left (or list), 1 some left, 2 usage or environment error.
EOF
	exit 2
}

mode=${1:-}
case $mode in -h | --help | "") usage ;; list | check) ;; *) usage ;; esac
[ $# -le 2 ] || usage
repo=${2:-.}
[ -d "$repo" ] || { echo "debug-temp.sh: no such folder: $repo" >&2; exit 2; }
marker=TT-DEBUG-TEMP

if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	hits=$(git -C "$repo" --no-optional-locks grep -nI --untracked -e "$marker" -- . ':(exclude,glob)**/.tt/**' ':(exclude,glob)**/* - Debug Report.md' 2>/dev/null)
else
	hits=$(grep -rnI --exclude-dir=.tt --exclude-dir=.git --exclude='* - Debug Report.md' -e "$marker" "$repo" 2>/dev/null)
fi
if [ -z "$hits" ]; then echo "no temporary debugging lines left"; exit 0; fi
printf '%s\n' "$hits" | cut -c1-200
printf '%d temporary debugging line(s) left\n' "$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
[ "$mode" = list ] && exit 0
exit 1
