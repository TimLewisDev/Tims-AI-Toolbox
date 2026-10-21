#!/usr/bin/env bash
# skeleton-check.sh: check a breakdown skeleton against its Comprehensive Tech
# Plan before the engineer reviews it: every step sliced, every task in one
# unit, units consecutive, every "Done when" item placed once, files inside
# the plan's Affected Files.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: skeleton-check.sh <draft folder> [--plan <plan.md>]

Reads <draft>/skeleton.md (the plan path defaults to its "- Plan:" line) and
prints one TSV row per defect: check<TAB>where<TAB>what<TAB>suggested fix.
  steps      a plan step ("### §N.") with no task
  units      a task in no unit or in two; a unit naming an unknown task; a
             unit whose tasks aren't consecutive, or out of order with the
             units before it
  depends    a dependency that isn't a task, or that sits in a later unit
  parallel   tasks marked parallel whose Files overlap or that depend on
             each other
  donewhen   a plan "Done when" item (donewhen.sh numbering) missing from the
             Done-when map or placed twice; a map item the plan doesn't have;
             an unknown unit; a unit before the one holding the step's first
             task; a missing or unknown "Checked by"
  files      an Affected Files row (not unchanged) no task creates or changes;
             a task file outside Affected Files, or one the plan marks
             unchanged
Paths match by suffix ("Strategy.Ships/X.cs" matches
"Assets/Scripts/Strategy.Ships/X.cs"); "{A, B}" braces are expanded.
Non-Goals need judgement and are not checked.

Exit: 0 no defects, 1 defects, 2 usage error.
EOF
	exit 2
}

