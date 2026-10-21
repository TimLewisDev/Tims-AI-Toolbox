#!/usr/bin/env bash
# verify-refs.sh: check every file path and path:line reference a markdown
# document cites, against a commit or the working tree, in bulk.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: verify-refs.sh (--ref <commit> | --worktree) [--repo <dir>] [--only-problems] [--include-code] <doc.md | ->

Reads references from backtick spans (outside code fences, unless
--include-code):
  PATH      a/b/File.cs, File.cs (known source/asset extensions), ./x
  PATHLINE  File.cs:120, a/b.cs:12-40, a/b.cs:12–40,88
  BARELINE  :222-284, attached to the last path on the same line, else to the
            last path on a heading or bold line since the last ## heading
  BRACE     a/{B, C}.cs, expanded to one row per item
  GLOB      a/*.cs, matched against the tree
  DIR       a/b/
  PATHISH   a/b with no extension: checked as a file or folder, soft if absent
  NEW       a path on a "- new `path`" line: expected not to exist yet
  AFFECTED  a row of the "## Affected Files" table: "new" must not exist;
            changed / unchanged / deleted must exist
A path that isn't found exactly is matched by unique suffix (OK_SUFFIX).
Line ranges are checked against the file's length, and the nearest identifier
span on the same line (`Foo`, `Bar.Baz()`) is looked for inside the range.

Output (TSV): docline kind ref resolved status detail context, then a
"# summary" line. Problem statuses: MISSING AMBIGUOUS NEW_EXISTS GLOB_NONE
LINE_OOR SYM_ABSENT SYM_MOVED. Soft: UNRESOLVED (PATHISH not found), UNATTACHED
(a bare :N-M with no path to attach to; check it by hand),
NEW_PLANNED (missing, but the document plans to create it), LFS_SKIP.

Exit: 0 no problems, 1 problems, 2 usage or environment error.
EOF
	exit 2
}

mode=""; sha=""; repo=""; only=0; code=0; doc=""
while [ $# -gt 0 ]; do
	case "$1" in
		--ref) mode=ref; sha=${2:?}; shift 2 ;;
		--worktree) mode=worktree; shift ;;
		--repo) repo=${2:?}; shift 2 ;;
		--only-problems) only=1; shift ;;
		--include-code) code=1; shift ;;
		--affected) shift ;; # always on; accepted for compatibility
		-h | --help) usage ;;
		-) doc=-; shift ;;
		-*) usage ;;
		*) doc=$1; shift ;;
	esac
done
[ -n "$mode" ] && [ -n "$doc" ] || usage

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [ "$doc" = - ]; then cat >"$tmp/doc.md"; else
	[ -f "$doc" ] || { echo "verify-refs.sh: no such file: $doc" >&2; exit 2; }
	cat "$doc" >"$tmp/doc.md"
fi

if [ -n "$repo" ]; then cd "$repo"; fi
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "verify-refs.sh: not in a git repo" >&2; exit 2; }
cd "$top"
G="git --no-optional-locks -c core.quotePath=false"
if [ "$mode" = ref ]; then
	sha=$($G rev-parse --verify --quiet "$sha^{commit}") || { echo "verify-refs.sh: unknown commit: $sha" >&2; exit 2; }
	$G ls-tree -r --name-only "$sha" >"$tmp/tree.txt"
else
	$G ls-files -co --exclude-standard >"$tmp/tree.txt"
fi

# 1. Extract references.
awk -v INCLUDE_CODE="$code" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function known_ext(p,   e) {
	if (!match(p, /\.[A-Za-z0-9]+$/)) return 0
	e = tolower(substr(p, RSTART + 1))
	return (e in EXT)
}
function looks_symbol(s) { return s ~ /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*(<[^>]*>)?(\(\))?$/ && !known_ext(s) }
function clean_symbol(s) { sub(/\(\)$/, "", s); sub(/<[^>]*>$/, "", s); sub(/^.*\./, "", s); return s }
# Classify one candidate; sets K (kind), P (path), L (lines). Returns 1 if it is a reference.
function classify(c,   before) {
	K = ""; P = ""; L = ""
	if (c ~ /^:[0-9]/) { K = "BARELINE"; L = substr(c, 2); return 1 }
	# An abbreviated path ("…/Prefabs/x.prefab") is matched by suffix.
	sub(/^(…|\.\.\.)\//, "", c)
	if (c ~ /[ \t<>()=;"\047|$]/ || c ~ /:\/\// || c ~ /^[-~\/]/ || c ~ /^[A-Za-z]:[\\\/]/ || c ~ /\\/) return 0
	if (match(c, /:[0-9][0-9,–-]*$/)) { before = substr(c, 1, RSTART - 1); L = substr(c, RSTART + 1); c = before }
	sub(/^\.\//, "", c)
	if (c == "" || c ~ /:/ || c ~ /^\.[A-Za-z0-9]+$/) return 0
	if (c ~ /[*?]/) { if (c !~ /\// && !known_ext(c)) return 0; K = "GLOB"; P = c; return 1 }
	if (c ~ /\/$/) { K = "DIR"; P = c; sub(/\/$/, "", P); return 1 }
	if (known_ext(c)) { K = (L != "" ? "PATHLINE" : "PATH"); P = c; return 1 }
	if (c ~ /\// && L == "" && c ~ /[A-Za-z]/ && c ~ /^[A-Za-z0-9_.@+-]+(\/[A-Za-z0-9_.@+ -]+)+$/) { K = "PATHISH"; P = c; return 1 }
	return 0
}
function indent_of(s,   t) { t = s; gsub(/\t/, "    ", t); match(t, /^ */); return RLENGTH }
# The path a bare ":N-M" on a list line at indent d belongs to: the nearest
# enclosing list item that led with a path, else the block (heading or bold
# paragraph) path. A bold-labelled item without a path stops the search.
function ctx_for(d,   k) {
	for (k = d - 1; k >= 0; k--) if (k in LCTX) return (LCTX[k] == "-") ? "" : LCTX[k]
	return BCTX
}
function emit(kind, ref, path, lines, sym, ctx, expect) {
	printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", NR, kind, ref, path, lines, sym, ctx, expect
}
BEGIN {
	n = split("cs shader hlsl cginc compute asmdef asmref json yaml yml md txt xml uxml uss js mjs cjs ts tsx jsx py sh ps1 bat cmd go rs java kt kts swift m mm c cc cpp h hpp rb php sql proto gradle toml ini cfg conf csproj sln props targets editorconfig unity prefab asset mat meta png jpg jpeg tga psd fbx anim controller playable overridecontroller lua html css scss vue svelte dart razor cshtml xaml resx tf hcl dockerfile lock", e, " ")
	for (i = 1; i <= n; i++) EXT[e[i]] = 1
	fence = ""; ctxpath = ""; ctxline = 0; affected = 0
}
{
	line = $0; sub(/\r$/, "", line)
	if (NR == 1) sub(/^\357\273\277/, "", line)
	probe = line; sub(/^   ?/, "", probe)
	if (fence != "") { if (index(probe, fence) == 1) fence = ""; else if (!INCLUDE_CODE) next }
	else if (probe ~ /^```/) { fence = "```"; next }
	else if (probe ~ /^~~~/) { fence = "~~~"; next }
	if (line ~ /^##?[ \t]/) {
		h = line; sub(/^#+[ \t]+/, "", h); affected = (trim(h) == "Affected Files")
	} else if (line ~ /^#+[ \t]/ && affected) affected = 0
	is_list = (line ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]/)
	is_block = (!is_list && (line ~ /^#+[ \t]/ || line ~ /^\*\*/))
	d = indent_of(line)
	if (is_block) { BCTX = ""; delete LCTX }
	else if (is_list) { for (k in LCTX) if (k + 0 >= d) delete LCTX[k] }
	else if (trim(line) != "" && line !~ /^\|/) delete LCTX
	here = is_list ? ctx_for(d) : BCTX
	lead_path = ""; lead_bold = (line ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]+\*\*/)
	is_new = (line ~ /^[ \t]*[-*+][ \t]+new[ \t]+`/)
	expect_row = ""
	if (affected && line ~ /^\|/) {
		nc = split(line, cell, "|")
		st = tolower(cell[3]); gsub(/[*_`]/, "", st); st = trim(st)
		if (st ~ /^new/) expect_row = "new"
		else if (st ~ /^(changed|unchanged|deleted|removed|modified)/) expect_row = "exists"
	}
	# Spans in order, with symbol candidates.
	ns = split(line, part, "`")
	cnt = 0
	for (i = 2; i < ns; i += 2) { cnt++; span[cnt] = trim(part[i]) }
	lastpath = ""
	for (i = 1; i <= cnt; i++) {
		s = span[i]
		cands = 1; cand[1] = s
		if (s ~ /\{[^}]*,[^}]*\}/) {
			pre = s; sub(/\{.*$/, "", pre); post = s; sub(/^[^}]*\}/, "", post)
			body = s; sub(/^[^{]*\{/, "", body); sub(/\}.*$/, "", body)
			cands = split(body, it, ",")
			for (j = 1; j <= cands; j++) cand[j] = pre trim(it[j]) post
		}
		for (j = 1; j <= cands; j++) {
			if (!classify(cand[j])) continue
			kind = (cands > 1 && K != "BARELINE") ? "BRACE" : K
			# The symbol a line reference points at: the span just before it,
			# with only a short gap ("`Foo`: `:12`", "`Foo` at `:12`"). Not when
			# the reference starts a list of references ("`A` and `B` (`:16`, `:44`)").
			sym = ""
			if (L != "" && i > 1 && length(part[2 * i - 1]) <= 12 && looks_symbol(span[i - 1]) &&
				!(i < cnt && span[i + 1] ~ /^:[0-9]/ && length(part[2 * i + 1]) <= 6)) sym = clean_symbol(span[i - 1])
			if (K == "BARELINE") {
				if (lastpath != "") emit(kind, s, lastpath, L, sym, "same line", "")
				else if (here != "") emit(kind, s, here, L, sym, "from context", "")
				else emit(kind, s, "", L, sym, "no path", "")
				continue
			}
			ex = expect_row
			if (ex == "" && is_new) ex = "new"
			if (affected && expect_row != "") kind = "AFFECTED"
			else if (is_new) kind = "NEW"
			emit(kind, s, P, L, sym, "", ex)
			if (K != "GLOB") {
				lastpath = P
				if (lead_path == "") lead_path = P
				if (is_block && BCTX == "") BCTX = P
			}
		}
	}
	# A list item that leads with a path is the context for its sub-items; a
	# bold-labelled item without one hides the paths above it.
	if (is_list) {
		first = (cnt > 0) ? span[1] : ""
		if (lead_path != "" && index(first, lead_path) > 0) LCTX[d] = lead_path
		else if (lead_bold) LCTX[d] = "-"
	}
}
' "$tmp/doc.md" >"$tmp/refs.tsv"

