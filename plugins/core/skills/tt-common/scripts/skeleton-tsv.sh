#!/usr/bin/env bash
# skeleton-tsv.sh: read a breakdown skeleton (tt-task-breakdown's
# templates/skeleton.md) into tab-separated records, so the scripts that
# check, render and scaffold from it read it one way.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: skeleton-tsv.sh <skeleton.md> meta | tasks | units | donewhen | checks

meta      key<TAB>value: plan, revision, base_sha, approved
tasks     id, title, executor, files, depends, traces, confirm, why, step, step title
          (step is the §N of the "### From §N. <title>" heading above the row)
units     id, outcome, tasks (expanded: "T01–T03" becomes "T01,T02,T03" by
          the tasks' order), validated by, depends on, parallel
donewhen  item ("§N #k"), first words, unit, checked by, why here
checks    unit, check text, who (from "- WU1: <text> (Agent)" lines)

Cells are trimmed; escaped pipes stay "\|". Columns are found by header text.
Exit: 0 printed, 1 the section has no rows, 2 usage error.
EOF
	exit 2
}

[ $# -eq 2 ] || usage
case "$1" in -h | --help) usage ;; esac
[ -f "$1" ] || { echo "skeleton-tsv.sh: no such file: $1" >&2; exit 2; }
case "$2" in meta | tasks | units | donewhen | checks) ;; *) usage ;; esac

tr -d '\r' <"$1" | awk -v WHAT="$2" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
function split_row(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|"); for (i = 1; i <= n; i++) { gsub(/\001/, "\\|", arr[i]); arr[i] = trim(arr[i]) }
	return n
}
function col(want,   i) { for (i = 1; i <= nh; i++) if (index(tolower(plain(h[i])), want) == 1) return i; return 0 }
function cell(name,   i) { i = C[name]; return (i ? c[i] : "") }
function dash(s) { return (s == "" ? "—" : s) }
# "T01–T03, T05" -> "T01,T02,T03,T05", ranges by the tasks order
function expand(s,   n, parts, i, a, b, p, q, j, out, pos) {
	gsub(/[ \t`]/, "", s); n = split(s, parts, ","); out = ""
	for (i = 1; i <= n; i++) {
		if (parts[i] == "" || parts[i] == "—" || parts[i] == "-") continue
		if (match(parts[i], /^[A-Z]+[0-9]+[a-z]?(–|-)[A-Z]+[0-9]+[a-z]?$/)) {
			p = parts[i]; sub(/(–|-).*$/, "", p); q = parts[i]; sub(/^.*(–|-)/, "", q)
			if ((p in POS) && (q in POS)) { for (j = POS[p]; j <= POS[q]; j++) out = out (out == "" ? "" : ",") ORDER[j]; continue }
		}
		out = out (out == "" ? "" : ",") parts[i]
	}
	return out
}
/^## / { sec = trim(substr($0, 4)); hdr = 1; next }
/^### From §/ { s = substr($0, 10); match(s, /^§[0-9]+[a-z]?/); step = substr(s, 1, RLENGTH); st = trim(substr(s, RLENGTH + 1)); sub(/^\.[ \t]*/, "", st); sub(/[ \t]*\(plan lines[^)]*\)[ \t]*$/, "", st); hdr = 1; next }
/^- Plan:/ { l = substr($0, 9); n = split(l, m, "·"); META["plan"] = trim(m[1]); for (i = 2; i <= n; i++) { v = trim(m[i]); if (v ~ /^revision /) META["revision"] = trim(substr(v, 10)); if (v ~ /^BASE_SHA /) META["base_sha"] = trim(substr(v, 10)) } }
/^- Approved:/ { v = trim(substr($0, 13)); sub(/[ \t]*<!--.*$/, "", v); META["approved"] = v }
/^[ \t]*\|/ && (sec == "Tasks" || sec == "Units" || sec == "Done-when map") {
	if (hdr) { nh = split_row($0, h); hdr = 0; sepr = 1; delete C
		if (sec == "Tasks") { C["id"] = col("task"); C["title"] = col("title"); C["ex"] = col("executor"); C["files"] = col("files"); C["dep"] = col("depends"); C["tr"] = col("traces"); C["cf"] = col("confirm"); C["why"] = col("why") }
		if (sec == "Units") { C["id"] = col("unit"); C["out"] = col("after this unit"); C["tasks"] = col("tasks"); C["val"] = col("validated"); C["dep"] = col("depends"); C["par"] = col("may run") }
		if (sec == "Done-when map") { C["item"] = col("item"); C["fw"] = col("first words"); C["unit"] = col("unit"); C["by"] = col("checked by"); C["why"] = col("why") }
		next }
	if (sepr) { sepr = 0; next }
	split_row($0, c)
	if (sec == "Tasks") { id = plain(cell("id")); if (id == "") next; nt++; ORDER[nt] = id; POS[id] = nt
		T[nt] = id "\t" cell("title") "\t" plain(cell("ex")) "\t" cell("files") "\t" dash(plain(cell("dep"))) "\t" cell("tr") "\t" dash(cell("cf")) "\t" cell("why") "\t" step "\t" st }
	if (sec == "Units") { id = plain(cell("id")); if (id == "") next; nu++; U[nu] = id; UO[nu] = cell("out"); UT[nu] = cell("tasks"); UV[nu] = plain(cell("val")); UD[nu] = dash(plain(cell("dep"))); UP[nu] = dash(cell("par")) }
	if (sec == "Done-when map") { it = plain(cell("item")); if (it == "") next; nd++; D[nd] = it "\t" cell("fw") "\t" plain(cell("unit")) "\t" plain(cell("by")) "\t" cell("why") }
	next
}
sec == "Unit checks" && /^- [A-Z]+[0-9]+[a-z]?:/ {
	l = substr($0, 3); u = l; sub(/:.*$/, "", u); t = trim(substr(l, length(u) + 2)); who = ""
	if (match(t, /\((Agent \+ Engineer|Agent|Engineer)\)[ \t]*$/)) { who = substr(t, RSTART + 1, RLENGTH - 2); sub(/\)[ \t]*$/, "", who); t = trim(substr(t, 1, RSTART - 1)) }
	nc++; K[nc] = u "\t" t "\t" who; next
}
END {
	if (WHAT == "meta") { for (k in META) { print k "\t" META[k]; any = 1 }; exit (any ? 0 : 1) }
	if (WHAT == "tasks") { for (i = 1; i <= nt; i++) print T[i]; exit (nt ? 0 : 1) }
	if (WHAT == "units") { for (i = 1; i <= nu; i++) print U[i] "\t" UO[i] "\t" expand(UT[i]) "\t" UV[i] "\t" UD[i] "\t" UP[i]; exit (nu ? 0 : 1) }
	if (WHAT == "donewhen") { for (i = 1; i <= nd; i++) print D[i]; exit (nd ? 0 : 1) }
	if (WHAT == "checks") { for (i = 1; i <= nc; i++) print K[i]; exit (nc ? 0 : 1) }
}'
