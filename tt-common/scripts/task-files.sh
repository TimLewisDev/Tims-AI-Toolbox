#!/usr/bin/env bash
# task-files.sh: record the working tree before a task starts, then list the
# files the task actually changed and check them against its card's Files
# list, so the orchestrator never reads a diff to find out.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: task-files.sh snapshot <task breakdown.md> <run folder> <task ID> [--repo <path>]
       task-files.sh diff     <task breakdown.md> <run folder> <task ID> [--repo <path>]

snapshot  Before the task starts: writes <run>/snapshots/<ID>.tsv, every path
          git reports as changed or untracked, with its content hash. Earlier
          tasks' uncommitted work is in it, so it isn't counted again.
diff      After the task: prints one row per file changed since the snapshot,
            <new|change|delete><TAB><path><TAB><on card|NOT ON CARD>
          then one row per card file left alone,
            untouched<TAB><path><TAB>on card
          then "files: <n> changed, <m> not on the card, <k> card files untouched".
          The card's files are the backticked paths under its "**Files**"
          heading; a path ending in "/" covers everything below it. Paths under
          a ".tt/" folder (run files) are ignored.

The repo defaults to the breakdown header's "**Repo:**" path.

Exit: 0 written or every change is on the card, 1 a change is not on the card,
2 usage error (no snapshot, unknown task, not a git repo).
EOF
	exit 2
}

die() { echo "task-files.sh: $*" >&2; exit 2; }

[ $# -ge 4 ] || usage
case "$1" in -h | --help) usage ;; snapshot | diff) ;; *) usage ;; esac
cmd=$1; bd=$2; run=$3; id=$4; shift 4
repo=""
while [ $# -gt 0 ]; do case "$1" in --repo) repo=${2:?}; shift 2 ;; *) usage ;; esac; done
[ -f "$bd" ] || die "no such file: $bd"
if [ -z "$repo" ]; then
	repo=$(tr -d '\r' <"$bd" | sed -n '1,25p' | sed -n 's/.*\*\*Repo:\*\*[^`]*`\([^`]*\)`.*/\1/p' | head -n 1)
	[ -n "$repo" ] || die "no **Repo:** in the breakdown header; pass --repo"
fi
repo=$(printf '%s' "$repo" | sed 's#\\#/#g')
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $repo"
snap="$run/snapshots/$id.tsv"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Every changed or untracked path (both sides of a rename), with its hash or
# "deleted". -z keeps names with spaces or quotes intact.
dirty() {
	local entry st path
	git -C "$repo" status --porcelain=v1 -z -uall | {
		while IFS= read -r -d '' entry; do
			st=${entry:0:2}; path=${entry:3}
			printf '%s\n' "$path"
			case "$st" in R* | C*) IFS= read -r -d '' path && printf '%s\n' "$path" ;; esac
		done
	} | grep -v -e '^\.tt/' -e '/\.tt/' | sort -u
}
hashes() {
	local path
	while IFS= read -r path; do
		if [ -f "$repo/$path" ]; then printf '%s\t%s\n' "$path" "$(git -C "$repo" hash-object -- "$path" 2>/dev/null)"
		else printf '%s\t%s\n' "$path" deleted; fi
	done
}

if [ "$cmd" = snapshot ]; then
	mkdir -p "$run/snapshots"
	dirty | hashes >"$snap"
	echo "snapshot: $(wc -l <"$snap" | tr -d ' ') dirty path(s) before $id -> $snap"
	exit 0
fi

[ -f "$snap" ] || die "no snapshot for $id: run task-files.sh snapshot before the task starts"

# The card's Files list.
bash "$(dirname "$0")/md-section.sh" get "$bd" "### $id —" 2>/dev/null | tr -d '\r' >"$work/section" || true
[ -s "$work/section" ] || die "no \"### $id —\" card in the breakdown"
awk '
/^\*\*Files\*\*/ { on = 1; next }
on && (/^\*\*/ || /^#/) { exit }
on && /^[ \t]*[-*] / { l = $0; if (match(l, /`[^`]+`/)) print substr(l, RSTART + 1, RLENGTH - 2) }' "$work/section" >"$work/card"

# Changed since the snapshot: a new hash, gone, or no longer dirty (reverted).
{ cut -f1 "$snap"; dirty; } | sort -u | hashes >"$work/now"
awk -F '\t' -v SNAP="$snap" '
BEGIN { while ((getline l < SNAP) > 0) { split(l, a, "\t"); was[a[1]] = a[2] } }
(($1 in was) && was[$1] == $2) { next }
{ print ($2 == "deleted" ? "delete" : (($1 in was) && was[$1] != "deleted") ? "change" : "new") "\t" $1 }' "$work/now" >"$work/changed"
# "new" vs "change" for a file the snapshot didn't have: is it in HEAD?
while IFS=$'\t' read -r kind path; do
	if [ "$kind" = new ] && git -C "$repo" cat-file -e "HEAD:$path" 2>/dev/null; then kind=change; fi
	printf '%s\t%s\n' "$kind" "$path"
done <"$work/changed" >"$work/kinds"

awk -F '\t' -v CARD="$work/card" '
BEGIN { while ((getline l < CARD) > 0) { nc++; card[nc] = l } }
function oncard(p,   i, r) {
	r = 0
	for (i = 1; i <= nc; i++)
		if (p == card[i] || (card[i] ~ /\/$/ && index(p, card[i]) == 1)) { hit[i] = 1; r = 1 }
	return r
}
{ n++; if (oncard($2)) print $1 "\t" $2 "\ton card"; else { off++; print $1 "\t" $2 "\tNOT ON CARD" } }
END {
	for (i = 1; i <= nc; i++) if (!hit[i]) { left++; print "untouched\t" card[i] "\ton card" }
	printf "files: %d changed, %d not on the card, %d card files untouched\n", n, off, left
	exit (off > 0 ? 1 : 0)
}' "$work/kinds"
