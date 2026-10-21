#!/usr/bin/env bash
# md-section.sh: index a markdown document's headings, or print sections by heading.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: md-section.sh index <doc.md | ->
       md-section.sh get <doc.md | -> "<heading prefix>" ["<heading prefix>" ...]

index  One line per heading: line<TAB>level<TAB>end line<TAB>heading text.
       The end line is the last line before the next heading of the same or
       higher level. Lines inside fenced code blocks are never headings.
get    Print each section whose heading starts with the prefix, from its
       heading line to its end line. A prefix starting with "#" is matched
       against the whole heading line ("### T07 —"); otherwise against the
       heading text after the #s ("T07 —"). Matching is a fixed-string prefix
       match, so "§", "(" and "|" are literal. Sections are separated by one
       blank line. Every heading that matches is printed.

Exit: 0 every prefix matched, 1 some prefix matched nothing, 2 usage error.
EOF
	exit 2
}

[ $# -ge 2 ] || usage
cmd=$1
doc=$2
shift 2
case "$cmd" in
	index) [ $# -eq 0 ] || usage ;;
	get) [ $# -ge 1 ] || usage ;;
	-h | --help) usage ;;
	*) usage ;;
esac
if [ "$doc" != "-" ] && [ ! -f "$doc" ]; then
	echo "md-section.sh: no such file: $doc" >&2
	exit 2
fi

# Prefixes are passed to awk through the environment, so backslashes survive.
n=0
for p in "$@"; do
	n=$((n + 1))
	export "MDS_PREFIX_$n=$p"
done
export MDS_PREFIX_COUNT=$n

awk -v CMD="$cmd" '
function trimcr(s) { sub(/\r$/, "", s); return s }
BEGIN {
	np = ENVIRON["MDS_PREFIX_COUNT"] + 0
	for (i = 1; i <= np; i++) pre[i] = ENVIRON["MDS_PREFIX_" i]
	fence = ""
}
{
	line = trimcr($0)
	if (NR == 1) sub(/^\357\273\277/, "", line)
	text[NR] = line
	probe = line
	sub(/^   ?/, "", probe)
	if (fence != "") {
		if (index(probe, fence) == 1) fence = ""
		next
	}
	if (probe ~ /^```/) { fence = "```"; next }
	if (probe ~ /^~~~/) { fence = "~~~"; next }
	if (line ~ /^#+[ \t]/) {
		hashes = line
		sub(/[ \t].*$/, "", hashes)
		lvl = length(hashes)
		if (lvl > 6) next
		h = line
		sub(/^#+[ \t]+/, "", h)
		sub(/[ \t]+#*[ \t]*$/, "", h)
		nh++
		hline[nh] = NR; hlvl[nh] = lvl; htext[nh] = h
	}
}
END {
	for (i = 1; i <= nh; i++) {
		hend[i] = NR
		for (j = i + 1; j <= nh; j++) if (hlvl[j] <= hlvl[i]) { hend[i] = hline[j] - 1; break }
	}
	if (CMD == "index") {
		for (i = 1; i <= nh; i++) printf "%d\t%d\t%d\t%s\n", hline[i], hlvl[i], hend[i], htext[i]
		exit (nh > 0 ? 0 : 1)
	}
	missing = 0; printed = 0
	for (p = 1; p <= np; p++) {
		found = 0
		for (i = 1; i <= nh; i++) {
			subject = (substr(pre[p], 1, 1) == "#") ? text[hline[i]] : htext[i]
			if (index(subject, pre[p]) != 1) continue
			found = 1
			if (printed++) print ""
			for (k = hline[i]; k <= hend[i]; k++) print text[k]
		}
		if (!found) { printf "md-section.sh: no heading starts with: %s\n", pre[p] > "/dev/stderr"; missing = 1 }
	}
	exit missing
}
' "$doc"
