#!/usr/bin/env bash
# continue-preflight.sh: the mechanical part of resuming a breakdown. Checks a
# Task Status document against its Task Breakdown, its plan and the repo, and
# says whether any model work (plan drift, judging in-progress work) is needed.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: continue-preflight.sh <task status.md> <task breakdown.md> [--plan <plan.md>] [--repo <dir>]

Read-only. Prints a TSV of findings, then summary lines.

Findings: check<TAB>item<TAB>found<TAB>expected<TAB>kind
  kind is "fact" (needs the engineer's confirmation before it is corrected),
  "derived" (status-set.sh --refresh fixes it) or "judge" (the orchestrator
  reads the evidence and decides; nothing is wrong yet).
Checks:
  board      the boards and the breakdown's Work Units / Task Map agree: the
             same unit and task IDs, executors and unit membership
  branch     the current branch matches the header's Branch
  files      files an Implemented or Done task lists in its Step Log exist;
             files a Todo task's card creates ("- new `path`") don't yet
  progress   an In Progress task's card files that git shows as changed
             (kind judge: how far it got)
  stale      a unit with a validation attempt whose tasks' files changed
             after that attempt's Run time (by file time, so a checkout or
             pull that rewrote the file also counts; confirm with git log)
  derived    the header's derived lines disagree with status-counts.sh, or
             status-counts.sh reports a board inconsistency
Summary lines:
  plan: revision <read> (unchanged) | revision <read> -> <now> (drift)
  needs_model: no | yes (<reasons>)

The plan defaults to the breakdown header's first [[link]] or (link), resolved
beside the breakdown; the repo to the header's "**Repo:**" path.

Exit: 0 no findings and no drift, 1 findings or drift, 2 usage error.
EOF
	exit 2
}

die() { echo "continue-preflight.sh: $*" >&2; exit 2; }

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
status=$1; bd=$2; shift 2
plan=""; repo=""
while [ $# -gt 0 ]; do
	case "$1" in
		--plan) plan=${2:?}; shift 2 ;;
		--repo) repo=${2:?}; shift 2 ;;
		*) usage ;;
	esac
done
[ -f "$status" ] || die "no such file: $status"
[ -f "$bd" ] || die "no such file: $bd"
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$status" >"$work/status"
tr -d '\r' <"$bd" >"$work/bd"

head_bd=$(sed -n '1,25p' "$work/bd")
if [ -z "$repo" ]; then
	repo=$(printf '%s\n' "$head_bd" | sed -n 's/.*\*\*Repo:\*\*[^`]*`\([^`]*\)`.*/\1/p' | head -n 1)
	[ -n "$repo" ] || die "no **Repo:** in the breakdown header; pass --repo"
fi
repo=$(printf '%s' "$repo" | sed 's#\\#/#g')
[ -d "$repo" ] || die "no such repo folder: $repo"
if [ -z "$plan" ]; then
	link=$(printf '%s\n' "$head_bd" | grep -m1 -i 'tech plan' | sed -n 's/.*\[\[\([^]|#]*\).*/\1/p')
	[ -n "$link" ] && plan="$(dirname "$bd")/$link.md"
	if [ -z "$link" ]; then
		link=$(printf '%s\n' "$head_bd" | grep -m1 -i 'tech plan' | sed -n 's/.*](\([^)#]*\).*/\1/p')
		[ -n "$link" ] && plan="$(dirname "$bd")/$(printf '%s' "$link" | sed 's/%20/ /g')"
	fi
fi

findings="$work/findings"; : >"$findings"
add() { printf '%s\t%s\t%s\t%s\t%s\n' "$@" >>"$findings"; }
reasons=()

# Plan revision.
read_rev=$(printf '%s\n' "$head_bd" | sed -n 's/.*[Pp]lan read:[^0-9]*revision \([0-9][0-9]*\).*/\1/p' | head -n 1)
plan_line="plan: not checked (no plan found)"
drift=0
if [ -n "$plan" ] && [ "$plan" -ef "$bd" ]; then
	plan_line="plan: not checked (the document is its own plan)"
