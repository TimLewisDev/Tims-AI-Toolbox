#!/usr/bin/env bash
# guide.sh: Tatty, the tt toolbox guide. Says hello, works out where the tt
# documents in a folder stand and which command comes next, and prints README
# sections on request. Needs bash and awk only. Writes nothing.
set -u

usage() {
	cat >&2 <<'EOF'
usage: guide.sh [hello]                    the greeting, then "where ."
       guide.sh where [dir]                where the tt documents in dir stand, and the next command
       guide.sh start                      the README's "Where to start" table
       guide.sh about [name]               a skill's README entry, or a topic (documents, ids, work units, ...);
                                           with no name, the list of topics
       guide.sh init [dir]                 inspect project metadata and build a local context/index cache
       guide.sh refresh [dir]              rebuild the local project context/index cache
       guide.sh context [dir]              report whether the local project context cache is current
       guide.sh update [check|apply]       pull latest from git and fix missing symlinks;
                                           check (default) previews only, apply makes the changes
       guide.sh quip                       one quip

TT_GUIDE_ASCII=1 draws Tatty without box-drawing characters.
Exit: 0 ok, 1 "about" found nothing, 2 usage error.
EOF
}

# Resolve the skill link to the clone, where the README is. Git Bash's
# cd -P doesn't follow Windows junctions, but readlink -f does.
here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
skill=$(dirname "$here")
root=$(dirname "$skill")
readme="$root/README.md"
MD="$root/tt-common/scripts/md-section.sh"
[ -f "$MD" ] || MD="$(cd "$(dirname "$0")/../.." && pwd)/tt-common/scripts/md-section.sh"

TATTY="$root/tt-common/scripts/tatty.sh"
STATE="$root/tt-common/scripts/workflow-state.sh"
CONTEXT="$root/tt-common/scripts/project-context.sh"

quip() { bash "$TATTY" quip; }

# field <file> <regex>: the first line matching the regex, without CR
field() { awk -v re="$2" '{ sub(/\r$/, "") } $0 ~ re { print; exit }' "$1"; }

where() {
	local dir=${1:-.}
	[ -d "$dir" ] || { echo "guide.sh: no such folder: $dir" >&2; exit 2; }
	bash "$STATE" "$dir" && return 0
	echo "  New here? Or explore first with /tt-familiarise <topic>."
	echo "  Docs in a vault or another folder? Ask me to look there (guide.sh where <folder>)."
}


need_readme() {
	[ -f "$readme" ] && [ -f "$MD" ] && return 0
	echo "(I can't find the toolbox README beside this skill, so here's the short version.)"
	cat <<'EOF'
  explore code ............ /tt-familiarise <topic>
  plan a feature .......... /tt-adversarial-plan [idea, doc, spec or ticket]
  resume planning ......... /tt-adversarial-plan resume <draft plan>
  review or change a plan . /tt-tech-plan-review [tech plan]
  break it into tasks ..... /tt-task-breakdown <comprehensive tech plan>
  build ................... /tt-execute <task status>
  small change, no plan ... /tt-coder <plan, spec or ticket>
  small feature or a bug .. /tt-workflow-lite [bug | feature]
  chase a bug ............. /tt-debug <symptom>
  build a lite brief ...... /tt-execute-lite <lite brief>
  review an MR ............ /tt-mr-review [MR or branch]
EOF
	return 1
}

# sections <starts|contains> <text>: README headings (level 2-4) whose text
# starts with or contains the text, ignoring case (a fixed string, not a regex)
sections() {
	bash "$MD" index "$readme" | Q="$2" awk -F'\t' -v m="$1" '
		BEGIN { q = tolower(ENVIRON["Q"]) }
		$2 >= 2 && $2 <= 4 { i = index(tolower($4), q); if (m == "starts" ? i == 1 : i > 0) print }'
}

# topics: the README headings that aren't a skill's entry
topics() { sections contains "" | awk -F'\t' '$4 !~ /^\[`tt-/ { print "  " $4 }'; }