# 2. Resolve paths against the tree.
awk -F '\t' -v OFS='\t' '
function base(p) { sub(/^.*\//, "", p); return p }
function glob_re(g,   r, i, c, nx) {
	r = ""
	for (i = 1; i <= length(g); i++) {
		c = substr(g, i, 1); nx = substr(g, i + 1, 1)
		if (c == "*" && nx == "*") { r = r ".*"; i++ }
		else if (c == "*") r = r "[^/]*"
		else if (c == "?") r = r "[^/]"
		else if (c ~ /[.+(){}^$|\[\]\\]/) r = r "\\" c
		else r = r c
	}
	return "(^|/)" r "$"
}
FNR == NR {
	t = $0; sub(/\r$/, "", t); tree[++nt] = t; exact[t] = 1
	b = base(t); bycount[b]++; byname[b, bycount[b]] = t
	d = t
	while (sub(/\/[^\/]*$/, "", d)) { if (d in isdir) break; isdir[d] = 1; dirs[++ndirs] = d }
	next
}
FNR == 1 { pass2 = 1 }
{
	kind = $2; path = $4; expect = $8; res = ""; st = ""
	if (kind == "BARELINE" && path == "") { print $0, "", "UNATTACHED"; next }
	if (kind == "GLOB") {
		re = glob_re(path); m = 0
		for (i = 1; i <= nt; i++) if (tree[i] ~ re) { m++; if (m == 1) res = tree[i] }
		print $0, (m ? res (m > 1 ? " (+" m - 1 ")" : "") : ""), (m ? "GLOB_OK(" m ")" : "GLOB_NONE"); next
	}
	if (kind != "DIR" && (path in exact)) { res = path; st = "OK" }
	else if (path in isdir) { res = path "/"; st = "OK_DIR" }
	else if (kind != "DIR") {
		b = base(path); m = 0
		for (i = 1; i <= bycount[b]; i++) {
			c = byname[b, i]
			if (c == path || substr(c, length(c) - length(path)) == "/" path) { m++; if (m == 1) res = c }
		}
		if (m == 1) st = "OK_SUFFIX"; else if (m > 1) { st = "AMBIGUOUS(" m ")"; res = res " (+" m - 1 ")" } else res = ""
	}
	if (st == "" && (kind == "DIR" || kind == "PATHISH")) {
		m = 0
		for (i = 1; i <= ndirs; i++) if (substr(dirs[i], length(dirs[i]) - length(path)) == "/" path) { m++; if (m == 1) res = dirs[i] "/" }
		if (m == 1) st = "OK_DIR"; else if (m > 1) st = "AMBIGUOUS(" m ")"
	}
	found = (st == "OK" || st == "OK_SUFFIX" || st == "OK_DIR")
	if (expect == "new") st = found ? "NEW_EXISTS" : "NEW_OK"
	else if (st == "") st = (kind == "PATHISH") ? "UNRESOLVED" : "MISSING"
	print $0, res, st
}
' "$tmp/tree.txt" "$tmp/refs.tsv" >"$tmp/resolved.tsv"

# Paths the document plans to create: a missing reference to one is NEW_PLANNED.
awk -F '\t' '$8 == "new" { print $4 }' "$tmp/resolved.tsv" | sort -u >"$tmp/newset.txt"

# 3. Fetch each file whose lines are checked, once.
mkdir -p "$tmp/blobs"
: >"$tmp/blobmap.tsv"
awk -F '\t' '$5 != "" && ($10 == "OK" || $10 == "OK_SUFFIX") { print $9 }' "$tmp/resolved.tsv" | sort -u |
	while IFS= read -r f; do
		n=$((${n:-0} + 1))
		if [ "$mode" = ref ]; then
			$G show "$sha:$f" >"$tmp/blobs/$n" 2>/dev/null || continue
			printf '%s\t%s\n' "$f" "$tmp/blobs/$n" >>"$tmp/blobmap.tsv"
		elif [ -f "$f" ]; then
			printf '%s\t%s\n' "$f" "$top/$f" >>"$tmp/blobmap.tsv"
		fi
	done

# 4. Line and symbol checks, then the report.
awk -F '\t' -v OFS='\t' -v ONLY="$only" '
function load(f,   b, l, k) {
	if (f in nl) return
	b = blob[f]; k = 0
	while ((getline l < b) > 0) { sub(/\r$/, "", l); k++; text[f, k] = l }
	close(b); nl[f] = k
	lfs[f] = (text[f, 1] ~ /^version https:\/\/git-lfs\.github\.com\/spec/)
}
function rank(s) {
	if (s ~ /^(MISSING|AMBIGUOUS|NEW_EXISTS|GLOB_NONE)/) return 5
	if (s ~ /^LINE_OOR/) return 4
	if (s ~ /^SYM_ABSENT/) return 3
	if (s ~ /^SYM_MOVED/) return 2
	return 0
}
FILENAME == ARGV[1] { blob[$1] = $2; next }
FILENAME == ARGV[2] { planned[$0] = 1; next }
{
	ln = $1; kind = $2; ref = $3; path = $4; lines = $5; sym = $6; ctx = $7; res = $9; st = $10; detail = ""
	if (st == "MISSING" && (path in planned)) st = "NEW_PLANNED"
	if (lines != "" && (st == "OK" || st == "OK_SUFFIX") && (res in blob)) {
		load(res)
		if (lfs[res]) { detail = "LFS_SKIP"; }
		else {
			gsub(/–/, "-", lines)
			nr = split(lines, rg, ","); oor = 0; delete want
			for (i = 1; i <= nr; i++) {
				a = rg[i]; b = rg[i]
				if (index(rg[i], "-")) { a = substr(rg[i], 1, index(rg[i], "-") - 1); b = substr(rg[i], index(rg[i], "-") + 1) }
				a += 0; b += 0; if (b < a) b = a
				if (b > nl[res]) oor = 1
				for (k = a; k <= b && k <= nl[res]; k++) want[k] = 1
			}
			detail = "lines " lines " of " nl[res]
			if (oor) st = "LINE_OOR"
			if (sym != "") {
				hit = 0
				for (k in want) if (index(text[res, k], sym)) { hit = 1; break }
				if (hit) detail = detail "; SYM_OK " sym
				else {
					moved = 0
					for (k = 1; k <= nl[res]; k++) if (index(text[res, k], sym)) { moved = k; break }
					if (moved) { detail = detail "; SYM_MOVED:" moved " " sym; if (rank(st) < 2) st = "SYM_MOVED:" moved }
					else { detail = detail "; SYM_ABSENT " sym; if (rank(st) < 3) st = "SYM_ABSENT" }
				}
			}
		}
	}
	key = st; sub(/[:(].*$/, "", key); count[key]++; total++
	if (rank(st) > 0) problems++
	if (ONLY && rank(st) == 0) next
	print ln, kind, ref, res, st, detail, ctx
}
END {
	s = "# summary: " total " refs"
	for (k in count) s = s " · " k " " count[k]
	print s " · problems " problems + 0
	exit (problems > 0 ? 1 : 0)
}
' "$tmp/blobmap.tsv" "$tmp/newset.txt" "$tmp/resolved.tsv"