elif [ -n "$plan" ] && [ -f "$plan" ]; then
	now_rev=$(tr -d '\r' <"$plan" | sed -n '1,40p' | sed -n 's/.*Revision:\**[ \t]*\**\([0-9][0-9]*\).*/\1/p' | head -n 1)
	if [ -z "$read_rev" ] || [ -z "$now_rev" ]; then
		plan_line="plan: revision unknown (breakdown read '${read_rev:-?}', plan '${now_rev:-?}')"
	elif [ "$read_rev" = "$now_rev" ]; then
		plan_line="plan: revision $read_rev (unchanged)"
	else
		plan_line="plan: revision $read_rev -> $now_rev (drift)"; drift=1; reasons+=("plan drift: run the plan-drift brief")
	fi
fi

# Boards, Step Log files and validation run times from the status document.
awk -v OUT="$work" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
function split_row(l, arr,   n, i) {
	gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, arr, "|"); for (i = 1; i <= n; i++) gsub(/\001/, "\\|", arr[i])
	return n
}
function col(want, h, nh,   i) { for (i = 1; i <= nh; i++) if (index(tolower(plain(h[i])), want) == 1) return i; return 0 }
/^# / { sec = trim(substr($0, 3)); hdr = 1; ent = ""; next }
sec == "Status" && /^- Branch:/ { b = $0; if (match(b, /`[^`]+`/)) print substr(b, RSTART + 1, RLENGTH - 2) > (OUT "/branch") }
sec == "Status" && match($0, /^- (State|Progress|Current Unit|Current Task|Next):/) { k = substr($0, 3, RLENGTH - 3); print k "\t" trim(substr($0, RLENGTH + 1)) > (OUT "/header") }
(sec == "Task Board" || sec == "Work Unit Board") && /^[ \t]*\|/ {
	if (hdr) { nh = split_row($0, h); hdr = 0; sep = 1
		if (sec == "Task Board") { ti = col("id", h, nh); tx = col("executor", h, nh); tw = col("work unit", h, nh); ts = col("status", h, nh) }
		else { ui = col("id", h, nh); ut = col("tasks", h, nh); us = col("status", h, nh) }
		next }
	if (sep) { sep = 0; next }
	split_row($0, c)
	if (sec == "Task Board") print plain(c[ti]) "\t" plain(c[tx]) "\t" (tw ? plain(c[tw]) : "") "\t" plain(c[ts]) > (OUT "/tasks")
	else print plain(c[ui]) "\t" plain(c[ut]) "\t" plain(c[us]) > (OUT "/units")
	next
}
sec == "Step Log" && /^## / { e = substr($0, 4); sub(/[ \t]+—.*$/, "", e); ent = plain(e); infiles = 0; next }
sec == "Step Log" && ent != "" && /^- Files Modified:/ { infiles = 1; l = substr($0, 18) }
sec == "Step Log" && ent != "" && infiles {
	if ($0 ~ /^- / && $0 !~ /^- Files Modified:/) { infiles = 0; next }
	l = $0; while (match(l, /`[^`]+`/)) { p = substr(l, RSTART + 1, RLENGTH - 2); l = substr(l, RSTART + RLENGTH)
		kind = ($0 ~ /(^|[ \t-])(deleted?|removed?) /) ? "deleted" : "present"
		if (p ~ /[\/.]/ && p !~ /[ *]/) print ent "\t" kind "\t" p > (OUT "/logfiles") }
	next
}
sec == "Work Unit Validation" && /^## / { u = substr($0, 4); sub(/[ \t]+—.*$/, "", u); cu = plain(u); next }
sec == "Work Unit Validation" && cu != "" && /^- Run:/ { r = $0; if (match(r, /[0-9]{4}-[0-9]{2}-[0-9]{2}( [0-9]{2}:[0-9]{2})?/)) last[cu] = substr(r, RSTART, RLENGTH) }
END { for (u in last) print u "\t" last[u] > (OUT "/runs") }
' "$work/status"
touch "$work/tasks" "$work/units" "$work/logfiles" "$work/runs" "$work/header" "$work/branch"

