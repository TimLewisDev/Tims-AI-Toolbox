#!/usr/bin/env bash
# stories.sh: the only writer of a User Stories document, for tt-user-stories
# (and any tool that shows one). Every write reads the whole document, applies
# one change and renders it again from templates/user-stories.md and
# templates/story.md, so every story is laid out the same however it was made.
# Needs bash, awk and sed only.
set -u
export LC_ALL=C

usage() {
	cat >&2 <<'EOF'
usage: stories.sh init <design doc> <out.md> [--prefix <P>] [--source <text>]
       stories.sh add <doc> <spec> [--proposed]
       stories.sh edit <doc> <US-id> <spec> [--altered] [--if <hash>]
       stories.sh set <doc> <US-id> title|group|status|source <value> [--if <hash>]
       stories.sh accept <doc> <US-id> [--if <hash>]
       stories.sh reject <doc> <US-id> [<reason>] [--if <hash>]
       stories.sh group add <doc> <name> [<description>]
       stories.sh group describe <doc> <name> <description>
       stories.sh group rename <doc> <name> <new name>
       stories.sh group remove <doc> <name> [--to <group>]
       stories.sh status <doc> Drafting|Ready|Updated
       stories.sh list <doc> --tsv
       stories.sh show <doc> <US-id> --tsv
       stories.sh check <doc>
       stories.sh tidy <doc>

init      Write a new document: the header, empty Groups, Stories and Retired.
          Source is a link to the design doc (a wiki link when it sits beside
          <out.md>, else its path); Status is "Drafting <date>".
add       Add a story from a spec and print its ID (US-NN, the next unused
          number; IDs are never reused). --proposed makes it Proposed.
edit      Change the fields the spec gives. --altered counts an alteration
          (the Altered line) and keeps the Origin.
set       Change one field. Setting Status to Accepted is the same as accept.
accept    Proposed -> Accepted. Accepting a "Merge of …" story moves the
          stories it merges to Retired as "Merged into <id>".
reject    Move the story to Retired as "Rejected" or "Rejected: <reason>".
group     add / describe / rename (every story's Group follows) / remove (its
          stories move to --to, or to Ungrouped). Names are unique ignoring
          case and can't hold "|"; "Ungrouped" is never listed.
status    Set the header's Status line to the word and today's date.
list      Print the document as tab-separated records:
            meta    source|status|next  <value>
            group   <name>  <description>  <stories in it>
            story   <id> <title> <group> <status> <origin> <altered> <source>
                    <article> <as> <want> <so that> <details> <criteria> <hash>
            retired <id> <title> <outcome>
          In every field \ is \\, a tab \t and a newline \n; criteria are
          one per line. <hash> changes whenever the story does: pass it back
          with --if to refuse a change to a story that moved since you read it.
show      The story's record only.
check     Exit 0 when the document is in the template's layout; otherwise
          print "problem: …" lines. Every write refuses a document with
          problems, so nothing in it is lost.
tidy      Render the document again in the template's layout.

A spec is a small text file, or - to read it from stdin (a quoted heredoc):
  title: <title>
  group: <group>                 (default Ungrouped; must be in Groups)
  status: Accepted|Proposed      (default Accepted)
  origin: Design doc|Suggested|Merge of US-02, US-05   (default Design doc)
  source: <the part of the design doc it comes from>
  as: <role>                     ("an artist": the article is kept)
  want: <goal>
  so_that: <benefit>
  details:
    <free text, every line indented two spaces>
  criteria:
    - Given …, when …, then …
add needs title, as, want, so_that and at least one criterion. Details lines
can't start with "#" or look like "- **Field:**", code fences must close, and
as/want/so_that can't hold "**".

Exit: 0 done, 1 refused input (a bad spec, an unknown story or group, a
document with problems), 2 usage error or a missing file, 3 the story changed
since it was read (--if).
EOF
	exit 2
}

die() { echo "stories.sh: $*" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
tpl="$here/../templates"
work=$(mktemp -d)
lock=""
cleanup() { [ -n "$lock" ] && rmdir "$lock" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT

# The fenced block of a template file.
fenced() { awk '/^```/ { if (in_) exit; in_ = 1; next } in_' "$1"; }

LIB='
BEGIN { for (i = 1; i < 256; i++) ORD[sprintf("%c", i)] = i }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function esc(s,   o, i, n, c) {
	if (s !~ /[\\\t\n]/) return s
	o = ""; n = length(s)
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "\\") o = o "\\\\"; else if (c == "\t") o = o "\\t"; else if (c == "\n") o = o "\\n"; else o = o c
	}
	return o
}
function unesc(s,   o, i, n, c) {
	if (index(s, "\\") == 0) return s
	o = ""; n = length(s)
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == "\\" && i < n) { c = substr(s, ++i, 1); o = o (c == "t" ? "\t" : c == "n" ? "\n" : c) } else o = o c
	}
	return o
}
function hash(s,   h, i, n) {
	h = 5381; n = length(s)
	for (i = 1; i <= n; i++) h = (h * 33 + ORD[substr(s, i, 1)]) % 2147483647
	return sprintf("%d", h)
}
'

