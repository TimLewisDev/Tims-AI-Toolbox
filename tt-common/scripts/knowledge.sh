#!/usr/bin/env bash
# knowledge.sh: index and selectively route knowledge references.
set -u

usage() {
	cat >&2 <<'EOF'
usage: knowledge.sh index <repo> <output.tsv>
       knowledge.sh get <index.tsv> <scope> [topic ...]
       knowledge.sh trace <cache-dir> <skill> <scope> <matches>

index  Find marked knowledge references below the repository and write a TSV.
get    Print matching rows. A row matches its scope or "general", and any
       requested topic matches topics or triggers (fixed, case-insensitive).
trace  Append one compact retrieval event to the cache's retrieval.log.

Exit: 0 success, 1 no matches, 2 usage or environment error.
EOF
	exit 2
}

[ $# -ge 1 ] || usage
cmd=$1
shift

repo_key() {
	local repo=$1
	(cd "$repo" && pwd -P)
}

metadata() {
	awk '
		{sub(/\r$/, "")}
		NR == 1 && $0 == "---" { on = 1; next }
		on && $0 == "---" { exit }
		on && /^kind:[[:space:]]*/ { sub(/^kind:[[:space:]]*/, ""); print "kind\t" $0 }
		on && /^scope:[[:space:]]*/ { sub(/^scope:[[:space:]]*/, ""); print "scope\t" $0 }
		on && /^topics:[[:space:]]*/ { sub(/^topics:[[:space:]]*/, ""); print "topics\t" $0 }
		on && /^triggers:[[:space:]]*/ { sub(/^triggers:[[:space:]]*/, ""); print "triggers\t" $0 }
		on && /^load:[[:space:]]*/ { sub(/^load:[[:space:]]*/, ""); print "load\t" $0 }
	' "$1"
}

clean_list() {
	printf '%s' "$1" | sed 's/^\[//; s/\]$//; s/, /,/g; s/,/;/g; s/^ *//; s/ *$//'
}

source_hash() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

cmd_index() {
	[ $# -eq 2 ] || usage
	local repo out file meta kind scope topics triggers load rel hash count=0
	repo=$(repo_key "$1"); out=$2
	[ -d "$repo" ] || { echo "knowledge.sh: no such repository: $1" >&2; exit 2; }
	mkdir -p "$(dirname "$out")" || { echo "knowledge.sh: cannot create output directory" >&2; exit 2; }
	: >"$out" || { echo "knowledge.sh: cannot write $out" >&2; exit 2; }
	while IFS= read -r file; do
		meta=$(metadata "$file")
		kind=$(printf '%s\n' "$meta" | awk -F'\t' '$1=="kind"{print $2; exit}')
		[ "$kind" = knowledge ] || continue
		scope=$(printf '%s\n' "$meta" | awk -F'\t' '$1=="scope"{print $2; exit}')
		topics=$(printf '%s\n' "$meta" | awk -F'\t' '$1=="topics"{print $2; exit}')
		triggers=$(printf '%s\n' "$meta" | awk -F'\t' '$1=="triggers"{print $2; exit}')
		load=$(printf '%s\n' "$meta" | awk -F'\t' '$1=="load"{print $2; exit}')
		[ -n "$scope" ] && [ -n "$topics" ] && [ -n "$triggers" ] || {
			echo "knowledge.sh: incomplete metadata: $file" >&2
			continue
		}
		[ "$load" = whole ] || load=section
		rel=${file#"$repo"/}
		hash=$(source_hash "$file")
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rel" "$scope" "$(clean_list "$topics")" "$(clean_list "$triggers")" "$load" "$hash" >>"$out"
		count=$((count + 1))
	done < <(find "$repo" -type f -name '*.md' \
		-not -path "$repo/.git/*" -not -path "$repo/.tt/*" \
		-not -path "$repo/docs/patch-notes/*" -print | sort)
	echo "indexed $count knowledge source(s) -> $out"
	[ "$count" -gt 0 ]
}

matches_topic() {
	local needle=$1 hay=$2
	printf '%s\n' "$hay" | tr '[:upper:]' '[:lower:]' | tr ';' '\n' | \
		awk -v n="$(printf '%s' "$needle" | tr '[:upper:]' '[:lower:]')" '
			{ gsub(/^ +| +$/, ""); if ($0 == n || index(n, $0) == 1 || index($0, n) == 1) found=1 }
			END { exit !found }'
}

cmd_get() {
	[ $# -ge 2 ] || usage
	local index=$1 scope=$2 topic row path rscope topics triggers load hash found=0
	shift 2
	[ -f "$index" ] || { echo "knowledge.sh: no such index: $index" >&2; exit 2; }
	while IFS=$'\t' read -r path rscope topics triggers load hash; do
		[ -n "$path" ] || continue
		[ "$rscope" = "$scope" ] || [ "$rscope" = general ] || continue
		if [ $# -eq 0 ]; then
			printf '%s\n' "$path"
			found=1
			continue
		fi
		for topic in "$@"; do
			if matches_topic "$topic" "$topics;$triggers"; then
				printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$path" "$rscope" "$topics" "$triggers" "$load" "$hash"
				found=1
				break
			fi
		done
	done <"$index"
	[ "$found" -eq 1 ]
}

cmd_trace() {
	[ $# -eq 4 ] || usage
	local cache=$1 skill=$2 scope=$3 matches=$4
	mkdir -p "$cache" || { echo "knowledge.sh: cannot create $cache" >&2; exit 2; }
	printf '%s\t%s\t%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$skill" "$scope" "$matches" >>"$cache/retrieval.log"
}

case "$cmd" in
	index) cmd_index "$@" ;;
	get) cmd_get "$@" ;;
	trace) cmd_trace "$@" ;;
	-h|--help) usage ;;
	*) usage ;;
esac
