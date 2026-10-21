#!/usr/bin/env bash
# coverage.sh: the mechanical part of a Task Breakdown's coverage audit. Checks
# the written parts against the plan and writes the Coverage section, leaving
# only Non-Goals and plain-English quality for a model.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: coverage.sh <draft folder> [--plan <plan.md>]

Reads <draft>/manifest.txt, <draft>/skeleton.md and the parts, and the plan
(default: the skeleton's "- Plan:" line). Writes <draft>/parts/80-coverage.md
(plan step -> tasks -> units; plan ID -> tasks; affected file -> task; ending
with <!-- tt:end -->) and prints one TSV row per defect:
check<TAB>where<TAB>what<TAB>suggested fix.
  steps        a plan step no card's Plan step names
  tasks        a skeleton task with no card in the manifest; a card part not in
               the manifest; a card whose heading or Work unit disagrees with
               its file name
  donewhen     a plan "Done when" item (donewhen.sh) found verbatim in no unit
               block, or in more than one
  ids          an ID a plan step cites that no card cites
  files        an Affected Files row (not unchanged) on no card; a card file
               outside Affected Files or marked unchanged
  plainenglish a unit block or card with no "**In plain English:**", or one
               with code, a path or more than 4 sentences
  planningids  check-planning-ids.sh --md hits in the unit and card parts
  fill         a "<!-- fill: … -->" marker left in a part
Not checked (needs a model): that no card does what Scope / Non-Goals rules
out, and that each plain-English paragraph reads well.

Exit: 0 no defects, 1 defects, 2 usage error.
EOF
	exit 2
}