# The model: one record per line, fields escaped (see list).
#   head <text> · group <name> <desc> · story <id> <title> <group> <status>
#   <origin> <altered> <source> <article> <as> <want> <so that> <details>
#   <criteria> · retired <id> <title> <outcome> · extra <text>
PARSE='
function problem(m) { printf "problem: %s\n", m >> PROB; close(PROB) }
function lp(m) { problem("line " NR ": " m) }
function cells(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l)
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|")
	for (i = 1; i <= n; i++) { gsub(/\001/, "|", arr[i]); arr[i] = trim(arr[i]) }
	return n
}
function table(l,   n, c) {
	if (l ~ /^[ \t]*$/) return
	if (l !~ /^[ \t]*\|/) { lp("text that is not a table row in ## " sec); return }
	n = cells(l, c)
	if (!tbl) {
		tbl = 1
		if (sec == "Groups" && c[1] != "Group") lp("the Groups table starts with | Group | Description |")
		if (sec == "Retired" && c[1] != "ID") lp("the Retired table starts with | ID | Title | Outcome |")
		return
	}
	if (c[1] ~ /^:?-+:?$/) return
	if (sec == "Groups") {
		if (n != 2) lp("a Groups row has " n " cells, not 2")
		ng++; GN[ng] = c[1]; GD[ng] = (c[2] == "—" ? "" : c[2])
	} else {
		if (n != 3) lp("a Retired row has " n " cells, not 3")
		nr++; RID[nr] = c[1]; RTI[nr] = c[2]; ROU[nr] = c[3]
	}
}
function endstory(   n, i, lines, out, pend) {
	if (!cur) return
	n = split(D[cur], lines, "\n"); out = ""; pend = 0
	for (i = 1; i <= n; i++) {
		if (lines[i] ~ /^[ \t]*$/) { if (out != "") pend = 1; continue }
		out = (out == "") ? lines[i] : out (pend ? "\n\n" : "\n") lines[i]; pend = 0
	}
	D[cur] = (out == "—") ? "" : out
	cur = 0
}
function storyline(l, inf,   t, k, v, s, p, q) {
	if (!inf && l ~ /^### /) {
		endstory()
		t = l; sub(/^###[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
		if (match(t, /^US-[0-9]+: /)) {
			ns++; cur = ns; skip = 0
			SID[ns] = substr(t, 1, RLENGTH - 2); T[ns] = substr(t, RLENGTH + 1); PART[ns] = "fields"
		} else { lp("a story heading reads \"### US-NN: <title>\""); skip = 1 }
		return
	}
	if (!cur) { if (l !~ /^[ \t]*$/ && !skip) lp("text outside a story in ## Stories"); return }
	if (!inf && l ~ /^#### /) {
		t = l; sub(/^####[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
		if (t == "Details") { if (PART[cur] != "fields") lp(SID[cur] ": Details comes before Acceptance criteria"); PART[cur] = "details"; HASD[cur] = 1 }
		else if (t == "Acceptance criteria") { PART[cur] = "criteria"; HASC[cur] = 1 }
		else lp(SID[cur] ": unknown heading \"" t "\"")
		return
	}
	if (PART[cur] == "details") { D[cur] = (DN[cur]++ ? D[cur] "\n" : "") l; return }
	if (l ~ /^[ \t]*$/) return
	if (PART[cur] == "criteria") {
		if (l ~ /^[-*] /) { v = trim(substr(l, 3)); C[cur] = (NC[cur]++ ? C[cur] "\n" : "") v }
		else if (l ~ /^[ \t]+[^ \t]/ && NC[cur]) C[cur] = C[cur] " " trim(l)
		else lp(SID[cur] ": an acceptance criterion is a \"- \" line")
		return
	}
	if (match(l, /^- \*\*[A-Za-z][A-Za-z ]*:\*\*/)) {
		k = substr(l, 5, RLENGTH - 7); v = trim(substr(l, RLENGTH + 1))
		if (k in FIELD) { if ((cur, k) in F) lp(SID[cur] ": a second " k " line"); F[cur, k] = v }
		else lp(SID[cur] ": unknown field \"" k "\"")
		return
	}
	if (l ~ /^\*\*As an?\*\* /) {
		s = l; ART[cur] = (s ~ /^\*\*As an\*\* /) ? "an" : "a"; sub(/^\*\*As an?\*\* /, "", s)
		p = index(s, ", **I want** "); q = index(s, ", **so that** ")
		if (!p || q <= p) { lp(SID[cur] ": the story line reads \"**As a** …, **I want** …, **so that** ….\""); return }
		AS[cur] = substr(s, 1, p - 1); W[cur] = substr(s, p + 13, q - p - 13)
		s = substr(s, q + 14); sub(/[ \t]*\.?[ \t]*$/, "", s); SO[cur] = s; HASL[cur] = 1
		return
	}
	lp(SID[cur] ": unexpected line")
}
BEGIN { sec = "pre"; fence = ""; split("Group Status Origin Altered Source", fl, " "); for (i in fl) FIELD[fl[i]] = 1 }
{
	line = $0; sub(/\r$/, "", line)
	if (NR == 1) sub(/^\357\273\277/, "", line)
	probe = line; sub(/^   ?/, "", probe)
	inf = 0
	if (fence != "") { inf = 1; if (index(probe, fence) == 1) fence = "" }
	else if (probe ~ /^```/ || probe ~ /^~~~/) { fence = substr(probe, 1, 3); inf = 1 }
	if (!inf && line ~ /^## /) {
		endstory(); skip = 0
		h = line; sub(/^##[ \t]+/, "", h); sub(/[ \t]+$/, "", h)
		if (h == "Groups" || h == "Stories" || h == "Retired") {
			if (seen[h]++) lp("a second \"## " h "\" section")
			sec = h; tbl = 0; next
		}
		sec = "extra"; nx++; X[nx] = line; next
	}
	if (sec == "pre") { P[++npre] = line; next }
	if (sec == "extra") { X[nx] = X[nx] "\n" line; next }
	if (sec == "Groups" || sec == "Retired") { table(line); next }
	storyline(line, inf)
}
END {
	endstory()
	if (fence != "") problem("a code fence is never closed")
	if (!seen["Groups"]) problem("no \"## Groups\" section")
	if (!seen["Stories"]) problem("no \"## Stories\" section")
	if (!seen["Retired"]) problem("no \"## Retired\" section")
	for (i = 1; i <= ng; i++) {
		k = tolower(GN[i])
		if (GN[i] == "") problem("a group with no name")
		else if (k == "ungrouped") problem("\"Ungrouped\" is never listed in Groups")
		else if (k in GK) problem("group \"" GN[i] "\" is listed twice")
		GK[k] = GN[i]
	}
	for (i = 1; i <= nr; i++) {
		if (RID[i] !~ /^US-[0-9]+$/) problem("a Retired row has the ID \"" RID[i] "\"")
		if (RID[i] in IDS) problem(RID[i] " is used twice")
		IDS[RID[i]] = 1
	}
	for (i = 1; i <= ns; i++) { if (SID[i] in IDS) problem(SID[i] " is used twice"); IDS[SID[i]] = 1 }
	for (i = 1; i <= ns; i++) {
		id = SID[i]
		if (T[i] == "") problem(id ": no title")
		g = F[i, "Group"]
		if (g == "") problem(id ": no Group line")
		else if (tolower(g) == "ungrouped") G[i] = "Ungrouped"
		else if (tolower(g) in GK) G[i] = GK[tolower(g)]
		else problem(id ": the group \"" g "\" is not in ## Groups")
		st = F[i, "Status"]
		if (st != "Accepted" && st != "Proposed") problem(id ": Status is Accepted or Proposed")
		o = F[i, "Origin"]
		if (o != "Design doc" && o != "Suggested" && o !~ /^Merge of US-[0-9]+(, US-[0-9]+)+$/)
			problem(id ": Origin is Design doc, Suggested or Merge of US-NN, US-NN")
		else if (o ~ /^Merge of /) {
			n = split(substr(o, 10), refs, ", ")
			for (j = 1; j <= n; j++) if (!(refs[j] in IDS) || refs[j] == id) problem(id ": merges " refs[j] ", which is not another story")
		}
		a = F[i, "Altered"]; if (a == "0") a = ""
		if (a != "" && a !~ /^[0-9]+$/) problem(id ": Altered is a number")
		AL[i] = a
		if (!HASL[i]) problem(id ": no \"**As a** …, **I want** …, **so that** ….\" line")
		if (!HASD[i]) problem(id ": no \"#### Details\" heading")
		if (!HASC[i] || !NC[i]) problem(id ": no acceptance criteria")
	}
	head = ""
	for (i = 1; i <= npre; i++) head = head (i > 1 ? "\n" : "") P[i]
	sub(/[ \t\n]+$/, "", head)
	print "head\t" esc(head)
	for (i = 1; i <= ng; i++) print "group\t" esc(GN[i]) "\t" esc(GD[i])
	for (i = 1; i <= ns; i++) {
		src = F[i, "Source"]; if (src == "—") src = ""
		print "story\t" esc(SID[i]) "\t" esc(T[i]) "\t" esc(G[i]) "\t" esc(F[i, "Status"]) "\t" esc(F[i, "Origin"]) "\t" AL[i] "\t" esc(src) "\t" ART[i] "\t" esc(AS[i]) "\t" esc(W[i]) "\t" esc(SO[i]) "\t" esc(D[i]) "\t" esc(C[i])
	}
	for (i = 1; i <= nr; i++) print "retired\t" esc(RID[i]) "\t" esc(RTI[i]) "\t" esc(ROU[i])
	for (i = 1; i <= nx; i++) { x = X[i]; sub(/[ \t\n]+$/, "", x); print "extra\t" esc(x) }
}
'

# Reading the model into arrays; shared by the change and render programs.
LOAD='
{
	n = split($0, f, "\t")
	if (f[1] == "head") { HEAD = unesc(f[2]); HASHEAD = 1 }
	else if (f[1] == "group") { ng++; GN[ng] = unesc(f[2]); GD[ng] = unesc(f[3]) }
	else if (f[1] == "story") { ns++; for (k = 2; k <= 14; k++) S[ns, k] = unesc(f[k]); REC[ns] = $0 }
	else if (f[1] == "retired") { nr++; RID[nr] = unesc(f[2]); RTI[nr] = unesc(f[3]); ROU[nr] = unesc(f[4]) }
	else if (f[1] == "extra") { nx++; X[nx] = unesc(f[2]) }
}
'

# The change. Story fields: 2 id, 3 title, 4 group, 5 status, 6 origin,
# 7 altered, 8 source, 9 article, 10 as, 11 want, 12 so that, 13 details,
# 14 criteria.
CHANGE='
function fail(m) { print "stories.sh: " m > "/dev/stderr"; failed = 1; exit 1 }
function findstory(id,   i) { for (i = 1; i <= ns; i++) if (S[i, 2] == id && !DEL[i]) return i; return 0 }
function findgroup(name,   i) {
	if (tolower(name) == "ungrouped") return -1
	for (i = 1; i <= ng; i++) if (!DELG[i] && tolower(GN[i]) == tolower(name)) return i
	return 0
}
function groupname(name,   i) {
	i = findgroup(name)
	if (i == -1) return "Ungrouped"
	if (i == 0) fail("no group \"" name "\" (add it first: stories.sh group add)")
	return GN[i]
}
function goodname(name) {
	if (name == "") fail("a group needs a name")
	if (name ~ /[|\t\n]/) fail("a group name can not hold \"|\"")
	if (tolower(name) == "ungrouped") fail("\"Ungrouped\" is not a group of its own")
}
function nextid(   i, m, v) {
	m = 0
	for (i = 1; i <= ns; i++) { v = substr(S[i, 2], 4) + 0; if (v > m) m = v }
	for (i = 1; i <= nr; i++) { v = substr(RID[i], 4) + 0; if (v > m) m = v }
	return sprintf("US-%02d", m + 1)
}
function retire(i, outcome) { nr++; RID[nr] = S[i, 2]; RTI[nr] = S[i, 3]; ROU[nr] = outcome; DEL[i] = 1 }
function accept(i,   n, refs, j, k) {
	S[i, 5] = "Accepted"
	if (S[i, 6] ~ /^Merge of /) {
		n = split(substr(S[i, 6], 10), refs, ", ")
		for (j = 1; j <= n; j++) { k = findstory(refs[j]); if (k) retire(k, "Merged into " S[i, 2]) }
	}
}
function apply(i) {
	if ("title" in HAS) S[i, 3] = SP["title"]
	if ("group" in HAS) S[i, 4] = groupname(SP["group"])
	if ("origin" in HAS) S[i, 6] = SP["origin"]
	if ("source" in HAS) S[i, 8] = SP["source"]
	if ("as" in HAS) { S[i, 10] = SP["as"]; S[i, 9] = SP["article"] }
	if ("want" in HAS) S[i, 11] = SP["want"]
	if ("so_that" in HAS) S[i, 12] = SP["so_that"]
	if ("details" in HAS) S[i, 13] = SP["details"]
	if ("criteria" in HAS) S[i, 14] = SP["criteria"]
	if ("status" in HAS) { if (SP["status"] == "Accepted" && S[i, 5] != "Accepted") accept(i); else S[i, 5] = SP["status"] }
}
function complete(i,   miss, n, refs, j) {
	miss = ""
	if (S[i, 3] == "") miss = miss " title"
	if (S[i, 10] == "") miss = miss " as"
	if (S[i, 11] == "") miss = miss " want"
	if (S[i, 12] == "") miss = miss " so_that"
	if (S[i, 14] == "") miss = miss " criteria"
	if (miss != "") fail(S[i, 2] " needs:" miss)
	if (S[i, 6] ~ /^Merge of /) {
		n = split(substr(S[i, 6], 10), refs, ", ")
		for (j = 1; j <= n; j++) if (refs[j] == S[i, 2] || (!findstory(refs[j]) && !retired(refs[j]))) fail(S[i, 2] " merges " refs[j] ", which is not another story")
	}
}
function retired(id,   i) { for (i = 1; i <= nr; i++) if (RID[i] == id) return i; return 0 }
BEGIN {
	if (SPEC != "") while ((getline l < SPEC) > 0) { k = substr(l, 1, index(l, "\t") - 1); SP[k] = unesc(substr(l, index(l, "\t") + 1)); HAS[k] = 1 }
}
END {
	if (failed) exit 1
	V = ENVIRON["ST_VALUE"]; V2 = ENVIRON["ST_VALUE2"]
	if (OP == "add") {
		i = ++ns; S[i, 2] = nextid(); S[i, 4] = "Ungrouped"; S[i, 5] = "Accepted"; S[i, 6] = "Design doc"; S[i, 9] = "a"
		apply(i)
		if (PROPOSED) S[i, 5] = "Proposed"
		complete(i)
		print S[i, 2] > OUTID
	} else if (OP ~ /^(edit|accept|reject)$/) {
		i = findstory(ID)
		if (!i) { for (j = 1; j <= nr; j++) if (RID[j] == ID) fail(ID " is retired (" ROU[j] ")"); fail("no story " ID) }
		if (IFH != "" && hash(REC[i]) != IFH) { print "stories.sh: " ID " has changed since it was read" > "/dev/stderr"; exit 3 }
		if (OP == "edit") { apply(i); if (ALTERED) S[i, 7] = (S[i, 7] + 0) + 1; complete(i) }
		else if (OP == "accept") accept(i)
		else retire(i, V == "" ? "Rejected" : "Rejected: " V)
	} else if (OP == "group_add") {
		goodname(V); if (findgroup(V)) fail("there is already a group \"" V "\"")
		ng++; GN[ng] = V; GD[ng] = V2
	} else if (OP == "group_describe") {
		g = findgroup(V); if (g <= 0) fail("no group \"" V "\""); GD[g] = V2
	} else if (OP == "group_rename") {
		g = findgroup(V); if (g <= 0) fail("no group \"" V "\"")
		goodname(V2); j = findgroup(V2); if (j && j != g) fail("there is already a group \"" V2 "\"")
		for (i = 1; i <= ns; i++) if (S[i, 4] == GN[g]) S[i, 4] = V2
		GN[g] = V2
	} else if (OP == "group_remove") {
		g = findgroup(V); if (g <= 0) fail("no group \"" V "\"")
		to = (V2 == "") ? "Ungrouped" : groupname(V2)
		if (to == GN[g]) fail("move the stories to a different group")
		for (i = 1; i <= ns; i++) if (S[i, 4] == GN[g]) S[i, 4] = to
		DELG[g] = 1
	} else if (OP == "status") {
		n = split(HEAD, hl, "\n"); out = ""; found = 0
		for (j = 1; j <= n; j++) { if (hl[j] ~ /^- \*\*Status:\*\*/) { hl[j] = "- **Status:** " V; found = 1 } out = out (j > 1 ? "\n" : "") hl[j] }
		HEAD = found ? out : HEAD "\n- **Status:** " V
	}
	print "head\t" esc(HEAD)
	for (i = 1; i <= ng; i++) if (!DELG[i]) print "group\t" esc(GN[i]) "\t" esc(GD[i])
	for (i = 1; i <= ns; i++) if (!DEL[i]) { r = "story"; for (k = 2; k <= 14; k++) r = r "\t" esc(S[i, k]); print r }
	for (i = 1; i <= nr; i++) print "retired\t" esc(RID[i]) "\t" esc(RTI[i]) "\t" esc(ROU[i])
	for (i = 1; i <= nx; i++) print "extra\t" esc(X[i])
}
'

# The document from the model and the two templates. Blank-line runs are
# collapsed afterwards, so the templates' spacing is the only spacing.
RENDER='
function fill(s,   out, p, k, hit) {
	out = ""
	while ((p = index(s, "<")) > 0) {
		out = out substr(s, 1, p - 1); s = substr(s, p); hit = 0
		for (k in VAL) if (index(s, "<" k ">") == 1) { out = out VAL[k]; s = substr(s, length(k) + 3); hit = 1; break }
		if (!hit) { out = out "<"; s = substr(s, 2) }
	}
	return out s
}
function cell(s) { gsub(/\|/, "\\|", s); return s }
function story(i,   j, n, c, crit) {
	split("", VAL)
	VAL["id"] = S[i, 2]; VAL["title"] = S[i, 3]; VAL["group"] = S[i, 4]; VAL["status"] = S[i, 5]
	VAL["origin"] = S[i, 6]; VAL["altered"] = S[i, 7]; VAL["source"] = (S[i, 8] == "" ? "—" : S[i, 8])
	VAL["article"] = S[i, 9]; VAL["as"] = S[i, 10]; VAL["want"] = S[i, 11]; VAL["so_that"] = S[i, 12]
	VAL["details"] = (S[i, 13] == "" ? "—" : S[i, 13])
	n = split(S[i, 14], c, "\n"); crit = ""
	for (j = 1; j <= n; j++) crit = crit (j > 1 ? "\n" : "") "- " c[j]
	VAL["criteria"] = crit
	for (j = 1; j <= nst; j++) {
		if (index(st[j], "<altered>") && VAL["altered"] == "") continue
		print fill(st[j])
	}
}
BEGIN {
	while ((getline l < DOCT) > 0) dt[++nd] = l
	while ((getline l < STORYT) > 0) st[++nst] = l
	for (he = 1; he <= nd; he++) if (dt[he] ~ /^## /) break
}
END {
	if (HASHEAD) print HEAD
	else {
		split("", VAL); VAL["title"] = ENVIRON["ST_TITLE"]; VAL["source"] = ENVIRON["ST_SOURCE"]; VAL["status"] = ENVIRON["ST_STATUS"]
		for (j = 1; j < he; j++) print fill(dt[j])
	}
	print ""
	for (j = he; j <= nd; j++) {
		if (dt[j] == "<group rows>") { for (i = 1; i <= ng; i++) print "| " cell(GN[i]) " | " cell(GD[i] == "" ? "—" : GD[i]) " |" }
		else if (dt[j] == "<stories>") { for (i = 1; i <= ns; i++) { story(i); print "" } }
		else if (dt[j] == "<retired rows>") { for (i = 1; i <= nr; i++) print "| " RID[i] " | " cell(RTI[i]) " | " cell(ROU[i]) " |" }
		else print dt[j]
	}
	for (i = 1; i <= nx; i++) { print ""; print X[i] }
}
'

TIDY='
/^[ \t]*$/ { if (seen) blank = 1; next }
{ if (blank) print ""; blank = 0; seen = 1; print }
'

# The spec, as escaped key/value lines. Prints every problem it finds.
SPEC_AWK='
function err(m) { print "stories.sh: spec: " m > "/dev/stderr"; bad = 1 }
function article(v,   c) {
	c = tolower(substr(v, 1, 1))
	if (c ~ /[aeio]/) return "an"
	if (c == "u" && tolower(v) ~ /^u[nmpglt]/ && tolower(v) !~ /^uni/) return "an"
	return "a"
}
BEGIN { split("title group status origin source as want so_that details criteria", kl, " "); for (i in kl) KEY[kl[i]] = 1 }
{
	l = $0; sub(/\r$/, "", l)
	if (NR == 1) sub(/^\357\273\277/, "", l)
	if (blk != "") {
		if (l ~ /^[ \t]*$/) { BL[blk, ++BN[blk]] = ""; next }
		if (l ~ /^  /) { BL[blk, ++BN[blk]] = substr(l, 3); next }
		if (l ~ /^\t/) { BL[blk, ++BN[blk]] = substr(l, 2); next }
		blk = ""
	}
	if (l ~ /^[ \t]*$/) next
	if (match(l, /^[a-z_]+:/)) {
		k = substr(l, 1, RLENGTH - 1); v = trim(substr(l, RLENGTH + 1))
		if (!(k in KEY)) { err("line " NR ": unknown key \"" k "\""); next }
		if (k in HAS) err("\"" k "\" is given twice")
		HAS[k] = 1
		if (k == "details" || k == "criteria") { blk = k; if (v != "") BL[k, ++BN[k]] = v; next }
		V[k] = v; next
	}
	err("line " NR ": not \"key: value\" (block text is indented two spaces)")
}
END {
	if ("details" in HAS) {
		out = ""; pend = 0; fences = 0
		for (i = 1; i <= BN["details"]; i++) {
			l = BL["details", i]
			if (l ~ /^[ \t]*$/) { if (out != "") pend = 1; continue }
			if (l ~ /^[ \t]*(```|~~~)/) fences++
			else if (l ~ /^[ \t]*#/) err("details: a line can not start with \"#\": " l)
			if (l ~ /^[ \t]*[-*] \*\*[A-Za-z][A-Za-z ]*:\*\*/) err("details: a line can not look like a story field: " l)
			out = (out == "") ? l : out (pend ? "\n\n" : "\n") l; pend = 0
		}
		if (fences % 2) err("details: a code fence is never closed")
		V["details"] = (out == "—") ? "" : out
	}
	if ("criteria" in HAS) {
		out = ""; n = 0
		for (i = 1; i <= BN["criteria"]; i++) {
			l = trim(BL["criteria", i]); if (l == "") continue
			sub(/^[-*][ \t]+/, "", l); if (l == "") continue
			out = out (n++ ? "\n" : "") l
		}
		if (!n) err("criteria: at least one criterion")
		V["criteria"] = out
	}
	if ("as" in HAS) {
		v = V["as"]
		if (tolower(v) ~ /^as an? /) v = substr(v, 4)
		if (tolower(v) ~ /^an /) { A = "an"; v = substr(v, 4) } else if (tolower(v) ~ /^a /) { A = "a"; v = substr(v, 3) } else A = article(v)
		V["as"] = trim(v); V["article"] = A; HAS["article"] = 1
	}
	if ("want" in HAS) { v = V["want"]; if (tolower(v) ~ /^i want /) v = substr(v, 8); V["want"] = trim(v) }
	if ("so_that" in HAS) { v = V["so_that"]; if (tolower(v) ~ /^so that /) v = substr(v, 9); sub(/[ \t]*\.+$/, "", v); V["so_that"] = trim(v) }
	for (k in V) if ((k == "as" || k == "want" || k == "so_that") && index(V[k], "**")) err(k ": can not hold \"**\"")
	for (k in V) if ((k == "title" || k == "as" || k == "want" || k == "so_that") && V[k] == "") err(k ": is empty")
	if ("title" in HAS && index(V["title"], "**")) err("title: can not hold \"**\"")
	if ("status" in HAS && V["status"] != "Accepted" && V["status"] != "Proposed") err("status: Accepted or Proposed")
	if ("origin" in HAS && V["origin"] != "Design doc" && V["origin"] != "Suggested" && V["origin"] !~ /^Merge of US-[0-9]+(, US-[0-9]+)+$/)
		err("origin: Design doc, Suggested or Merge of US-NN, US-NN")
	if (bad) exit 1
	for (k in HAS) print k "\t" esc(V[k])
}
'

