#!/usr/bin/env bash
# check-planning-ids.sh: find planning IDs and planning-document references in
# code (or in the code blocks of markdown task cards), so none get committed.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: check-planning-ids.sh [--repo <dir>] [--extra '<ERE>'] [<file> ...]
       check-planning-ids.sh --md [--extra '<ERE>'] <doc.md> [<doc.md> ...]

Code mode (default): searches the given files, or, with none, every file
changed against HEAD plus every untracked file, in the repo (default: the
current directory's repo). Binary files are skipped.
--md: searches only the fenced code blocks of markdown documents (task cards,
plans), wherever they are.

Looks for:
  id       task, unit, plan, decision and challenge IDs: T07 T00b WU3 CD1 CH2 NB7 R14 A3 S5
           C2 D2 P4, level names L0 L1, and plan steps §6
  phrase   "per the plan", "tech plan", "task breakdown", "task status",
           "added for task", "work unit <n>"
  extra    anything matching --extra

Prints path:line<TAB>kind<TAB>token<TAB>text (text cut to 160 chars), then a
count. A hit isn't always wrong (a constant named C4, an "A1" key): judge each
one, and reword or drop the comments that are.

Exit: 0 no hits, 1 hits, 2 usage or environment error.
EOF
	exit 2
}

repo=""
extra=""
md=0
while [ $# -gt 0 ]; do
	case "$1" in
		--repo) repo=${2:?}; shift 2 ;;
		--extra) extra=${2:?}; shift 2 ;;
		--md) md=1; shift ;;
		-h | --help) usage ;;
		--) shift; break ;;
		-*) usage ;;
		*) break ;;
	esac
done

# scan: reads "location<TAB>text" lines and prints hits.
scan() {
	awk -F '\t' -v EXTRA="$extra" '
	function is_word(c) { return c ~ /[A-Za-z0-9_]/ }
	function hit(kind, tok) { printf "%s\t%s\t%s\t%s\n", loc, kind, tok, (length(txt) > 160 ? substr(txt, 1, 160) "…" : txt); n++ }
	{
		loc = $1; txt = substr($0, length($1) + 2); sub(/\r$/, "", txt)
		rest = txt; seen = 0
		while (match(rest, /(T[0-9][0-9][a-z]?|WU[0-9]+|CD[0-9]+|CH[0-9]+|NB[0-9]+|[RACSDP][0-9][0-9]?[0-9]?|L[0-9])/)) {
			tok = substr(rest, RSTART, RLENGTH)
			b = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
			a = substr(rest, RSTART + RLENGTH, 1)
			rest = substr(rest, RSTART + RLENGTH)
			if (is_word(b) || is_word(a)) continue
			hit("id", tok)
		}
		if (index(txt, "§")) hit("id", "§")
		low = tolower(txt)
		if (match(low, /per the (tech )?plan|tech plan|task breakdown|task status|added for task|work unit [0-9]/))
			hit("phrase", substr(txt, RSTART, RLENGTH))
		if (EXTRA != "" && match(txt, EXTRA)) hit("extra", substr(txt, RSTART, RLENGTH))
	}
	END { printf "# %d hit(s)\n", n; exit (n > 0 ? 1 : 0) }'
}

if [ $md -eq 1 ]; then
	[ $# -ge 1 ] || usage
	for f in "$@"; do [ -f "$f" ] || { echo "check-planning-ids.sh: no such file: $f" >&2; exit 2; }; done
	for f in "$@"; do
		awk -v F="$f" '
		{ l = $0; sub(/\r$/, "", l); p = l; sub(/^[ \t]*/, "", p) }
		fence != "" { if (index(p, fence) == 1) { fence = ""; next } printf "%s:%d\t%s\n", F, FNR, l; next }
		p ~ /^```/ { fence = "```"; next }
		p ~ /^~~~/ { fence = "~~~"; next }' "$f"
	done | scan
	exit $?
fi

if [ -n "$repo" ]; then cd "$repo"; fi
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "check-planning-ids.sh: not in a git repo" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"

files=()
if [ $# -gt 0 ]; then
	files=("$@")
else
	while IFS= read -r -d '' f; do [ -f "$f" ] && files+=("$f"); done < <(
		{ git -c core.quotePath=false diff --name-only -z HEAD; git -c core.quotePath=false ls-files -z --others --exclude-standard; } 2>/dev/null)
fi
if [ ${#files[@]} -eq 0 ]; then
	echo "# no changed or untracked files"
	exit 0
fi

# git grep finds candidate lines (skipping binaries); scan() applies the word
# boundaries, which differ between regex engines.
pattern='(T[0-9]{2}|WU[0-9]|CD[0-9]|CH[0-9]|NB[0-9]|[RACSDP][0-9]|L[0-9]|§|[Pp]lan|[Tt]ask|[Ww]ork unit)'
if [ -n "$extra" ]; then pattern="$pattern|($extra)"; fi
git -c core.quotePath=false grep --untracked --no-color -n -I -E "$pattern" -- "${files[@]}" 2>/dev/null |
	awk '{ i = index($0, ":"); j = index(substr($0, i + 1), ":"); printf "%s\t%s\n", substr($0, 1, i + j - 1), substr($0, i + j + 1) }' |
	scan