# show <index lines>: print each section
show() {
	local line ln end
	while IFS=$'\t' read -r ln _ end _; do
		sed -n "${ln},${end}p" "$readme" | tr -d '\r'
		echo
	done <<<"$1"
}

about() {
	need_readme || return 0
	local q hits row
	q=$(printf '%s' "$*" | tr '[:upper:]' '[:lower:]')
	if [ -z "$q" ]; then
		echo "Ask me about any tt-* skill, or one of these:"
		topics
		return 0
	fi
	case $q in docs | doc) q=documents ;; id | revisions) q=ids ;; units | wu | tasks) q="work units" ;;
		metrics | tokens) q="token log" ;; stages) q="planning stages" ;; esac
	local name=${q#tt-}
	if [ -d "$root/tt-$name" ]; then
		row=$(grep -F "| [\`tt-$name\`]" "$readme" | head -1 | tr -d '\r')
		[ -n "$row" ] && printf '%s\n\n' "$row"
		hits=$(sections starts "[\`tt-$name\`]")
		case $name in requirements | scope | approach | technical-design | plan-signoff)
			hits=$(sections starts "the planning stages") ;; esac
		if [ -n "$hits" ]; then
			show "$hits"
		elif [ -z "$row" ]; then
			field "$root/tt-$name/SKILL.md" '^name:'
			awk '/^description:/ { on = 1; next } on && /^[a-z-]+:/ { exit } on { sub(/^  /, ""); print }' "$root/tt-$name/SKILL.md"
		fi
		return 0
	fi
	hits=$(sections contains "$q")
	if [ -n "$hits" ]; then
		show "$hits"
		return 0
	fi
	echo "Nothing in the README about \"$*\". Try a skill name (tt-scope, execute, ...) or one of:"
	topics
	return 1
}

