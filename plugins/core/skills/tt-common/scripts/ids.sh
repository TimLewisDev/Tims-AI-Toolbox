#!/usr/bin/env bash
# ids.sh: list the planning IDs a document defines or cites, say in plain words
# what an ID means, link to it, and cross-check them.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: ids.sh defined <doc.md>
       ids.sh cited <doc.md>
       ids.sh xref [--prefixes R,S,A,C,CD,CH,NB,P,T,WU,§] <citing.md> <defining.md> [<defining.md> ...]
       ids.sh gloss [--link] [--style obsidian|md] <doc.md> <ID> [<ID> ...]
       ids.sh anchor [--fix] <plan.md>
       ids.sh style <doc.md>
       ids.sh linkify [--style obsidian|md] --def <defining.md> [--def ...] <doc.md>

IDs are R A S C P T (with digits, e.g. R12, T07a), CD CH NB WU (CD3, CH2, NB7, WU2)
and plan steps §N. Text inside code fences and inline code is ignored.

defined  ID<TAB>line<TAB>gloss for every definition: "**R12:**", "**S3**," or
         "**R12 (removed …):**", a table row whose first cell is the ID
         ("| CD3 |", "| CH2 |"), or a heading that starts with the ID ("### §3.",
         "## P4 —", "### T07 —", "## WU1 —"). The gloss is the item's statement
         cut to a short phrase (see gloss).
cited    ID<TAB>count<TAB>first line, for every ID mentioned. Ranges such as
         "R3–R6", "R3-6" and "§1–§4" cite every ID in between.
xref     UNDEFINED<TAB>ID<TAB>line: cited in <citing> but defined in none of
         the defining docs. UNCITED<TAB>ID<TAB>line: defined (with a prefix in
         --prefixes, default all) but never cited in <citing>.