# Board agreement with the breakdown.
if bash "$here/status-boards.sh" "$bd" >"$work/boards" 2>/dev/null; then
	awk -F'\t' -v OUT="$work/findings" '
	function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
	function plain(s) { gsub(/[`*]/, "", s); return trim(s) }
	function cells(l, arr,   n, i) { gsub(/\\\|/, "\001", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l); n = split(l, arr, "|"); for (i = 1; i <= n; i++) arr[i] = plain(arr[i]); return n }
	function f(c, i, fd, e) { printf "board\t%s\t%s\t%s\tfact\n", i, fd, e > OUT }
	# "T01–T05" and "T01, T02, …" name the same tasks.
	function tasklist(s,   n, i, parts, a, b, p, w, k, out) {
		gsub(/[ \t]/, "", s); n = split(s, parts, ","); out = ""
		for (i = 1; i <= n; i++) {
			if (match(parts[i], /^[A-Z]+[0-9]+(-|–)[A-Z]*[0-9]+$/)) {
				p = parts[i]; match(p, /^[A-Z]+/); pre = substr(p, 1, RLENGTH); rest = substr(p, RLENGTH + 1)
				split(rest, ab, /-|–/); a = ab[1]; b = ab[2]; sub(/^[A-Z]+/, "", b); w = length(a)
				for (k = a + 0; k <= b + 0; k++) out = out sprintf("%s%0" w "d,", pre, k)
			} else out = out parts[i] ","
		}
		return out
	}
	FILENAME ~ /boards$/ && /^# / { sec = substr($0, 3); hdr = 1; next }
	FILENAME ~ /boards$/ && /^\|/ { if (hdr) { hdr = 0; sep = 1; next }; if (sep) { sep = 0; next }
		cells($0, c); if (sec == "Task Board") { BT[c[1]] = 1; BX[c[1]] = c[3]; BW[c[1]] = c[4]; bo[++nb] = c[1] } else { BU[c[1]] = c[3]; uo[++nbu] = c[1] }; next }
	FILENAME ~ /\/tasks$/ { ST[$1] = 1; SX[$1] = $2; SW[$1] = $3; SS[$1] = $4; next }
	FILENAME ~ /\/units$/ { SU[$1] = $2; next }
	END {
		for (i = 1; i <= nb; i++) { t = bo[i]
			if (!(t in ST)) { f("", t, "missing from the Task Board", "in the Task Map"); continue }
			if (SX[t] != BX[t]) f("", t, "executor " SX[t], "executor " BX[t])
			if (SW[t] != BW[t]) f("", t, "unit " SW[t], "unit " BW[t]) }
		for (t in ST) if (!(t in BT) && SS[t] != "Dropped") f("", t, "on the Task Board", "not in the Task Map")
		for (i = 1; i <= nbu; i++) { u = uo[i]
			if (!(u in SU)) f("", u, "missing from the Work Unit Board", "in Work Units")
			else if (tasklist(SU[u]) != tasklist(BU[u])) f("", u, "tasks " SU[u], "tasks " BU[u]) }
	}' "$work/boards" "$work/tasks" "$work/units"
else
	add board "-" "no Work Units / Task Map tables read" "status-boards.sh output" fact
fi

# Branch.
want=$(head -n 1 "$work/branch")
if [ -n "$want" ]; then
	have=$(git -C "$repo" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
	[ "$have" = "$want" ] || add branch HEAD "$have" "$want" fact
fi

# Files: Step Log files of Implemented/Done tasks exist. A path that isn't
# repo-relative (a Step Log may write `Editor.meta` under a module heading)
# is matched by unique suffix against the repo's files; one that matches
# nothing and whose first folder isn't at the repo root can't be checked.
git -C "$repo" --no-optional-locks ls-files -co --exclude-standard 2>/dev/null >"$work/lsfiles" || : >"$work/lsfiles"
resolve() { # path -> repo-relative path, "?" (can't tell) or nothing (missing)
	local p=$1 first
	if [ -e "$repo/$p" ]; then printf '%s\n' "$p"; return; fi
	m=$(grep -F -- "/$p" "$work/lsfiles" | awk -v P="/$p" 'substr($0, length($0) - length(P) + 1) == P' | head -n 2)
	if [ "$(printf '%s' "$m" | grep -c .)" = 1 ]; then printf '%s\n' "$m"; return; fi
	first=${p%%/*}
	if [ "$first" = "$p" ] || [ ! -d "$repo/$first" ]; then echo "?"; fi
}
while IFS=$'\t' read -r t k p; do
	[ -n "$t" ] || continue
	s=$(awk -F'\t' -v T="$t" '$1 == T { print $4 }' "$work/tasks")
	case "$s" in Implemented | Done) ;; *) continue ;; esac
	r=$(resolve "$p")
	if [ "$k" = present ] && [ -z "$r" ]; then add files "$t" "missing: $p" "exists (Step Log, $s)" fact; fi
	if [ "$k" = deleted ] && [ -n "$r" ] && [ "$r" != "?" ]; then add files "$t" "exists: $p" "deleted (Step Log, $s)" fact; fi
	[ -n "$r" ] && [ "$r" != "?" ] && printf '%s\t%s\n' "$t" "$r" >>"$work/resolved"
done <"$work/logfiles"
touch "$work/resolved"

# Card files for Todo and In Progress tasks.
card_files() { # task ID -> "new|change<TAB>path" lines from its card's Files list
	bash "$here/md-section.sh" get "$work/bd" "### $1 —" 2>/dev/null | awk '
	/^\*\*Files\*\*/ { on = 1; next }
	on && /^\*\*/ { on = 0 }
	on && /^- (new|change|delete|deleted) `/ { k = $2; p = $0; sub(/^[^`]*`/, "", p); sub(/`.*/, "", p); print k "\t" p }'
}
while IFS=$'\t' read -r t x u s; do
	case "$s" in
		Todo)
			card_files "$t" | while IFS=$'\t' read -r k p; do
				[ "$k" = new ] && [ -e "$repo/$p" ] && add files "$t" "exists: $p" "not yet (Todo; the card creates it)" fact
				:
			done ;;
		"In Progress")
			changed=$(card_files "$t" | cut -f2 | while IFS= read -r p; do
				[ -n "$p" ] && git -C "$repo" --no-optional-locks status --porcelain -- "$p" 2>/dev/null | head -n 1
			done | wc -l | tr -d ' ')
			total=$(card_files "$t" | wc -l | tr -d ' ')
			add progress "$t" "$changed of $total card files changed (git status)" "the card's Steps" judge
			reasons+=("$t is In Progress: compare git diff on its card files with its Steps") ;;
	esac
done <"$work/tasks"

# Stale validation evidence.
while IFS=$'\t' read -r u run; do
	[ -n "$u" ] || continue
	# Run times are to the minute (a change within it is the run's own); a
	# date alone covers the whole day.
	case "$run" in *:*) run="$run:59" ;; *) run="$run 23:59:59" ;; esac
	since=$(date -d "$run" +%s 2>/dev/null) || continue
	files=$(awk -F'\t' -v U="$u" 'NR == FNR { if ($3 == U) T[$1] = 1; next } ($1 in T) { print $2 }' "$work/tasks" "$work/resolved" | sort -u)
	[ -n "$files" ] || continue
	# A committed file changed if a commit touching it is newer than the run
	# (a checkout doesn't count); an uncommitted change is judged by file time.
	newer=$(printf '%s\n' "$files" | while IFS= read -r p; do
		if [ -n "$(git -C "$repo" --no-optional-locks status --porcelain -- "$p" 2>/dev/null)" ]; then
			[ "$(date -r "$repo/$p" +%s 2>/dev/null || echo 0)" -gt "$since" ] && printf '%s (uncommitted)\n' "$p"
		else
			c=$(git -C "$repo" --no-optional-locks log -1 --format=%ct -- "$p" 2>/dev/null)
			[ -n "$c" ] && [ "$c" -gt "$since" ] && printf '%s\n' "$p"
		fi
		:
	done | head -n 5 | paste -sd ',' -)
	run=${run%:59}; run=${run% 23:59}
	[ -n "$newer" ] && add stale "$u" "changed after its $run attempt: $newer" "unchanged since validation" fact
done <"$work/runs"

# Derived header fields.
set +e
derived=$(bash "$here/status-counts.sh" "$work/status" 2>&1)
set -e
printf '%s\n' "$derived" | grep '^! ' | sed 's/^! //' | while IFS= read -r m; do add derived board "$m" "consistent boards" fact; done
printf '%s\n' "$derived" | grep -v '^! ' | while IFS= read -r l; do
	k=${l%%: *}; v=${l#*: }
	cur=$(awk -F'\t' -v K="$k" '$1 == K { print $2 }' "$work/header")
	# An annotated value ("None (T14 Implemented)") agrees with its prefix.
	[ -n "$cur" ] && [ "${cur#"$v"}" = "$cur" ] && add derived "$k" "$cur" "$v" derived
	:
done

printf 'check\titem\tfound\texpected\tkind\n'
cat "$findings"
echo "$plan_line"
if [ ${#reasons[@]} -gt 0 ]; then
	printf 'needs_model: yes (%s)\n' "$(printf '%s; ' "${reasons[@]}" | sed 's/; $//')"
else
	echo "needs_model: no"
fi
[ -s "$findings" ] || [ "$drift" = 1 ] && exit 1
exit 0