update() {
	local mode=${1:-check}
	local skills_dirs=(
		"$HOME/.claude/skills"
		"$HOME/.copilot/skills"
		"$HOME/.agents/skills"
	)

	is_windows_shell() {
		case ${OSTYPE:-} in
		msys* | cygwin* | win32*) return 0 ;;
		*) return 1 ;;
		esac
	}

	create_link() {
		local target=$1 link=$2
		if is_windows_shell && command -v powershell.exe >/dev/null 2>&1 &&
			command -v cygpath >/dev/null 2>&1; then
			local win_target win_link
			win_target=$(cygpath -w "$target")
			win_link=$(cygpath -w "$link")
			TT_LINK_PATH="$win_link" TT_TARGET_PATH="$win_target" \
				powershell.exe -NoProfile -NonInteractive -Command \
				'$ErrorActionPreference = "Stop"; New-Item -ItemType Junction -Path $env:TT_LINK_PATH -Target $env:TT_TARGET_PATH | Out-Null'
		else
			ln -s "$target" "$link"
		fi
	}

	check_links() {
		local skills_dir=$1
		printf '\nSymlink check (%s):\n' "$skills_dir"
		local ok=0 missing=0 broken=0 name link target expected
		for d in "$root"/tt-*/; do
			[ -d "$d" ] || continue
			name=$(basename "$d")
			link="$skills_dir/$name"
			expected=$(cd "$d" && pwd -P)
			if [ ! -e "$link" ] && [ ! -L "$link" ]; then
				printf '  MISSING   %s\n' "$name"
				missing=$((missing+1))
			else
				target=$(cd "$link" 2>/dev/null && pwd -P || echo "")
				if [ "$target" = "$expected" ]; then
					ok=$((ok+1))
				else
					printf '  BROKEN    %s  (-> %s)\n' "$name" "$target"
					broken=$((broken+1))
				fi
			fi
		done
		printf '%d OK, %d missing, %d broken.\n' "$ok" "$missing" "$broken"
	}

	apply_links() {
		local skills_dir=$1
		local changed=0 failed=0 ok=0 name link target expected
		if [ ! -d "$skills_dir" ]; then
			if mkdir -p "$skills_dir"; then
				printf 'Created  %s\n' "$skills_dir"
			else
				printf 'FAILED   %s (could not create skills directory)\n' "$skills_dir"
				return 1
			fi
		fi
		printf '\nSymlink check (%s):\n' "$skills_dir"
		for d in "$root"/tt-*/; do
			[ -d "$d" ] || continue
			name=$(basename "$d")
			link="$skills_dir/$name"
			expected=$(cd "$d" && pwd -P)
			if [ ! -e "$link" ] && [ ! -L "$link" ]; then
				if create_link "$d" "$link"; then
					printf 'Linked   %s\n' "$name"
					changed=$((changed+1))
				else
					printf 'FAILED   %s (could not create symlink)\n' "$name"
					failed=1
				fi
			else
				target=$(cd "$link" 2>/dev/null && pwd -P || echo "")
				if [ "$target" = "$expected" ]; then
					ok=$((ok+1))
				elif [ -L "$link" ] && rm -rf "$link" && create_link "$d" "$link"; then
					printf 'Relinked %s\n' "$name"
					changed=$((changed+1))
				else
					printf 'FAILED   %s (existing path is not a replaceable symlink)\n' "$name"
					failed=1
				fi
			fi
		done
		if [ $changed -eq 0 ]; then
			printf 'All %d symlinks already correct.\n' "$ok"
		else
			printf '\n%d symlink(s) updated, %d already correct.\n' "$changed" "$ok"
		fi
		return "$failed"
	}

	case $mode in
	check)
		printf '=== Toolbox update check ===\nRepo: %s\n' "$root"
		if git -C "$root" fetch origin --quiet 2>/dev/null; then
			local behind
			behind=$(git -C "$root" rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
			if [ "${behind:-0}" -gt 0 ]; then
				printf '\nCommits to pull (%s):\n' "$behind"
				git -C "$root" log HEAD..origin/main --oneline | sed 's/^/  /'
			else
				printf '\nAlready up to date.\n'
			fi
		else
			printf '\n(Could not reach remote — skipping fetch.)\n'
		fi
		for skills_dir in "${skills_dirs[@]}"; do
			check_links "$skills_dir"
		done
		;;
	apply)
		local old_head new_head failures=0
		old_head=$(git -C "$root" rev-parse HEAD 2>/dev/null)
		printf '=== Pulling ===\n'
		if git -C "$root" pull --ff-only origin main; then
			new_head=$(git -C "$root" rev-parse HEAD 2>/dev/null)
			if [ "$old_head" != "$new_head" ]; then
				printf '\nNew commits:\n'
				git -C "$root" log "${old_head}..${new_head}" --oneline | sed 's/^/  /'
			fi
		else
			printf '(Pull failed — continuing with symlink check.)\n'
		fi
		printf '\n=== Symlink check ===\n'
		for skills_dir in "${skills_dirs[@]}"; do
			if ! apply_links "$skills_dir"; then
				failures=$((failures+1))
			fi
		done
		printf '\n=== Done ===\n'
		[ "$failures" -eq 0 ] || return 1
		;;
	*)
		printf 'guide.sh update: unknown mode "%s". Use: check | apply\n' "$mode" >&2
		exit 2
		;;
	esac
}

context() {
	local mode=$1 dir=${2:-.}
	[ -d "$dir" ] || { echo "guide.sh: no such folder: $dir" >&2; exit 2; }
	case "$mode" in
		init) bash "$CONTEXT" init "$dir" ;;
		refresh) bash "$CONTEXT" refresh "$dir" ;;
		status) bash "$CONTEXT" status "$dir" ;;
		*) echo "guide.sh context: unknown mode $mode" >&2; exit 2 ;;
	esac
}

cmd=${1:-hello}
[ $# -gt 0 ] && shift
case $cmd in
hello)
	bash "$TATTY" banner
	echo
	echo "Where things stand in $(pwd):"
	where .
	echo
	echo "Ask me anything about the toolbox: which skill to run, what a document is for, how to resume."
	;;
where) where "$@" ;;
start) if need_readme; then bash "$MD" get "$readme" "Where to start" | tr -d '\r'; fi ;;
about) about "$@" ;;
update) update "$@" ;;
init) context init "${1:-.}" ;;
refresh) context refresh "${1:-.}" ;;
context) context status "${1:-.}" ;;
quip) quip ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
