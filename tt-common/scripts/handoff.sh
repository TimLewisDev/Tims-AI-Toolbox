#!/usr/bin/env bash
# handoff.sh: print the filled-in coder handoff prompt for one task, so the
# orchestrator passes it on unchanged instead of typing it out.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: handoff.sh <task breakdown.md> <task status.md> <task ID> --run <run folder>
                  [--repo <path>] [--plan <plan.md>] [--base-sha <sha>]

Fills the fenced prompt in tt-execute/templates/handoff.md from:
  the task's Task Map row (title, work unit) and its unit's heading (name);
  the breakdown header: the plan link (as continue-preflight.sh resolves it),
  "**Repo:**" path and base, "**Build check:**";
  BASE_SHA: --base-sha, else origin/<base>, else <base>, in the repo.
<your changed files> is left for the coder. Prints the prompt only.

Exit: 0 printed, 2 usage error (unknown task, missing header field, no template).
EOF
	exit 2
}

die() { echo "handoff.sh: $*" >&2; exit 2; }

[ $# -ge 3 ] || usage
case "$1" in -h | --help) usage ;; esac
bd=$1; status=$2; id=$3; shift 3
run=""; repo=""; plan=""; sha=""
while [ $# -gt 0 ]; do
	case "$1" in
		--run) run=${2:?}; shift 2 ;;
		--repo) repo=${2:?}; shift 2 ;;
		--plan) plan=${2:?}; shift 2 ;;
		--base-sha) sha=${2:?}; shift 2 ;;
		*) usage ;;
	esac
done
[ -n "$run" ] || usage
[ -f "$bd" ] || die "no such file: $bd"
[ -f "$status" ] || die "no such file: $status"
here=$(cd "$(dirname "$0")" && pwd)
common=$(cd "$here/.." && { pwd -W 2>/dev/null || pwd; })
tpl="$common/../tt-execute/templates/handoff.md"
[ -f "$tpl" ] || die "no handoff template: $tpl"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$bd" >"$work/bd"

head_bd=$(sed -n '1,25p' "$work/bd")
if [ -z "$repo" ]; then
	repo=$(printf '%s\n' "$head_bd" | sed -n 's/.*\*\*Repo:\*\*[^`]*`\([^`]*\)`.*/\1/p' | head -n 1)
	[ -n "$repo" ] || die "no **Repo:** in the breakdown header; pass --repo"
fi
repo=$(printf '%s' "$repo" | sed 's#\\#/#g')
base=$(printf '%s\n' "$head_bd" | grep -m1 '\*\*Repo:\*\*' | sed -n 's/.*base `\([^`]*\)`.*/\1/p')
[ -n "$base" ] || die "no base branch on the breakdown's **Repo:** line"
build=$(printf '%s\n' "$head_bd" | sed -n 's/.*\*\*Build check:\*\*[ \t]*//p' | head -n 1)
[ -n "$build" ] || build="not recorded"
if [ -z "$plan" ]; then
	link=$(printf '%s\n' "$head_bd" | grep -m1 -i 'tech plan' | sed -n 's/.*\[\[\([^]|#]*\).*/\1/p')
	[ -n "$link" ] && plan="$(dirname "$bd")/$link.md"
	if [ -z "$link" ]; then
		link=$(printf '%s\n' "$head_bd" | grep -m1 -i 'tech plan' | sed -n 's/.*](\([^)#]*\).*/\1/p')
		[ -n "$link" ] && plan="$(dirname "$bd")/$(printf '%s' "$link" | sed 's/%20/ /g')"
	fi
fi
[ -n "$plan" ] || die "no plan link in the breakdown header; pass --plan"
if [ -z "$sha" ]; then
	sha=$(git -C "$repo" rev-parse --verify -q "origin/$base^{commit}" 2>/dev/null ||
		git -C "$repo" rev-parse --verify -q "$base^{commit}" 2>/dev/null) || die "can't resolve $base in $repo; pass --base-sha"
fi

# The task's row in the Task Map: title and work unit, columns found by header.
row=$(awk -v ID="$id" '
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function cells(l, arr,   n, i, raw) {
	sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, raw, "|")
	for (i = 1; i <= n; i++) { arr[i] = trim(raw[i]); gsub(/`/, "", arr[i]) }
	return n
}
/^## / { sec = trim(substr($0, 4)); inhdr = 1; next }
sec == "Task Map" && /^[ \t]*\|/ {
	if (inhdr) { nh = cells($0, h); inhdr = 0; sep = 1
		for (i = 1; i <= nh; i++) { k = tolower(h[i]); if (k == "id") ci = i; else if (k == "task") ct = i; else if (index(k, "work unit") == 1) cw = i }
		next }
	if (sep) { sep = 0; next }
	cells($0, c)
	if (c[ci] == ID) { print c[ct] "\t" c[cw]; exit }
}' "$work/bd")
[ -n "$row" ] || die "no $id in the breakdown's Task Map"
title=${row%%$'\t'*}; wu=${row#*$'\t'}
[ -n "$wu" ] || die "$id has no work unit in the Task Map"
wuname=$(sed -n "s/^## $wu — //p" "$work/bd" | head -n 1)
[ -n "$wuname" ] || die "no \"## $wu — \" heading in the breakdown"

# The template's fenced block, with each placeholder replaced as plain text.
awk '/^```/ { if (in_) exit; in_ = 1; next } in_' "$tpl" >"$work/tpl"
[ -s "$work/tpl" ] || die "no fenced prompt in $tpl"
{
	printf '%s\t%s\n' "<ID>" "$id" "<title>" "$title" "<WU ID>" "$wu" "<name>" "$wuname" \
		"<breakdown path>" "$bd" "<plan path>" "$plan" "<status path>" "$status" \
		"<repo path>" "$repo" "<base>" "$base" "<BASE_SHA>" "$sha" \
		"<method, for reference only>" "$build" "<run>" "$run" "<common>" "$common"
} >"$work/pairs"
awk -v F="$work/pairs" '
BEGIN { while ((getline l < F) > 0) { n++; k[n] = substr(l, 1, index(l, "\t") - 1); v[n] = substr(l, index(l, "\t") + 1) } }
{
	out = $0
	for (i = 1; i <= n; i++) {
		res = ""
		while ((p = index(out, k[i])) > 0) { res = res substr(out, 1, p - 1) v[i]; out = substr(out, p + length(k[i])) }
		out = res out
	}
	print out
}' "$work/tpl"
