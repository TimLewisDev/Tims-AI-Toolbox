#!/usr/bin/env bash
# focus-summary.sh: a short summary of a Focus Log, for the question that asks the
# engineer to confirm the focus. It goes into the question text itself, so the
# engineer sees what the log says without opening it, and ends with a link to the
# log. Needs bash and awk only.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: focus-summary.sh <focus-log.md>

Prints markdown:
  **Focus statement:** <the statement, as written>
  **Change wanted:** <the wanted change>         (lite logs only)
  **Focus topics:** <name>; <name>               (Interest: Focus)
  **Background:** <name>; <name>                 (Interest: Context)
  **Parked:** <n> topic(s)
  **Not yet rated:** <n> topic(s)                (only when there are some)
  Full focus log: <link> (`<path>`)

The link is [[focus-log]] in an Obsidian vault (a .obsidian folder above the log),
else a relative Markdown link. Both open the log in a front end that follows
document links.

Exit: 0 printed, 1 the log has no Focus statement, 2 usage error.
EOF
	exit 2
}

[ $# -eq 1 ] || usage
case "$1" in -h | --help) usage ;; esac
log=$1
[ -f "$log" ] || { echo "focus-summary.sh: no such file: $log" >&2; exit 2; }
dir=$(cd "$(dirname "$log")" && pwd)
# The path as the engineer would paste it: a drive path under Git Bash on Windows.
shown=$(cd "$dir" && { pwd -W 2>/dev/null || pwd; })
abs="$shown/$(basename "$log")"
base=$(basename "$log" .md)

style=md
d=$dir
while [ -n "$d" ]; do
	if [ -d "$d/.obsidian" ]; then style=obsidian; break; fi
	p=$(dirname "$d")
	[ "$p" = "$d" ] && break
	d=$p
done

# From the feature folder's .tt onward when the log is under one, else its name.
case "$abs" in
	*/.tt/*) rel=".tt/${abs#*/.tt/}" ;;
	*) rel=$(basename "$log") ;;
esac
if [ "$style" = obsidian ]; then
	link="[[$base]]"
else
	link="[focus log]($(printf '%s' "$rel" | sed 's/ /%20/g'))"
fi

awk -v LINK="$link" -v PATHSHOWN="$abs" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function add(list, name) { return (list == "" ? name : list "; " name) }
function settle() {
	if (topic == "") return
	if (interest == "focus") focus = add(focus, topic)
	else if (interest == "context") context = add(context, topic)
	else if (interest == "parked") parked++
	else unrated++
	topic = ""; interest = ""
}
{
	line = $0
	sub(/\r$/, "", line)
	if (NR == 1) sub(/^\357\273\277/, "", line)
	if (line ~ /^```/) { fence = !fence; next }
	if (fence) next
	if (line ~ /^## /) { settle(); sect = tolower(trim(substr(line, 4))); next }
	if (sect == "focus statement") {
		t = trim(line)
		if (t != "" && t !~ /^<!--/) statement = (statement == "" ? t : statement " " t)
	} else if (sect == "topics") {
		if (line ~ /^### /) { settle(); topic = trim(substr(line, 5)); next }
		if (topic != "" && line ~ /^[-*] \*\*Interest:\*\*/) {
			v = line; sub(/^[-*] \*\*Interest:\*\*[ \t]*/, "", v)
			interest = tolower(v); sub(/[^a-z].*$/, "", interest)
		}
	} else if (sect == "change facts") {
		if (line ~ /^[-*] \*\*Wanted change:\*\*/) {
			v = line; sub(/^[-*] \*\*Wanted change:\*\*[ \t]*/, "", v)
			change = trim(v)
		}
	}
}
END {
	settle()
	if (statement == "") { print "focus-summary.sh: the log has no Focus statement" > "/dev/stderr"; exit 1 }
	print "**Focus statement:** " statement
	if (change != "") print "**Change wanted:** " change
	print "**Focus topics:** " (focus == "" ? "none yet" : focus)
	if (context != "") print "**Background:** " context
	printf "**Parked:** %d topic%s\n", parked + 0, (parked == 1 ? "" : "s")
	if (unrated > 0) printf "**Not yet rated:** %d topic%s\n", unrated, (unrated == 1 ? "" : "s")
	print "Full focus log: " LINK " (`" PATHSHOWN "`)"
}
' "$log"