# parse <doc>: the model in $work/model, problems in $work/problems
parse() {
	: >"$work/problems"
	awk -v PROB="$work/problems" "$LIB$PARSE" "$1" >"$work/model"
}

# fail_problems: refuse when the document has problems, so a write never drops text
fail_problems() {
	[ -s "$work/problems" ] || return 0
	cat "$work/problems" >&2
	echo "stories.sh: fix these first (stories.sh check \"$doc\")" >&2
	exit 1
}

templates() {
	[ -f "$tpl/user-stories.md" ] && [ -f "$tpl/story.md" ] || die "templates missing: $tpl"
	fenced "$tpl/user-stories.md" >"$work/doc.tpl"
	fenced "$tpl/story.md" >"$work/story.tpl"
}

# render <model> <out>: the document, CRLF when the file it replaces had it
render() {
	templates
	awk -v DOCT="$work/doc.tpl" -v STORYT="$work/story.tpl" "$LIB$LOAD$RENDER" "$1" | awk "$TIDY" >"$work/out"
	if [ -f "$2" ] && [ "$(head -c 4096 "$2" | tr -dc '\r' | wc -c)" -gt 0 ]; then
		awk -v BINMODE=3 '{ printf "%s\r\n", $0 }' "$work/out" >"$work/out.crlf" && mv "$work/out.crlf" "$work/out"
	fi
	local tmp
	tmp="$(dirname "$2")/.$(basename "$2").$$"
	cp "$work/out" "$tmp" && mv -f "$tmp" "$2" || { rm -f "$tmp"; die "can't write $2"; }
}

