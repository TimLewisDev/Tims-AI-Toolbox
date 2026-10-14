#!/usr/bin/env bash
# retrieval-report.sh: summarize compact knowledge retrieval traces.
set -u

usage() {
	cat >&2 <<'EOF'
usage: retrieval-report.sh <cache-dir>
       retrieval-report.sh --all <cache-root>

Prints retrieval counts by skill and scope, plus the most recent events.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
mode=one
dir=$1
if [ "$dir" = "--all" ]; then
	mode=all
	[ $# -eq 2 ] || usage
	dir=$2
fi

files=""
if [ "$mode" = one ]; then
	[ -f "$dir/retrieval.log" ] || { echo "No retrieval trace: $dir/retrieval.log"; exit 1; }
	files=$dir/retrieval.log
else
	[ -d "$dir" ] || { echo "No cache root: $dir" >&2; exit 2; }
	files=$(find "$dir" -mindepth 2 -maxdepth 2 -type f -name retrieval.log -print | sort)
	[ -n "$files" ] || { echo "No retrieval traces under $dir"; exit 1; }
fi

echo "Retrieval summary"
awk -F'\t' '
	BEGIN { print "  Skill / scope                 Requests  Matches" }
	{
		key = $2 " / " $3
		req[key]++
		if ($4 != "" && $4 != "none") matched[key]++
		events[NR] = $0
	}
	END {
		for (key in req) printf "  %-28s %8d %8d\n", key, req[key], matched[key] + 0
		print "\nRecent events"
		start = NR - 9; if (start < 1) start = 1
		for (i = start; i <= NR; i++) print "  " events[i]
	}' $files
