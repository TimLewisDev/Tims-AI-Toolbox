#!/usr/bin/env bash
# resolve-branch.sh: work out which branch to review and which base to compare
# it against, in any git repository. Needs git and bash only; writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: resolve-branch.sh [--repo <dir>] [--against <base>] [branch]

branch    the branch, tag or commit to review (default: the checked-out one).
          A name that exists only on the remote is read as origin/<name>.
--against the base to compare with. Without it the base is the remote's default
          branch (origin/HEAD), else the only one of main, master, develop and
          trunk that exists.

Prints key=value lines:
  branch      the ref that will be reviewed
  slug        the branch name made safe for a folder name
  head        its commit
  base        the ref it is compared with
  base_how    given | origin-head | only-candidate
  base_sha    the base's commit
  merge_base  the commit the branch left the base at
  commits     commits on the branch since then
  files       files changed
  diff_lines  lines added plus removed
  dirty       yes when the branch is checked out and has uncommitted changes
              (those are not reviewed), else no

Exit: 0 resolved, 1 cannot review (message on stderr: unknown ref, no base or
several candidates, no common ancestor, nothing changed), 2 usage error.
EOF
}

repo=.; against=""; branch=""
while [ $# -gt 0 ]; do
	case "$1" in
		--repo) [ $# -ge 2 ] || { usage; exit 2; }; repo=$2; shift 2 ;;
		--against) [ $# -ge 2 ] || { usage; exit 2; }; against=$2; shift 2 ;;
		-h | --help) usage; exit 2 ;;
		-*) usage; exit 2 ;;
		*) [ -z "$branch" ] || { usage; exit 2; }; branch=$1; shift ;;
	esac
done

g() { git -C "$repo" "$@"; }
die() { echo "resolve-branch.sh: $*" >&2; exit 1; }

g rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository: $repo"
g rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null || die "the repository has no commits"

# A ref name as given: a local one, else the same name on origin.
resolve_ref() {
	if g rev-parse --verify --quiet "$1^{commit}" >/dev/null; then printf '%s\n' "$1"
	elif g rev-parse --verify --quiet "origin/$1^{commit}" >/dev/null; then printf 'origin/%s\n' "$1"
	else return 1; fi
}

current=$(g symbolic-ref -q --short HEAD || true)
if [ -z "$branch" ]; then
	if [ -n "$current" ]; then branch=$current
	else branch=HEAD; fi
fi
ref=$(resolve_ref "$branch") || die "no such branch or commit: $branch"
head=$(g rev-parse "$ref^{commit}")

how=given
if [ -n "$against" ]; then
	base=$(resolve_ref "$against") || die "no such base: $against"
else
	base=""
	od=$(g symbolic-ref -q --short refs/remotes/origin/HEAD || true)
	if [ -n "$od" ] && [ "$od" != "$ref" ] && [ "$od" != "origin/$ref" ] &&
		g rev-parse --verify --quiet "$od^{commit}" >/dev/null; then
		base=$od; how=origin-head
	else
		found=""
		for n in main master develop trunk; do
			if [ "$n" = "$ref" ] || [ "origin/$n" = "$ref" ]; then continue; fi
			if b=$(resolve_ref "$n"); then found="$found $b"; fi
		done
		set -- $found
		case $# in
			0) die "cannot tell which base to compare $ref with: no origin/HEAD and none of main, master, develop, trunk. Pass --against <base>." ;;
			1) base=$1; how=only-candidate ;;
			*) die "cannot tell which base to compare $ref with: found $*. Pass --against <base>." ;;
		esac
	fi
fi
base_sha=$(g rev-parse "$base^{commit}")
[ "$base_sha" != "$head" ] || die "$ref and $base are the same commit: nothing to review"

mb=$(g merge-base "$base_sha" "$head" 2>/dev/null) || die "$ref and $base share no history: no common ancestor to compare from"
commits=$(g rev-list --count "$base_sha..$head")
g diff --quiet "$mb" "$head" && die "$ref has no file changes against $base ($commits commits, all cancelling out)"
files=$(g diff --numstat "$mb" "$head" | wc -l | tr -d ' ')
lines=$(g diff --numstat "$mb" "$head" | awk '$1 ~ /^[0-9]+$/ {n += $1 + $2} END {print n + 0}')

dirty=no
if [ -n "$current" ] && [ "$(g rev-parse "$current^{commit}")" = "$head" ] &&
	[ -n "$(g status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]; then dirty=yes; fi

slug=$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._-' '-')

printf 'branch=%s\nslug=%s\nhead=%s\nbase=%s\nbase_how=%s\nbase_sha=%s\nmerge_base=%s\ncommits=%s\nfiles=%s\ndiff_lines=%s\ndirty=%s\n' \
	"$ref" "$slug" "$head" "$base" "$how" "$base_sha" "$mb" "$commits" "$files" "$lines" "$dirty"