# take_lock: one writer at a time (the skill and a viewer may both write); a
# lock older than a minute was left by a writer that died
take_lock() {
	local l
	l="$(dirname "$doc")/.$(basename "$doc").lock"
	for _ in $(seq 1 100); do
		mkdir "$l" 2>/dev/null && { lock=$l; return 0; }
		[ -n "$(find "$l" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$l" 2>/dev/null && continue
		sleep 0.1
	done
	die "the document is locked by another writer: $l"
}

# change <op> [awk vars...]: parse, apply, render, under the lock
change() {
	local op=$1; shift
	take_lock
	parse "$doc"; fail_problems
	awk -v OP="$op" -v OUTID="$work/id" "$@" "$LIB$LOAD$CHANGE" "$work/model" >"$work/model2"
	local rc=$?
	[ "$rc" = 0 ] || exit "$rc"
	render "$work/model2" "$doc"
}

need_doc() { [ -f "$doc" ] || die "no such file: $doc"; }
one_line() { case "$1" in *$'\n'* | *$'\t'*) echo "stories.sh: a value can't hold a newline or tab" >&2; exit 1 ;; esac; }
spec() {
	local f=$1
	if [ "$f" = - ] || [ "$f" = /dev/stdin ]; then f="$work/stdin.spec"; cat >"$f"; fi
	[ -f "$f" ] || die "no such spec: $1"
	awk "$LIB$SPEC_AWK" "$f" >"$work/spec" || exit 1
}