gloss    ID<TAB>words for each ID (ranges expand): what the item says, in a
         short phrase taken from the document, never written from memory. An
         ID the document does not define prints "ID<TAB>?" and the exit is 1.
         --link adds a third column: a link to the item. In an Obsidian vault
         (a .obsidian folder above the document, or --style obsidian) that is
         [[Doc#^r12|R12]] to a block id, a heading link, or a section link;
         otherwise a relative Markdown link.
style    Print obsidian when a .obsidian folder sits above <doc.md> (a vault), else md.
         Tells a stage whether to write block ids (see anchor).
anchor   Report the R/A/S/C items without an Obsidian block id (" ^r12" at the
         end of the item, lowercase): MISSING<TAB>ID<TAB>line, or
         MISMATCH<TAB>ID<TAB>line<TAB>^found. --fix appends the missing ones
         (nothing else is changed) and leaves mismatches for the engineer.
linkify  Rewrite the bare single-ID cites in <doc> as links to the item in the
         --def documents (first definition wins). Code, existing links,
         headings, ranges, front matter and the document's own definitions are
         left alone. Safe to run again.

Exit: 0 clean (or IDs found, for defined / cited), 1 xref found gaps, a gloss ID
is undefined, an anchor is missing or nothing was found, 2 usage error.
EOF
	exit 2
}

# The awk library shared by every command.
read -r -d '' LIB <<'AWK' || true
function clean(s) { sub(/\r$/, "", s); return s }
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
# Skip fenced code; returns 1 if the line should be ignored.
function in_fence(l,   p) {
	p = l; sub(/^   ?/, "", p)
	if (FENCE != "") { if (index(p, FENCE) == 1) FENCE = ""; return 1 }
	if (p ~ /^```/) { FENCE = "```"; return 1 }
	if (p ~ /^~~~/) { FENCE = "~~~"; return 1 }
	return 0
}
function strip_code(l,   out, n, parts, i) {
	n = split(l, parts, "`")
	out = parts[1]
	for (i = 2; i <= n; i++) out = out ((i % 2 == 0) ? " " : parts[i])
	return out
}
function is_word(c) { return c ~ /[A-Za-z0-9_]/ }
# Calls cite(id, line) for every ID cited in the line.
function scan(l, ln,   rest, pos, tok, before, after, pfx, num, m, n2, k, tail) {
	rest = l; pos = 0
	while (match(rest, /(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?|§[0-9]+[a-z]?/)) {
		tok = substr(rest, RSTART, RLENGTH)
		before = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
		after = substr(rest, RSTART + RLENGTH, 1)
		tail = substr(rest, RSTART + RLENGTH)
		rest = tail
		if (substr(tok, 1, 1) != "§" && is_word(before)) continue
		if (is_word(after)) continue
		cite(tok, ln)
		# Ranges: R3–R6, R3-R6, R3–6, §1–§4
		pfx = tok; sub(/[0-9]+[a-z]?$/, "", pfx)
		num = tok; sub(/^[^0-9]+/, "", num); sub(/[a-z]$/, "", num)
		if (match(tail, /^(–|-)/)) {
			m = substr(tail, RLENGTH + 1)
			if (index(m, pfx) == 1) m = substr(m, length(pfx) + 1)
			if (match(m, /^[0-9]+/) && !is_word(substr(m, RLENGTH + 1, 1))) {
				n2 = substr(m, 1, RLENGTH) + 0
				if (n2 > num + 0 && n2 - num <= 50)
					for (k = num + 1; k <= n2; k++) cite(pfx k, ln)
			}
		}
	}
}
# Returns the ID a line defines, or "".
function definition(l,   t) {
	if (match(l, /\*\*(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?(:| \(|\*\*[:,])/)) {
		t = substr(l, RSTART + 2, RLENGTH - 2); sub(/(:| \(|\*\*[:,])$/, "", t); return t
	}
	if (match(l, /^\|[ \t]*(\*\*)?(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?(\*\*)?[ \t]*\|/)) {
		t = substr(l, RSTART, RLENGTH); gsub(/[| \t*]/, "", t); return t
	}
	if (match(l, /^#+[ \t]+((CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?|§[0-9]+[a-z]?)([.:]|[ \t]|$)/)) {
		t = substr(l, RSTART, RLENGTH); sub(/^#+[ \t]+/, "", t); sub(/[.: \t]$/, "", t); return t
	}
	return ""
}

# A document is held as lines T[1..N]; F[i] is 1 inside a code fence.
function reset_doc() { N = 0; FENCE = ""; delete T; delete F }
function load_line(raw,   l) { l = clean(raw); N++; T[N] = l; F[N] = in_fence(l) }
# The last line of the item that starts on line i: a bullet runs on until a
# blank line, the next bullet, a heading, a table row or a fence.
function pend(i,   j) {
	if (T[i] ~ /^(#|\|)/) return i
	j = i
	while (j < N && !F[j + 1] && T[j + 1] !~ /^[ \t]*$/ && T[j + 1] !~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]/ && T[j + 1] !~ /^(#|\||```|~~~)/) j++
	return j
}
function para_text(i,   j, t) {
	t = T[i]
	for (j = i + 1; j <= pend(i); j++) t = t " " trim(T[j])
	return t
}
# Words for the item in a definition line: its statement without the ID,
# markup, a trailing proposal cite or block id, cut at the first sentence (or
# ";" or a dash) and at about 80 characters.
function gloss(t,   n, cells, i, c, rest, removed, best, keep, tmp, off, p, pre, k, a, b) {
	removed = 0
	if (t ~ /^\|/) {
		n = split(t, cells, "|"); t = ""
		for (i = 3; i <= n; i++) { c = trim(cells[i]); if (c != "") { t = c; break } }
	} else if (t ~ /^#+[ \t]/) {
		sub(/^#+[ \t]+/, "", t); sub(/^[^ \t]+/, "", t); sub(/^([ \t]|\.|:|—|–|-)+/, "", t)
	} else if (match(t, /\*\*(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?(:| \(|\*\*[:,])/)) {
		rest = substr(t, RSTART + 2)
		sub(/^(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?/, "", rest)
		if (rest ~ /^ \(/) { removed = (rest ~ /^ \(removed/); sub(/^ \([^)]*\)/, "", rest) }
		sub(/^(:\*\*|\*\*[:,]?|:)/, "", rest)
		t = rest
	}
	while (match(t, /\[\[[^]]*\]\]/)) {
		a = RSTART; b = RLENGTH; k = substr(t, a + 2, b - 4)
		if (index(k, "|")) k = substr(k, index(k, "|") + 1)
		t = substr(t, 1, a - 1) k substr(t, a + b)
	}
	while (match(t, /\[[^]]*\]\([^)]*\)/)) {
		a = RSTART; b = RLENGTH; k = substr(t, a, b)
		sub(/\]\(.*$/, "", k); sub(/^\[/, "", k)
		t = substr(t, 1, a - 1) k substr(t, a + b)
	}
	gsub(/\*\*|`/, "", t); gsub(/\\\|/, "|", t); gsub(/[ \t]+/, " ", t)
	t = trim(t)
	sub(/ \^[A-Za-z0-9-]+$/, "", t)
	sub(/ ?\(P[0-9]+([,;] ?P[0-9]+)*\)\.?$/, "", t)
	best = length(t) + 1; keep = 0
	tmp = t; off = 0
	while (match(tmp, /[.!?]( |$)/)) {
		p = off + RSTART; pre = substr(t, 1, p - 1)
		if (pre !~ /(e\.g|i\.e|vs|etc)$/) { best = p; keep = 1; break }
		off += RSTART; tmp = substr(tmp, RSTART + 1)
	}
	k = index(t, ";"); if (k && k < best) { best = k; keep = 0 }
	k = index(t, " — "); if (k && k < best) { best = k; keep = 0 }
	k = index(t, " – "); if (k && k < best) { best = k; keep = 0 }
	if (best <= length(t)) t = substr(t, 1, keep ? best : best - 1)
	t = trim(t)
	if (length(t) > 80) { t = substr(t, 1, 80); sub(/[ \t]+[^ \t]*$/, "", t); sub(/[,:(]$/, "", t); t = t "…" }
	return removed ? "(removed) " t : t
}
function docname(f,   n) { n = f; sub(/^.*[\/\\]/, "", n); sub(/\.md$/, "", n); return n }
function slug(s) { s = tolower(s); gsub(/[^a-z0-9 _-]/, "", s); gsub(/ /, "-", s); return s }
# A heading as Obsidian wants it in a link.
function hclean(s) { gsub(/[][|#^]/, " ", s); gsub(/ +/, " ", s); return trim(s) }

# What each document defines, by ID (the first definition wins): gl words,
# docof document name, kind heading|item, head heading text, secof the "## "
# section it sits in, anc its block id, defline its line.
function defs_file(docn,   i, id, sec, e, h, a) {
	sec = ""
	for (i = 1; i <= N; i++) {
		if (F[i]) continue
		if (T[i] ~ /^##[ \t]/) { sec = T[i]; sub(/^##[ \t]+/, "", sec) }
		id = definition(T[i])
		if (id == "") continue
		# a table row (an "at a glance" list) gives way to a fuller definition
		if ((id in gl) && !(kind[id] == "row" && T[i] !~ /^\|/)) continue
		gl[id] = gloss(para_text(i)); docof[id] = docn; secof[id] = sec; defline[id] = i
		delete anc[id]
		if (T[i] ~ /^#+[ \t]/) { h = T[i]; sub(/^#+[ \t]+/, "", h); kind[id] = "heading"; head[id] = h }
		else if (T[i] ~ /^\|/) kind[id] = "row"
		else {
			kind[id] = "item"; e = pend(i)
			if (match(T[e], /[ \t]\^[A-Za-z0-9-]+[ \t]*$/)) { a = substr(T[e], RSTART); gsub(/[ \t^]/, "", a); anc[id] = a }
		}
	}
}
# A link to an item, as Obsidian wiki-link (STYLE obsidian) or Markdown link.
# In a table row the alias bar must be escaped.
function make_link(id, intable,   d, bar, t) {
	d = docof[id]
	if (STYLE == "obsidian") {
		bar = intable ? "\\|" : "|"
		if (kind[id] == "heading") return "[[" d "#" hclean(head[id]) bar id "]]"
		if (anc[id] != "") return "[[" d "#^" anc[id] bar id "]]"
		if (secof[id] != "") return "[[" d "#" hclean(secof[id]) bar id "]]"
		return "[[" d bar id "]]"
	}
	t = (kind[id] == "heading") ? head[id] : secof[id]
	return "[" id "](<" d ".md" (t != "" ? "#" slug(t) : "") ">)"
}
AWK

# obsidian when a .obsidian folder sits above the document, otherwise md.
detect_style() {
	local d p
	d=$(cd "$(dirname "$1")" && pwd)
	while [ -n "$d" ]; do
		if [ -d "$d/.obsidian" ]; then echo obsidian; return; fi
		p=$(dirname "$d")
		[ "$p" = "$d" ] && break
		d=$p
	done
	echo md
}

need_file() { [ -f "$1" ] || { echo "ids.sh: no such file: $1" >&2; exit 2; }; }

[ $# -ge 1 ] || usage
cmd=$1
shift
case "$cmd" in
	defined | cited)
		[ $# -eq 1 ] || usage
		need_file "$1"
		;;
	xref | gloss | anchor | linkify) ;;
	style)
		[ $# -eq 1 ] || usage
		need_file "$1"
		detect_style "$1"
		exit 0
		;;
	*) usage ;;
esac

case "$cmd" in
	defined)
		awk "$LIB"'
		{ load_line($0) }
		END { for (i = 1; i <= N; i++) { if (F[i]) continue
		        id = definition(T[i]); if (id != "") { printf "%s\t%d\t%s\n", id, i, gloss(para_text(i)); n++ } }
		      exit (n > 0 ? 0 : 1) }' "$1"
		;;
	cited)
		awk "$LIB"'
		function cite(id, ln) { if (!(id in cnt)) { order[++n] = id; first[id] = ln }; cnt[id]++ }
		{ l = clean($0); if (in_fence(l)) next; scan(strip_code(l), NR) }
		END { for (i = 1; i <= n; i++) printf "%s\t%d\t%d\n", order[i], cnt[order[i]], first[order[i]]; exit (n > 0 ? 0 : 1) }' "$1"
		;;
	xref)
		prefixes=""
		if [ "${1:-}" = --prefixes ]; then prefixes=${2:-}; shift 2 || usage; fi
		[ $# -ge 2 ] || usage
		for f in "$@"; do need_file "$f"; done
		citing=$1
		shift
		awk -v PREFIXES="$prefixes" "$LIB"'
		function cite(id, ln) { if (FILENAME == CITING && !(id in cited)) { cited[id] = ln; corder[++nc] = id } }
		function prefix(id,   p) { p = id; sub(/[0-9]+[a-z]?$/, "", p); return p }
		BEGIN { if (PREFIXES != "") { np = split(PREFIXES, ps, ","); for (i = 1; i <= np; i++) want[ps[i]] = 1 } }
		FNR == 1 { FENCE = ""; if (NR == 1) CITING = FILENAME }
		{
			l = clean($0); if (in_fence(l)) next
			if (FILENAME == CITING) scan(strip_code(l), FNR)
			else { id = definition(l); if (id != "" && !(id in defd)) { defd[id] = FNR; dorder[++nd] = id } }
		}
		END {
			for (i = 1; i <= nc; i++) if (!(corder[i] in defd)) { printf "UNDEFINED\t%s\t%d\n", corder[i], cited[corder[i]]; bad++ }
			for (i = 1; i <= nd; i++) {
				id = dorder[i]
				if (PREFIXES != "" && !(prefix(id) in want)) continue
				if (!(id in cited)) { printf "UNCITED\t%s\t%d\n", id, defd[id]; bad++ }
			}
			printf "# %d cited, %d defined, %d gaps\n", nc, nd, bad
			exit (bad > 0 ? 1 : 0)
		}' "$citing" "$@"
		;;
	gloss)
		link=0 style=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--link) link=1; shift ;;
				--style) style=${2:-}; shift 2 || usage ;;
				*) break ;;
			esac
		done
		[ $# -ge 2 ] || usage
		doc=$1
		shift
		need_file "$doc"
		[ -n "$style" ] || style=$(detect_style "$doc")
		case "$style" in obsidian | md) ;; *) usage ;; esac
		awk -v WANT="$*" -v STYLE="$style" -v LINK="$link" "$LIB"'
		function cite(id, ln) { if (!(id in seen)) { seen[id] = 1; order[++nw] = id } }
		BEGIN { scan(WANT, 0); if (nw == 0) { print "ids.sh: no IDs in the arguments" > "/dev/stderr"; BAD = 1; exit 2 } }
		{ load_line($0) }
		END {
			if (BAD) exit 2
			defs_file(docname(FILENAME))
			for (i = 1; i <= nw; i++) {
				id = order[i]
				if (!(id in gl)) { printf "%s\t?\n", id; miss++; continue }
				g = gl[id]; sub(/\.$/, "", g); if (g == "") g = "(statement on the lines that follow)"
				printf "%s\t%s", id, g
				if (LINK) printf "\t%s", make_link(id, 0)
				printf "\n"
			}
			exit (miss > 0 ? 1 : 0)
		}' "$doc"
		;;
	anchor)
		fix=0
		if [ "${1:-}" = --fix ]; then fix=1; shift; fi
		[ $# -eq 1 ] || usage
		doc=$1
		need_file "$doc"
		tmp=$(mktemp)
		# awk drops a Windows line end on reading, so remember it to put back.
		cr=""
		if [ "$(tr -cd '\015' <"$doc" | wc -c)" -gt 0 ]; then cr=$(printf '\015'); fi
		rc=0
		awk -v FIX="$fix" -v OUT="$tmp" -v CR="$cr" "$LIB"'
		{ load_line($0) }
		END {
			for (i = 1; i <= N; i++) {
				if (F[i] || T[i] ~ /^(#|\|)/) continue
				id = definition(T[i])
				if (id !~ /^[RASC][0-9]/ || (id in seen)) continue
				seen[id] = 1; want = tolower(id); e = pend(i)
				if (match(T[e], /[ \t]\^[A-Za-z0-9-]+[ \t]*$/)) {
					a = substr(T[e], RSTART); gsub(/[ \t^]/, "", a)
					if (a != want) { printf "MISMATCH\t%s\t%d\t^%s\n", id, i, a; mism++ } else ok++
				} else if (FIX) { sub(/[ \t]+$/, "", T[e]); T[e] = T[e] " ^" want; printf "FIXED\t%s\t%d\n", id, i; fixed++ }
				else { printf "MISSING\t%s\t%d\n", id, i; miss++ }
			}
			for (i = 1; i <= N; i++) printf "%s%s\n", T[i], CR > OUT
			printf "# %d anchored, %d missing, %d fixed, %d mismatched\n", ok, miss, fixed, mism
			exit (miss + mism > 0 ? 1 : 0)
		}' "$doc" || rc=$?
		[ "$fix" = 1 ] && ! cmp -s "$tmp" "$doc" && cat "$tmp" >"$doc"
		rm -f "$tmp"
		exit "$rc"
		;;
	linkify)
		style="" defs=()
		while [ $# -gt 0 ]; do
			case "$1" in
				--style) style=${2:-}; shift 2 || usage ;;
				--def | --plan) [ -n "${2:-}" ] || usage; defs+=("$2"); shift 2 ;;
				*) break ;;
			esac
		done
		[ $# -eq 1 ] && [ ${#defs[@]} -ge 1 ] || usage
		doc=$1
		need_file "$doc"
		[ -n "$style" ] || style=$(detect_style "$doc")
		case "$style" in obsidian | md) ;; *) usage ;; esac
		files=()
		for d in "${defs[@]}"; do
			need_file "$d"
			[ "$d" = "$doc" ] || files+=("$d")
		done
		tmp=$(mktemp)
		cr=""
		if [ "$(tr -cd '\015' <"$doc" | wc -c)" -gt 0 ]; then cr=$(printf '\015'); fi
		awk -v TARGET="$doc" -v STYLE="$style" -v OUT="$tmp" -v CR="$cr" "$LIB"'
		# Links the bare IDs in text that holds no code or link.
		function link_plain(s, intable,   out, head, tok, after, tail, before) {
			out = ""
			while (match(s, /(CD|CH|NB|WU|[RASCPT])[0-9]+[a-z]?|§[0-9]+[a-z]?/)) {
				tok = substr(s, RSTART, RLENGTH)
				before = (RSTART > 1) ? substr(s, RSTART - 1, 1) : ""
				head = substr(s, 1, RSTART - 1)
				tail = substr(s, RSTART + RLENGTH); after = substr(tail, 1, 1)
				s = tail
				out = out head
				if ((substr(tok, 1, 1) != "§" && is_word(before)) || is_word(after) || !(tok in gl) || (tok in own) \
				    || tail ~ /^(–|-)(CD|CH|NB|WU|[RASCPT])?[0-9]/ \
				    || (head ~ /^(–|-)$/ && out ~ /[0-9][a-z]?(–|-)$/)) {
					out = out tok
				} else { out = out make_link(tok, intable); nlinked++ }
			}
			return out s
		}
		function link_line(s, intable,   out, pre, m) {
			out = ""
			while (match(s, /`[^`]*`|\[\[[^]]*\]\]|\[[^]]*\]\([^)]*\)|\[[^]]*\]\[[^]]*\]/)) {
				pre = substr(s, 1, RSTART - 1); m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
				out = out link_plain(pre, intable) m
			}
			return out link_plain(s, intable)
		}
		function end_file(   i, skip) {
			if (FILE_ == TARGET) {
				for (i = 1; i <= N; i++) if (!F[i] && (id = definition(T[i])) != "") own[id] = 1
				skip = 0
				if (T[1] == "---") { for (i = 2; i <= N; i++) if (T[i] == "---") { skip = i; break } }
				for (i = 1; i <= N; i++) {
					if (i > skip && !F[i] && T[i] !~ /^#/ && definition(T[i]) == "") T[i] = link_line(T[i], T[i] ~ /^[ \t]*\|/)
					printf "%s%s\n", T[i], CR > OUT
				}
			} else defs_file(docname(FILE_))
		}
		FNR == 1 { if (NR > 1) end_file(); reset_doc(); FILE_ = FILENAME }
		{ load_line($0) }
		END { end_file(); printf "# %d cites linked\n", nlinked + 0 }' ${files[@]+"${files[@]}"} "$doc"
		cmp -s "$tmp" "$doc" || cat "$tmp" >"$doc"
		rm -f "$tmp"
		;;
esac
