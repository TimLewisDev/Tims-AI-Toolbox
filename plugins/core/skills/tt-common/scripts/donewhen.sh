#!/usr/bin/env bash
# donewhen.sh: list every "Done when" item of a Comprehensive Tech Plan's
# implementation steps, numbered the one way every tt-* skill and script
# numbers them.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: donewhen.sh <plan.md> [§N]

Reads each step heading ("### §N. <title>", any level) and the bullet list
under its "**Done when:**" line, and prints one line per item:

  §N<TAB>k<TAB>text<TAB>plan line

Numbering: items are numbered 1, 2, … per step, in order.
  - A flat bullet is one item.
  - A bullet with sub-bullets is a heading, not an item: each sub-bullet is
    an item, its text "<parent text> <child text>" so it reads on its own.
  - A wrapped line (indented, not a bullet) joins the item above it.
  - A bullet is never split.
The text is the item as written (markdown kept), so it can be copied
verbatim and searched for with grep -F.

With §N, only that step. Exit: 0 items printed, 1 none found, 2 usage error.
EOF
	exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
case "$1" in -h | --help) usage ;; esac
[ -f "$1" ] || { echo "donewhen.sh: no such file: $1" >&2; exit 2; }
only=${2:-}

tr -d '\r' <"$1" | awk -v ONLY="$only" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function flush(   i) {
	# Emit the pending top-level bullet: itself if it has no children, else
	# each child prefixed with its text.
	if (top == "") return
	if (nkid == 0) out(top, topline)
	else for (i = 1; i <= nkid; i++) out(top " " kid[i], kidline[i])
	top = ""; nkid = 0
}
function out(t, l) { if (ONLY != "" && step != ONLY) return; k++; printf "%s\t%d\t%s\t%d\n", step, k, t, l; n++ }
BEGIN { fence = 0 }
/^(```|~~~)/ { fence = !fence; next }
fence { next }
/^#+[ \t]+§[0-9]+[a-z]?\./ {
	flush(); indw = 0
	s = $0; sub(/^#+[ \t]+/, "", s); match(s, /^§[0-9]+[a-z]?/); step = substr(s, 1, RLENGTH); k = 0; next
}
/^#/ { flush(); indw = 0; step = ""; next }
step != "" && /^\*\*Done when:?\*\*:?[ \t]*$/ { flush(); indw = 1; next }
indw && /^\*\*/ { flush(); indw = 0; next }
indw && /^[-*+] / { flush(); top = trim(substr($0, 3)); topline = NR; last = "top"; next }
indw && /^[ \t]+[-*+] / { if (top == "") next; nkid++; kid[nkid] = trim(substr(trim($0), 3)); kidline[nkid] = NR; last = "kid"; next }
indw && /^[ \t]+[^ \t]/ { t = trim($0); if (last == "kid") kid[nkid] = kid[nkid] " " t; else if (top != "") top = top " " t; next }
indw && /^[ \t]*$/ { next }
indw { flush(); indw = 0 }
END { flush(); exit (n > 0 ? 0 : 1) }'