[ $# -ge 1 ] || usage
case "$1" in -h | --help) usage ;; esac
draft=$1; shift
plan=""
while [ $# -gt 0 ]; do case "$1" in --plan) plan=${2:?}; shift 2 ;; *) usage ;; esac; done
sk="$draft/skeleton.md"
[ -f "$sk" ] || { echo "skeleton-check.sh: no skeleton: $sk" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
[ -n "$plan" ] || plan=$(bash "$here/skeleton-tsv.sh" "$sk" meta | awk -F'\t' '$1 == "plan" { print $2 }')
plan=$(printf '%s' "$plan" | sed 's/^`//; s/`$//')
[ -f "$plan" ] || { echo "skeleton-check.sh: no such plan: ${plan:-?} (pass --plan)" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bash "$here/skeleton-tsv.sh" "$sk" tasks >"$work/tasks" || true
bash "$here/skeleton-tsv.sh" "$sk" units >"$work/units" || true
bash "$here/skeleton-tsv.sh" "$sk" donewhen >"$work/map" || true
bash "$here/donewhen.sh" "$plan" >"$work/items" || true
tr -d '\r' <"$plan" | awk '/^#+[ \t]+§[0-9]+[a-z]?\./ { s = $0; sub(/^#+[ \t]+/, "", s); match(s, /^§[0-9]+[a-z]?/); print substr(s, 1, RLENGTH) }' >"$work/steps"
# Affected Files: path<TAB>status, braces expanded.
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

awk -F'\t' -v W="$work" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function bad(c, w, m, f) { printf "%s\t%s\t%s\t%s\n", c, w, m, f; nb++ }
function norm(p) { gsub(/\\/, "/", p); sub(/^\.\//, "", p); return p }
function same(a, b) { a = norm(a); b = norm(b); return a == b || (length(a) > length(b) && substr(a, length(a) - length(b)) == "/" b) || (length(b) > length(a) && substr(b, length(b) - length(a)) == "/" a) }
function paths(cell, arr,   n, p) { n = 0; while (match(cell, /`[^`]+`/)) { p = substr(cell, RSTART + 1, RLENGTH - 2); cell = substr(cell, RSTART + RLENGTH); if (p ~ /[\/.]/) arr[++n] = p }; return n }
FILENAME ~ /tasks$/ { nt++; TID[nt] = $1; POS[$1] = nt; TF[$1] = $4; TD[$1] = $5; TS[$1] = $9; HASSTEP[$9] = 1; next }
FILENAME ~ /units$/ { nu++; UID[nu] = $1; UPOS[$1] = nu; UT[$1] = $3; UP[$1] = $6; next }
FILENAME ~ /map$/ { nm++; MI[nm] = $1; MU[$1] = MU[$1] (MU[$1] == "" ? "" : ",") $3; MB[$1] = $4; MC[$1]++; next }
FILENAME ~ /items$/ { key = $1 " #" $2; PI[key] = 1; PS[key] = $1; ni++; IK[ni] = key; next }
FILENAME ~ /steps$/ { ns++; S[ns] = $1; next }
FILENAME ~ /affected$/ { na++; AP[na] = $1; AS[na] = $2; next }
END {
	# steps
	for (i = 1; i <= ns; i++) if (!(S[i] in HASSTEP)) bad("steps", S[i], "no task slices this plan step", "add its tasks under \"### From " S[i] ". …\"")
	# units
	for (j = 1; j <= nu; j++) { u = UID[j]; n = split(UT[u], ts, ","); prev = 0
		for (k = 1; k <= n; k++) { t = ts[k]
			if (!(t in POS)) { bad("units", u, "names " t ", which is not a task", "fix the unit'"'"'s Tasks"); continue }
			IN[t] = IN[t] (IN[t] == "" ? "" : ",") u; TU[t] = u
			if (prev && POS[t] != prev + 1) bad("units", u, "tasks are not consecutive (" UT[u] ")", "reorder tasks or units so each unit is a run of consecutive IDs")
			prev = POS[t]
		}
		first = POS[ts[1]]; if (j > 1 && last_end && first < last_end) bad("units", u, "starts before the previous unit ends", "order units by their tasks")
		if (prev) last_end = prev
	}
	for (i = 1; i <= nt; i++) { t = TID[i]
		if (IN[t] == "") bad("units", t, "in no unit", "add it to a unit")
		else if (IN[t] ~ /,/) bad("units", t, "in more than one unit (" IN[t] ")", "keep it in one")
	}
	# depends
	for (i = 1; i <= nt; i++) { t = TID[i]; n = split(TD[t], ds, /[ ,]+/)
		for (k = 1; k <= n; k++) { d = ds[k]; if (d == "" || d == "—" || d == "-") continue
			if (!(d in POS)) bad("depends", t, "depends on " d ", which is not a task", "fix Depends on")
			else if ((d in TU) && (t in TU) && UPOS[TU[d]] > UPOS[TU[t]]) bad("depends", t, "depends on " d " in a later unit (" TU[d] ")", "move one of them") }
	}
	# parallel
	for (j = 1; j <= nu; j++) { u = UID[j]; p = UP[u]; if (p == "—" || p == "") continue
		gsub(/[`*]/, "", p); n = split(p, groups, /[;,]/)
		for (g = 1; g <= n; g++) { m = split(groups[g], pt, /[ \t]*(∥|\|\||&)[ \t]*/); for (a = 1; a <= m; a++) pt[a] = trim(pt[a])
			for (a = 1; a <= m; a++) for (b = a + 1; b <= m; b++) { x = pt[a]; y = pt[b]; if (!(x in POS) || !(y in POS)) continue
				na1 = paths(TF[x], fx); nb1 = paths(TF[y], fy)
				for (q = 1; q <= na1; q++) for (r = 1; r <= nb1; r++) if (same(fx[q], fy[r])) bad("parallel", u, x " and " y " both touch " fx[q], "run them in order")
				if (index(" " TD[y] ",", x) || index(" " TD[x] ",", y)) bad("parallel", u, x " and " y " depend on each other", "run them in order") } }
	}
	# donewhen
	for (i = 1; i <= ni; i++) { key = IK[i]
		if (!(key in MC)) { bad("donewhen", key, "plan item not in the Done-when map", "place it on the first unit where it can be observed"); continue }
		if (MC[key] > 1) bad("donewhen", key, "placed " MC[key] " times (" MU[key] ")", "place it once")
		u = MU[key]; if (!(u in UPOS)) { bad("donewhen", key, "unit " u " is not in Units", "fix the unit"); continue }
		minu = 0; for (t in TS) if (TS[t] == PS[key] && (t in TU)) if (!minu || UPOS[TU[t]] < minu) minu = UPOS[TU[t]]
		if (minu && UPOS[u] < minu) bad("donewhen", key, "placed on " u ", before the unit holding the step'"'"'s first task", "place it on that unit or later")
		b = MB[key]; if (b == "") bad("donewhen", key, "no Checked by", "Agent, Engineer or Agent + Engineer")
		else if (b != "Agent" && b != "Engineer" && b != "Agent + Engineer") bad("donewhen", key, "Checked by \"" b "\"", "Agent, Engineer or Agent + Engineer")
	}
	for (i = 1; i <= nm; i++) if (!(MI[i] in PI)) bad("donewhen", MI[i], "map item the plan doesn'"'"'t have (donewhen.sh numbering)", "renumber it with donewhen.sh")
	# files
	for (i = 1; i <= nt; i++) { t = TID[i]; n = paths(TF[t], fs)
		for (k = 1; k <= n; k++) { hit = 0; unch = 0
			for (a = 1; a <= na; a++) if (same(fs[k], AP[a])) { if (AS[a] == "unchanged") unch = 1; else { hit = 1; USED[a] = 1 } }
			if (!hit && unch) bad("files", t, fs[k] " is marked unchanged in Affected Files", "drop it, or escalate if the step needs it")
			else if (!hit) bad("files", t, fs[k] " is not in Affected Files", "drop it, or escalate: the plan does not list it") }
	}
	for (a = 1; a <= na; a++) if (AS[a] != "unchanged" && !(a in USED)) bad("files", AP[a], "Affected Files row (" AS[a] ") that no task creates or changes", "add it to a task'"'"'s Files")
	exit (nb ? 1 : 0)
}' "$work/tasks" "$work/units" "$work/map" "$work/items" "$work/steps" "$work/affected"