[ $# -ge 1 ] || usage
case "$1" in -h | --help) usage ;; esac
draft=$1; shift
plan=""
while [ $# -gt 0 ]; do case "$1" in --plan) plan=${2:?}; shift 2 ;; *) usage ;; esac; done
sk="$draft/skeleton.md"; man="$draft/manifest.txt"
[ -f "$sk" ] || { echo "coverage.sh: no skeleton: $sk" >&2; exit 2; }
[ -f "$man" ] || { echo "coverage.sh: no manifest: $man" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
[ -n "$plan" ] || plan=$(bash "$here/skeleton-tsv.sh" "$sk" meta | awk -F'\t' '$1 == "plan" { print $2 }')
plan=$(printf '%s' "$plan" | sed 's/^`//; s/`$//')
[ -f "$plan" ] || { echo "coverage.sh: no such plan: ${plan:-?} (pass --plan)" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
P="$draft/parts"

bash "$here/skeleton-tsv.sh" "$sk" tasks >"$work/tasks" || :
bash "$here/donewhen.sh" "$plan" >"$work/items" || :
tr -d '\r' <"$man" >"$work/manifest"
tr -d '\r' <"$plan" | awk '/^#+[ \t]+§[0-9]+[a-z]?\./ { s = $0; sub(/^#+[ \t]+/, "", s); match(s, /^§[0-9]+[a-z]?/); print substr(s, 1, RLENGTH) }' >"$work/steps"
# Affected Files: path<TAB>status, as skeleton-check.sh reads them.
tr -d '\r' <"$plan" | awk '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
/^## / { on = (trim(substr($0, 4)) == "Affected Files"); hdr = 1; next }
on && /^[ \t]*\|/ {
	if (hdr) { n = split($0, h, "|"); for (i = 1; i <= n; i++) { t = tolower(trim(h[i])); if (t ~ /^file/) fc = i; if (t ~ /^status/) sc = i }; hdr = 0; sepr = 1; next }
	if (sepr) { sepr = 0; next }
	n = split($0, c, "|"); st = tolower(c[sc]); gsub(/[*`]/, "", st); st = (st ~ /unchanged/) ? "unchanged" : trim(st)
	l = c[fc]
	while (match(l, /`[^`]+`/)) { p = substr(l, RSTART + 1, RLENGTH - 2); l = substr(l, RSTART + RLENGTH)
		if (match(p, /\{[^}]*\}/)) { pre = substr(p, 1, RSTART - 1); post = substr(p, RSTART + RLENGTH); m = split(substr(p, RSTART + 1, RLENGTH - 2), alt, ",")
			for (j = 1; j <= m; j++) print pre trim(alt[j]) post "\t" st }
		else if (p ~ /[\/.]/ && p !~ /^\.[a-z]+$/) print p "\t" st }
}' >"$work/affected"
# IDs each plan step cites.
while IFS= read -r s; do
	bash "$here/md-section.sh" get "$plan" "$s." >"$work/step.md" 2>/dev/null || continue
	bash "$here/ids.sh" cited "$work/step.md" 2>/dev/null | awk -F'\t' -v S="$s" '$1 !~ /^(§|T[0-9]|WU)/ { print S "\t" $1 }'
done <"$work/steps" >"$work/stepids"

# One record stream from the parts: unit blocks and cards.
: >"$work/parts"
for f in "$P"/30-*.md "$P"/31-*.md; do [ -f "$f" ] && printf '%s\n' "$f" >>"$work/parts"; done
: >"$work/cardids"
while IFS= read -r f; do
	case "$f" in */31-*) bash "$here/ids.sh" cited "$f" 2>/dev/null | awk -F'\t' -v F="$(basename "$f")" '{ print F "\t" $1 }' >>"$work/cardids" || : ;; esac
done <"$work/parts"
bash "$here/check-planning-ids.sh" --md $(grep '/3[01]-' "$work/parts" | tr '\n' ' ') >"$work/pids" 2>/dev/null || :

style=md
if [ -f "$draft/context.md" ] && grep -qiE 'wiki|\[\[' "$draft/context.md"; then style=wiki; fi
ng=$(tr -d '\r' <"$plan" | sed -n 's/^#\{1,6\}[ \t]\{1,\}\(.*Non-Goals.*\)$/\1/p' | head -n 1)

mapfile -t partfiles <"$work/parts"
awk -v W="$work" -v OUT="$P/80-coverage.md" -v STYLE="$style" -v PBASE="$(basename "$plan" .md)" -v NG="$ng" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function bad(c, w, m, f) { printf "%s\t%s\t%s\t%s\n", c, w, m, f; nb++ }
function norm(p) { gsub(/\\/, "/", p); sub(/^\.\//, "", p); return p }
function same(a, b) { a = norm(a); b = norm(b); return a == b || (length(a) > length(b) && substr(a, length(a) - length(b)) == "/" b) || (length(b) > length(a) && substr(b, length(b) - length(a)) == "/" a) }
function base(f) { sub(/.*\//, "", f); return f }
function join(arr, n,   i, s) { s = ""; for (i = 1; i <= n; i++) s = s (s == "" ? "" : ", ") arr[i]; return s }
BEGIN {
	while ((getline l < (W "/tasks")) > 0) { split(l, ar, "\t"); nt++; TID[nt] = ar[1]; ISTASK[ar[1]] = 1 }
	while ((getline l < (W "/items")) > 0) { split(l, ar, "\t"); ni++; IK[ni] = ar[1] " #" ar[2]; IS[ni] = ar[1]; ITX[ni] = ar[3] }
	while ((getline l < (W "/steps")) > 0) { ns++; S[ns] = l }
	while ((getline l < (W "/affected")) > 0) { split(l, ar, "\t"); na++; AP[na] = ar[1]; AS[na] = ar[2] }
	while ((getline l < (W "/manifest")) > 0) { l = trim(l); if (l == "" || l ~ /^#/) continue; INMAN[base(l)] = 1 }
	while ((getline l < (W "/stepids")) > 0) { split(l, ar, "\t"); nsi++; SIS[nsi] = ar[1]; SID[nsi] = ar[2] }
	while ((getline l < (W "/cardids")) > 0) { split(l, ar, "\t"); c = ar[1]; sub(/^31-[^-]+-/, "", c); sub(/\.md$/, "", c); if (!((ar[2], c) in CI)) { CI[ar[2], c] = 1; CITED[ar[2]] = CITED[ar[2]] (CITED[ar[2]] == "" ? "" : ", ") c } }
	while ((getline l < (W "/pids")) > 0) if (l !~ /^#/ && l != "") { split(l, ar, "\t"); bad("planningids", base(ar[1]), "planning ID " ar[3] " in a code block: " ar[4], "reword the snippet comment") }
}
FNR == 1 { f = base(FILENAME); kind = (f ~ /^30-/) ? "unit" : "card"; id = f; sub(/^3[01]-/, "", id); sub(/\.md$/, "", id)
	if (kind == "card") { cu = id; sub(/-.*/, "", cu); ct = id; sub(/^[^-]+-/, "", ct); CARD[ct] = 1; CU[ct] = cu; FILEOF[ct] = f } else UNIT[id] = f
	if (!(f in INMAN)) bad("tasks", f, "part not in the manifest", "add it to manifest.txt or delete it")
	infiles = 0; HASPE[f] = 0; blk = 0 }
{ l = $0; sub(/\r$/, "", l) }
l ~ /^(```|~~~)/ { blk = !blk }
!blk && index(l, "<!-- fill:") { bad("fill", f ":" FNR, "fill marker left", "write that part of the card") }
kind == "card" && FNR <= 3 && l ~ /^### / { h = substr(l, 5); sub(/[ \t]+—.*$/, "", h); if (h != ct) bad("tasks", f, "heading is " h, "the file is for " ct) }
kind == "card" && l ~ /^\| \*\*Work unit\*\* \|/ { v = l; sub(/^\| \*\*Work unit\*\* \|[ \t]*/, "", v); sub(/[ \t]*\|[ \t]*$/, "", v); if (v != cu) bad("tasks", f, "Work unit is " v, "the file is under " cu) }
kind == "card" && l ~ /^\| \*\*Plan step\*\* \|/ { for (i = 1; i <= ns; i++) if (match(l, S[i] "([^0-9a-z]|$)")) { STEPCARD[S[i]] = STEPCARD[S[i]] (STEPCARD[S[i]] == "" ? "" : ", ") ct } }
l ~ /^\*\*In plain English:\*\*/ { HASPE[f] = 1; pe = substr(l, 22); if (pe ~ /`/ || pe ~ /[A-Za-z0-9_]\/[A-Za-z0-9_]/ || pe ~ /\.(cs|ts|js|py|md|asset|prefab|unity|json|asmdef)([^A-Za-z]|$)/) bad("plainenglish", f, "code, a path or a file name in the plain-English summary", "describe the outcome without code names")
	n = gsub(/[.!?]([ \t]|$)/, "&", pe); if (n > 4) bad("plainenglish", f, n " sentences in the plain-English summary", "2–4 sentences") }
kind == "unit" && l ~ /^- \[[ xX]\] / { for (i = 1; i <= ni; i++) if (index(l, ITX[i])) { if (!((i, id) in IU)) { IU[i, id] = 1; IN[i]++; UL[i] = UL[i] (UL[i] == "" ? "" : ", ") id } } }
kind == "card" && l ~ /^\*\*Files\*\*/ { infiles = 1; next }
kind == "card" && infiles && l ~ /^\*\*/ { infiles = 0 }
kind == "card" && infiles && match(l, /^- (new|change|changed|delete|deleted) `[^`]+`/) {
	p = substr(l, RSTART, RLENGTH); verb = p; sub(/^- /, "", verb); sub(/ .*/, "", verb); sub(/^[^`]*`/, "", p); sub(/`$/, "", p)
	nf++; FP[nf] = p; FV[nf] = verb; FT[nf] = ct }
END {
	for (i = 1; i <= ns; i++) if (!(S[i] in STEPCARD)) bad("steps", S[i], "no card names this plan step", "set a card'"'"'s Plan step, or add the missing task")
	for (i = 1; i <= nt; i++) { t = TID[i]; fn = ""; for (k in INMAN) if (k ~ ("^31-[^-]+-" t "\\.md$")) fn = k; if (fn == "") bad("tasks", t, "no card part in the manifest", "re-run skeleton-render.sh") }
	for (t in CARD) if (!(t in ISTASK)) bad("tasks", FILEOF[t], "card for a task the skeleton does not have", "remove it, or add the task to the skeleton")
	for (i = 1; i <= ni; i++) { if (IN[i] == 0) bad("donewhen", IK[i], "not found verbatim in any unit block", "copy it from the plan onto the unit the Done-when map names")
		else if (IN[i] > 1) bad("donewhen", IK[i], "in " IN[i] " unit blocks (" UL[i] ")", "keep it on one") }
	for (i = 1; i <= nsi; i++) if (!(SID[i] in CITED) && !((SIS[i], SID[i]) in MISS)) { MISS[SIS[i], SID[i]] = 1; bad("ids", SIS[i] " " SID[i], "cited by the plan step, on no card", "cite it on the card that implements it") }
	for (k = 1; k <= nf; k++) { hit = 0; unch = 0
		for (a = 1; a <= na; a++) if (same(FP[k], AP[a])) { if (AS[a] == "unchanged") unch = 1; else { hit = 1; if (!(a in BY) || index(BY[a], FT[k]) == 0) BY[a] = BY[a] (BY[a] == "" ? "" : ", ") FT[k] (FV[k] == "new" ? " (creates)" : "") } }
		if (!hit && unch) bad("files", FT[k], FP[k] " is marked unchanged in Affected Files", "drop it, or escalate")
		else if (!hit) bad("files", FT[k], FP[k] " is not in Affected Files", "drop it, or escalate") }
	for (a = 1; a <= na; a++) if (AS[a] != "unchanged" && !(a in BY)) bad("files", AP[a], "Affected Files row (" AS[a] ") on no card", "add it to a card'"'"'s Files")
	for (f in HASPE) if (!HASPE[f]) bad("plainenglish", f, "no **In plain English:** paragraph", "add one")

	ng = (NG == "") ? "Non-Goals" : NG
	nglink = (STYLE == "wiki") ? "[[" PBASE "#" ng "]]" : "[" ng "](" PBASE ".md)"
	print "## Coverage" > OUT; print "" > OUT
	print "| Plan step | Tasks | Its \"Done when\" items validated in |" > OUT; print "|---|---|---|" > OUT
	for (i = 1; i <= ns; i++) { s = S[i]; delete seen; us = ""
		for (j = 1; j <= ni; j++) if (IS[j] == s) { n = split(UL[j], uu, ", "); for (q = 1; q <= n; q++) if (uu[q] != "" && !(uu[q] in seen)) { seen[uu[q]] = 1; us = us (us == "" ? "" : ", ") uu[q] } }
		print "| " s " | " ((s in STEPCARD) ? STEPCARD[s] : "—") " | " (us == "" ? "—" : us) " |" > OUT }
	print "" > OUT; print "| Plan ID | Tasks |" > OUT; print "|---|---|" > OUT
	for (i = 1; i <= nsi; i++) { x = SID[i]; if (x in DONEID) continue; DONEID[x] = 1; print "| " x " | " ((x in CITED) ? CITED[x] : "—") " |" > OUT }
	print "" > OUT; print "| Affected file | Created / changed by |" > OUT; print "|---|---|" > OUT
	for (a = 1; a <= na; a++) print "| `" AP[a] "` | " (AS[a] == "unchanged" ? "unchanged" : ((a in BY) ? BY[a] : "—")) " |" > OUT
	print "" > OUT; print "Not covered by design: see the plan'"'"'s Non-Goals (" nglink ")." > OUT
	print "" > OUT; print "<!-- tt:end -->" > OUT
	exit (nb ? 1 : 0)
}' ${partfiles[@]+"${partfiles[@]}"} </dev/null
