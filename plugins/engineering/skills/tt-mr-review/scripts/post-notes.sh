#!/usr/bin/env bash
# post-notes.sh: post approved review findings to a GitLab MR as inline notes
# (falling back to a general note), plus an optional summary note.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: post-notes.sh --project <url-encoded path> --mr <iid> --target <branch> --source <branch>
                     [--summary <summary.md>] [--dry-run] <approved.tsv> <bodies dir>

approved.tsv: tab-separated, with a header line; columns n, file, line (in the
new file), then anything else. The comment body for row n is <bodies dir>/<n>.md.
Position SHAs: base = merge-base of origin/<target> and origin/<source>,
head = origin/<source>, start = origin/<target> (run git fetch first).
An inline note that fails is re-posted as a general note naming file:line.

Prints one line per finding: n<TAB>inline | general (fallback) | failed<TAB>detail.
Exit: 0 all posted, 1 some failed, 2 usage or environment error.
EOF
	exit 2
}

project=""; mr=""; target=""; source=""; summary=""; dry=0
while [ $# -gt 0 ]; do
	case "$1" in
		--project) project=${2:?}; shift 2 ;;
		--mr) mr=${2:?}; shift 2 ;;
		--target) target=${2:?}; shift 2 ;;
		--source) source=${2:?}; shift 2 ;;
		--summary) summary=${2:?}; shift 2 ;;
		--dry-run) dry=1; shift ;;
		-h | --help) usage ;;
		-*) usage ;;
		*) break ;;
	esac
done
[ -n "$project" ] && [ -n "$mr" ] && [ -n "$target" ] && [ -n "$source" ] && [ $# -eq 2 ] || usage
tsv=$1; bodies=$2
[ -f "$tsv" ] || { echo "post-notes.sh: no such file: $tsv" >&2; exit 2; }
[ -d "$bodies" ] || { echo "post-notes.sh: no such folder: $bodies" >&2; exit 2; }
command -v glab >/dev/null || { echo "post-notes.sh: glab not found" >&2; exit 2; }

base_sha=$(git merge-base "origin/$target" "origin/$source")
head_sha=$(git rev-parse "origin/$source")
start_sha=$(git rev-parse "origin/$target")

api() { if [ $dry -eq 1 ]; then echo "DRY: glab api $*" >&2; else glab api "$@"; fi; }

failed=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tr -d '\r' <"$tsv" | tail -n +2 | while IFS=$'\t' read -r n file line _rest; do
	[ -n "$n" ] || continue
	body="$bodies/$n.md"
	if [ ! -f "$body" ]; then printf '%s\tfailed\tno body file %s\n' "$n" "$body"; continue; fi
	if out=$(api -X POST "projects/$project/merge_requests/$mr/discussions" \
		-F "body=@$body" \
		-f "position[position_type]=text" \
		-f "position[base_sha]=$base_sha" \
		-f "position[head_sha]=$head_sha" \
		-f "position[start_sha]=$start_sha" \
		-f "position[new_path]=$file" \
		-f "position[new_line]=$line" 2>&1); then
		printf '%s\tinline\t%s:%s\n' "$n" "$file" "$line"
	else
		{ printf '`%s:%s`\n\n' "$file" "$line"; cat "$body"; } >"$tmp/$n.md"
		if out2=$(api -X POST "projects/$project/merge_requests/$mr/notes" -F "body=@$tmp/$n.md" 2>&1); then
			printf '%s\tgeneral (fallback)\tinline failed: %s\n' "$n" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
		else
			printf '%s\tfailed\t%s\n' "$n" "$(printf '%s' "$out2" | tr '\n' ' ' | cut -c1-200)"
			touch "$tmp/failed"
		fi
	fi
done
if [ -n "$summary" ]; then
	if api -X POST "projects/$project/merge_requests/$mr/notes" -F "body=@$summary" >/dev/null 2>&1; then
		printf 'summary\tposted\t%s\n' "$summary"
	else
		printf 'summary\tfailed\t%s\n' "$summary"; touch "$tmp/failed"
	fi
fi
[ ! -f "$tmp/failed" ] || failed=1
exit $failed
