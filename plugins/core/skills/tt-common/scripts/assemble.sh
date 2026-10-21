#!/usr/bin/env bash
# assemble.sh: build a markdown document from part files, report part status,
# or append / insert parts into an existing document.
set -eu

MARK='<!-- tt:end -->'

usage() {
	cat >&2 <<'EOF'
usage: assemble.sh status <manifest.txt>
       assemble.sh build  <out.md> <manifest.txt> [--force]
       assemble.sh append <doc.md> <part.md> [<part.md> ...]
       assemble.sh insert <doc.md> "<exact heading line>" <part.md> [<part.md> ...]

A part is complete when its last non-blank line is <!-- tt:end -->.
The manifest lists part paths, one per line, relative to the manifest's folder
(absolute paths are allowed). Blank lines and lines starting with # are skipped.

status  Prints complete / incomplete / missing for every part.
        Exit 0 if all complete, 1 otherwise.
build   Refuses (exit 1) if any part is not complete, or <out> exists without
        --force. Writes parts in manifest order, markers stripped, CR and BOM
        removed, one blank line between parts. Prints counts, never content.
append  Appends complete parts to the end of <doc>, after one blank line.
insert  Inserts complete parts before the first line (outside code fences)
        exactly equal to the heading, followed by one blank line. Exit 1 if the
        heading isn't found.
append and insert keep <doc>'s line endings (CRLF stays CRLF). All writes go
to a temp file in the same folder and are then moved into place.
EOF
	exit 2
}

die() { echo "assemble.sh: $*" >&2; exit 2; }

# part_state <file>: complete | incomplete | missing
part_state() {
	if [ ! -f "$1" ]; then echo missing; return; fi
	last=$(tr -d '\r' <"$1" | awk 'NF { l = $0 } END { sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l); print l }')
	if [ "$last" = "$MARK" ]; then echo complete; else echo incomplete; fi
}

# emit_part <file> <crlf 0|1>: the part's content with CR, BOM, end markers
# and leading/trailing blank lines removed.
emit_part() {
	awk -v BINMODE=3 -v MARK="$MARK" -v CRLF="$2" '
	{
		l = $0; sub(/\r$/, "", l)
		if (FNR == 1) sub(/^\357\273\277/, "", l)
		t = l; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
		if (t == MARK) next
		if (t == "") { if (started) blanks++; next }
		for (; blanks > 0; blanks--) out("")
		started = 1
		out(l)
	}
	function out(s) { if (CRLF) printf "%s\r\n", s; else print s }
	' "$1"
}

# manifest_parts <manifest>: absolute-ish part paths, one per line
manifest_parts() {
	mdir=$(cd "$(dirname "$1")" && pwd)
	tr -d '\r' <"$1" | while IFS= read -r p || [ -n "$p" ]; do
		case "$p" in '' | '#'*) continue ;; esac
		case "$p" in
			/* | [A-Za-z]:[/\\]*) printf '%s\n' "$p" ;;
			*) printf '%s\n' "$mdir/$p" ;;
		esac
	done
}

# Count CR bytes with tr: some Windows builds of grep and awk drop CR when
# reading, and grep patterns for a literal "\r" in od output misfire.
uses_crlf() { [ "$(head -c 4096 "$1" | tr -dc '\r' | wc -c)" -gt 0 ]; }

tmp_beside() { mktemp "$(dirname "$1")/.assemble.XXXXXX"; }

require_complete() {
	for p in "$@"; do
		s=$(part_state "$p")
		[ "$s" = complete ] || { echo "assemble.sh: part is $s: $p" >&2; exit 1; }
	done
}

[ $# -ge 1 ] || usage
cmd=$1
shift
case "$cmd" in
	status)
		[ $# -eq 1 ] || usage
		[ -f "$1" ] || die "no such manifest: $1"
		bad=0; total=0
		while IFS= read -r p; do
			total=$((total + 1))
			s=$(part_state "$p")
			[ "$s" = complete ] || bad=$((bad + 1))
			printf '%s\t%s\n' "$s" "$p"
		done < <(manifest_parts "$1")
		echo "# $total parts, $((total - bad)) complete, $bad not complete"
		[ "$bad" -eq 0 ]
		;;
	build)
		[ $# -ge 2 ] && [ $# -le 3 ] || usage
		out=$1; man=$2; force=${3:-}
		[ -z "$force" ] || [ "$force" = --force ] || usage
		[ -f "$man" ] || die "no such manifest: $man"
		if [ -e "$out" ] && [ "$force" != --force ]; then
			echo "assemble.sh: $out exists; pass --force to overwrite" >&2; exit 1
		fi
		parts=()
		while IFS= read -r p; do parts+=("$p"); done < <(manifest_parts "$man")
		[ ${#parts[@]} -gt 0 ] || die "manifest lists no parts: $man"
		require_complete "${parts[@]}"
		tmp=$(tmp_beside "$out")
		trap 'rm -f "$tmp"' EXIT
		first=1
		for p in "${parts[@]}"; do
			[ $first -eq 1 ] || echo >>"$tmp"
			first=0
			emit_part "$p" 0 >>"$tmp"
		done
		mv -f "$tmp" "$out"
		trap - EXIT
		echo "built $out: ${#parts[@]} parts, $(wc -l <"$out" | tr -d ' ') lines"
		;;
	append | insert)
		if [ "$cmd" = append ]; then [ $# -ge 2 ] || usage; else [ $# -ge 3 ] || usage; fi
		doc=$1; shift
		[ -f "$doc" ] || die "no such document: $doc"
		heading=""
		if [ "$cmd" = insert ]; then heading=$1; shift; fi
		require_complete "$@"
		crlf=0
		if uses_crlf "$doc"; then crlf=1; fi
		tmp=$(tmp_beside "$doc")
		trap 'rm -f "$tmp" "$tmp.parts"' EXIT
		nl() { if [ $crlf -eq 1 ]; then printf '\r\n'; else echo; fi; }
		: >"$tmp.parts"
		first=1
		for p in "$@"; do
			[ $first -eq 1 ] || nl >>"$tmp.parts"
			first=0
			emit_part "$p" "$crlf" >>"$tmp.parts"
		done
		if [ "$cmd" = append ]; then
			cat "$doc" >"$tmp"
			# Make sure the document ends with a newline, then one blank line.
			[ -z "$(tail -c 1 "$doc")" ] || nl >>"$tmp"
			nl >>"$tmp"
			cat "$tmp.parts" >>"$tmp"
		else
			nl >>"$tmp.parts"
			HEADING=$heading awk -v BINMODE=3 -v PARTS="$tmp.parts" '
			BEGIN { h = ENVIRON["HEADING"]; fence = "" }
			{
				l = $0; sub(/\r$/, "", l)
				p = l; sub(/^   ?/, "", p)
				if (fence != "") { if (index(p, fence) == 1) fence = "" }
				else if (p ~ /^```/) fence = "```"
				else if (p ~ /^~~~/) fence = "~~~"
				else if (!done && l == h) {
					while ((getline x < PARTS) > 0) print x
					close(PARTS)
					done = 1
				}
				print
			}
			END { exit (done ? 0 : 1) }
			' "$doc" >"$tmp" || { echo "assemble.sh: heading not found: $heading" >&2; exit 1; }
		fi
		mv -f "$tmp" "$doc"
		rm -f "$tmp.parts"
		trap - EXIT
		echo "$cmd: $# part(s) into $doc, now $(wc -l <"$doc" | tr -d ' ') lines"
		;;
	-h | --help) usage ;;
	*) usage ;;
esac