[ $# -ge 1 ] || usage
cmd=$1; shift
case "$cmd" in
	-h | --help) usage ;;
	init)
		[ $# -ge 2 ] || usage
		intake=$1; doc=$2; shift 2; prefix=""; source=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--prefix) prefix=${2:?}; shift 2 ;;
				--source) source=${2:?}; shift 2 ;;
				*) usage ;;
			esac
		done
		[ -f "$intake" ] || die "no such file: $intake"
		[ -e "$doc" ] && die "$doc exists; delete it first to start again"
		[ -d "$(dirname "$doc")" ] || die "no such folder: $(dirname "$doc")"
		[ -n "$prefix" ] || prefix=$(basename "$doc" .md | sed 's/ - User Stories$//')
		if [ -z "$source" ]; then
			if [ "$(cd "$(dirname "$intake")" && pwd -P)" = "$(cd "$(dirname "$doc")" && pwd -P)" ]; then
				source="[[$(basename "$intake" .md)]]"
			else
				source="\`$intake\`"
			fi
		fi
		: >"$work/empty"
		ST_TITLE="$prefix - User Stories" ST_SOURCE="$source" ST_STATUS="Drafting $(date +%F)" render "$work/empty" "$doc"
		echo "$doc"
		;;
	add)
		[ $# -ge 2 ] || usage
		doc=$1; sp=$2; shift 2; proposed=0
		while [ $# -gt 0 ]; do case "$1" in --proposed) proposed=1; shift ;; *) usage ;; esac; done
		need_doc; spec "$sp"
		change add -v SPEC="$work/spec" -v PROPOSED="$proposed"
		cat "$work/id"
		;;
	edit)
		[ $# -ge 3 ] || usage
		doc=$1; id=$2; sp=$3; shift 3; altered=0; ifh=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--altered) altered=1; shift ;;
				--if) ifh=${2:?}; shift 2 ;;
				*) usage ;;
			esac
		done
		need_doc; spec "$sp"
		change edit -v SPEC="$work/spec" -v ID="$id" -v ALTERED="$altered" -v IFH="$ifh"
		;;
	set)
		[ $# -ge 4 ] || usage
		doc=$1; id=$2; field=$3; value=$4; shift 4; ifh=""
		while [ $# -gt 0 ]; do case "$1" in --if) ifh=${2:?}; shift 2 ;; *) usage ;; esac; done
		case "$field" in title | group | status | source) ;; *) usage ;; esac
		need_doc; one_line "$value"
		printf '%s: %s\n' "$field" "$value" >"$work/set.spec"
		spec "$work/set.spec"
		change edit -v SPEC="$work/spec" -v ID="$id" -v IFH="$ifh"
		;;
	accept | reject)
		[ $# -ge 2 ] || usage
		doc=$1; id=$2; shift 2; reason=""; ifh=""
		while [ $# -gt 0 ]; do
			case "$1" in
				--if) ifh=${2:?}; shift 2 ;;
				*) [ "$cmd" = reject ] && [ -z "$reason" ] || usage; reason=$1; shift ;;
			esac
		done
		need_doc; one_line "$reason"
		ST_VALUE="$reason" change "$cmd" -v ID="$id" -v IFH="$ifh"
		;;
	group)
		[ $# -ge 3 ] || usage
		sub=$1; doc=$2; name=$3; shift 3
		need_doc; one_line "$name"
		case "$sub" in
			add) one_line "${1:-}"; ST_VALUE="$name" ST_VALUE2="${1:-}" change group_add ;;
			describe) [ $# -eq 1 ] || usage; one_line "$1"; ST_VALUE="$name" ST_VALUE2="$1" change group_describe ;;
			rename) [ $# -eq 1 ] || usage; one_line "$1"; ST_VALUE="$name" ST_VALUE2="$1" change group_rename ;;
			remove)
				to=""
				if [ $# -gt 0 ]; then [ "$1" = --to ] && [ $# -eq 2 ] || usage; to=$2; fi
				ST_VALUE="$name" ST_VALUE2="$to" change group_remove ;;
			*) usage ;;
		esac
		;;
	status)
		[ $# -eq 2 ] || usage
		doc=$1
		case "$2" in Drafting | Ready | Updated) ;; *) usage ;; esac
		need_doc
		ST_VALUE="$2 $(date +%F)" change status
		;;
	list | show)
		doc=$1
		if [ "$cmd" = list ]; then [ $# -eq 2 ] && [ "$2" = --tsv ] || usage; id=""; else [ $# -eq 3 ] && [ "$3" = --tsv ] || usage; id=$2; fi
		need_doc
		parse "$doc"
		[ -s "$work/problems" ] && cat "$work/problems" >&2
		awk -F'\t' -v ID="$id" "$LIB"'
			FNR == NR { if ($1 == "story") { CNT[tolower(unesc($4))]++; v = substr($2, 4) + 0; if (v > m) m = v } else if ($1 == "retired") { v = substr($2, 4) + 0; if (v > m) m = v }; next }
			ID != "" { if ($1 == "story" && $2 == ID) { print $0 "\t" hash($0); found = 1 } next }
			$1 == "head" {
				n = split(unesc($2), hl, "\n")
				for (j = 1; j <= n; j++) {
					if (hl[j] ~ /^- \*\*Source:\*\*/) { s = hl[j]; sub(/^- \*\*Source:\*\*[ \t]*/, "", s); print "meta\tsource\t" esc(s) }
					if (hl[j] ~ /^- \*\*Status:\*\*/) { s = hl[j]; sub(/^- \*\*Status:\*\*[ \t]*/, "", s); print "meta\tstatus\t" esc(s) }
				}
				printf "meta\tnext\tUS-%02d\n", m + 1
				next
			}
			$1 == "group" { print $0 "\t" (CNT[tolower(unesc($2))] + 0); next }
			$1 == "story" { print $0 "\t" hash($0); next }
			$1 == "retired" { print }
			END { if (ID != "" && !found) { print "stories.sh: no story " ID > "/dev/stderr"; exit 1 } }
		' "$work/model" "$work/model"
		;;
	check)
		[ $# -eq 1 ] || usage
		doc=$1; need_doc
		parse "$doc"
		if [ -s "$work/problems" ]; then cat "$work/problems"; exit 1; fi
		templates
		awk -v DOCT="$work/doc.tpl" -v STORYT="$work/story.tpl" "$LIB$LOAD$RENDER" "$work/model" | awk "$TIDY" >"$work/out"
		tr -d '\r' <"$doc" | sed '1s/^\xEF\xBB\xBF//' | awk "$TIDY" >"$work/now"
		if ! cmp -s "$work/out" "$work/now"; then
			echo "problem: the layout differs from the template (stories.sh tidy \"$doc\" lays it out again)"
			exit 1
		fi
		;;
	tidy)
		[ $# -eq 1 ] || usage
		doc=$1; need_doc
		take_lock
		parse "$doc"; fail_problems
		render "$work/model" "$doc"
		;;
	*) usage ;;
esac
