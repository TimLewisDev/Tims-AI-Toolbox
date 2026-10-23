#!/usr/bin/env bash
# guide.sh: Tatty, the tt toolbox guide. Says hello, works out where the tt
# documents in a folder stand and which command comes next, and prints
# toolbox.md sections on request. Needs bash and awk only. Writes nothing
# except what init/refresh (the project cache), update apply (pull, skill
# links for other clients), migrate apply (removes old skill links) and pack
# save (a connection pack in the user-level folder) do.
set -u

usage() {
	cat >&2 <<'EOT'
usage: guide.sh [hello]                    the greeting, then "where ."
       guide.sh where [dir]                where the tt documents in dir stand, and the next command
       guide.sh start                      the "Where to start" table
       guide.sh about [name]               a skill's catalogue entry, or a topic (documents, ids, work units, ...);
                                           with no name, the list of topics
       guide.sh init [dir]                 inspect project metadata and build a local context/index cache
       guide.sh refresh [dir]              rebuild the local project context/index cache
       guide.sh context [dir]              report whether the local project context cache is current
       guide.sh connections [dir]          which connections this project's pack needs and which are missing
       guide.sh pack list                  the installed connection packs and what they match
       guide.sh pack save <name> [--replace]
                                           save the pack text on stdin as <name>.pack (exit 4: it exists)
       guide.sh update [check|apply]       whether the Claude Code plugins auto-update; for a clone linked into Copilot CLI or
                                           Codex CLI, pull and fix missing links (check previews, apply changes)
       guide.sh migrate [check|apply]      old ~/.claude/skills/tt-* links (from before the plugins) and an old
                                           metrics hook entry; check lists them, apply removes the links
       guide.sh quip                       one quip

TT_GUIDE_ASCII=1 draws Tatty without box-drawing characters.
Exit: 0 ok, 1 "about" found nothing, 2 usage error, 4 "pack save": that pack already exists.
EOT
}

# This skill's folder, and the skills folder of the core plugin around it.
# Git Bash's cd -P doesn't follow Windows junctions, but readlink -f does.
here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
skill=$(dirname "$here")
core=$(dirname "$skill")
common="$core/tt-common"
. "$common/scripts/tt-path.sh"
readme="$skill/toolbox.md"
MD="$common/scripts/md-section.sh"

TATTY="$common/scripts/tatty.sh"
STATE="$common/scripts/workflow-state.sh"
CONTEXT="$common/scripts/project-context.sh"
CONNECTIONS="$core/tt-connections/scripts/connections.sh"

quip() { bash "$TATTY" quip; }

# field <file> <regex>: the first line matching the regex, without CR
field() { awk -v re="$2" '{ sub(/\r$/, "") } $0 ~ re { print; exit }' "$1"; }

# plugin_hint <skill>: which plugin a skill comes from, and how to get it
plugin_hint() {
	case $1 in
	tt-guide | tt-common | tt-config | tt-connections | tt-metrics) echo "It is part of core: /plugin install core@tims-ai-toolbox" ;;
	tt-user-stories) echo "It is part of design: /plugin install design@tims-ai-toolbox, then restart Claude Code" ;;
	*) echo "It is part of engineering: /plugin install engineering@tims-ai-toolbox, then restart Claude Code" ;;
	esac
}

where() {
	local dir=${1:-.}
	[ -d "$dir" ] || { echo "guide.sh: no such folder: $dir" >&2; exit 2; }
	if ! tt_find tt-workflow >/dev/null; then
		echo "  The planning and build commands come from engineering, which isn't installed here."
		echo "  Install it with /plugin install engineering@tims-ai-toolbox, then restart Claude Code."
	fi
	bash "$STATE" "$dir" && return 0
	echo "  New here? Or explore first with /tt-familiarise <topic>."
	echo "  Docs in a vault or another folder? Ask me to look there (guide.sh where <folder>)."
}


need_readme() {
	[ -f "$readme" ] && [ -f "$MD" ] && return 0
	echo "(I can't find toolbox.md beside this skill, so here's the short version.)"
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
  user stories from a design /tt-user-stories <design doc>
EOF
	return 1
}

# sections <starts|contains> <text>: toolbox.md headings (level 2-4) whose text
# starts with or contains the text, ignoring case (a fixed string, not a regex)
sections() {
	bash "$MD" index "$readme" | Q="$2" awk -F'\t' -v m="$1" '
		BEGIN { q = tolower(ENVIRON["Q"]) }
		$2 >= 2 && $2 <= 4 { i = index(tolower($4), q); if (m == "starts" ? i == 1 : i > 0) print }'
}

# topics: the catalogue headings that aren't a skill's entry
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
	local name=${q#tt-} dir
	dir=$(tt_find "tt-$name") || dir=""
	row=$(grep -F "| [\`tt-$name\`]" "$readme" | head -1 | tr -d '\r')
	if [ -n "$dir" ] || [ -n "$row" ]; then
		[ -n "$row" ] && printf '%s\n\n' "$row"
		hits=$(sections starts "[\`tt-$name\`]")
		case $name in requirements | scope | approach | technical-design | plan-signoff)
			hits=$(sections starts "the planning stages") ;; esac
		if [ -n "$hits" ]; then
			show "$hits"
		elif [ -z "$row" ]; then
			field "$dir/SKILL.md" '^name:'
			awk '/^description:/ { on = 1; next } on && /^[a-z-]+:/ { exit } on { sub(/^  /, ""); print }' "$dir/SKILL.md"
		fi
		[ -n "$dir" ] || echo "(tt-$name isn't installed here. $(plugin_hint "tt-$name"))"
		return 0
	fi
	hits=$(sections contains "$q")
	if [ -n "$hits" ]; then
		show "$hits"
		return 0
	fi
	echo "Nothing in the catalogue about \"$*\". Try a skill name (tt-scope, execute, ...) or one of:"
	topics
	return 1
}

is_windows_shell() {
	case ${OSTYPE:-} in
	msys* | cygwin* | win32*) return 0 ;;
	*) return 1 ;;
	esac
}

# remove_link <path>: remove a symlink or junction without touching what it
# points at. Never recurses; a real folder is left alone (returns 1).
remove_link() {
	[ -L "$1" ] || [ -e "$1" ] || return 0
	rmdir "$1" 2>/dev/null && return 0
	[ -L "$1" ] && rm -f "$1" 2>/dev/null
}

# legacy_links: the old ~/.claude/skills/tt-* entries for toolbox skills, from
# before the plugins. Those entries load the skills a second time.
legacy_links() {
	local l name known
	# Installed skills, and the catalogue's names for those not installed yet.
	known=$({ tt_skills; sed -n 's/^| \[`\(tt-[a-z-]*\)`\].*/\1/p' "$readme"; } | sort -u)
	for l in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/skills/tt-*; do
		[ -L "$l" ] || [ -e "$l" ] || continue
		name=$(basename "$l")
		printf '%s\n' "$known" | grep -qx "$name" || continue
		if [ -L "$l" ]; then printf 'link\t%s\n' "$l"; else printf 'folder\t%s\n' "$l"; fi
	done
}

# legacy_hook: the line of settings.json that runs record-session.sh by hand
legacy_hook() {
	local s=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json
	[ -f "$s" ] && grep -n 'record-session\.sh' "$s" | head -1
}

# marketplace_autoupdate <json file>: the toolbox marketplace's "autoUpdate" in
# that file: on, off, unset (the entry has no such key) or absent (no entry).
# Claude Code keeps it in the marketplace entry of settings.json
# (extraKnownMarketplaces) and in plugins/known_marketplaces.json. Reads the
# entry's braces to find its end; fine for the plain objects these files hold.
marketplace_autoupdate() {
	[ -s "$1" ] || { echo absent; return; }
	tr -d '\r\n' <"$1" | awk '
		{
			k = index($0, "\"tims-ai-toolbox\"")
			if (!k) { print "absent"; exit }
			s = substr($0, k + 17); o = index(s, "{")
			if (!o) { print "absent"; exit }
			depth = 0; body = ""
			for (i = o; i <= length(s); i++) {
				c = substr(s, i, 1)
				if (c == "{") depth++
				if (c == "}") { depth--; if (depth == 0) break }
				body = body c
			}
			if (body ~ /"autoUpdate"[ \t]*:[ \t]*true/) print "on"
			else if (body ~ /"autoUpdate"[ \t]*:[ \t]*false/) print "off"
			else print "unset"
		}'
}

# autoupdate_state: on if either file says on, else off if either says off,
# else unset if the marketplace is known, else absent
autoupdate_state() {
	local cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude} a b
	a=$(marketplace_autoupdate "$cfg/settings.json")
	b=$(marketplace_autoupdate "$cfg/plugins/known_marketplaces.json")
	for s in on off unset; do
		if [ "$a" = "$s" ] || [ "$b" = "$s" ]; then echo "$s"; return; fi
	done
	echo absent
}

migrate() {
	local mode=${1:-check} kind path n=0 removed=0 hook
	case $mode in
	check | apply) ;;
	*)
		printf 'guide.sh migrate: unknown mode "%s". Use: check | apply\n' "$mode" >&2
		exit 2
		;;
	esac
	printf '=== Old skill links (from before the plugins) ===\n'
	while IFS=$'\t' read -r kind path; do
		[ -n "$path" ] || continue
		n=$((n + 1))
		if [ "$kind" = folder ]; then
			printf '  KEEP      %s  (a real folder, not a link: remove it yourself if you want)\n' "$path"
		elif [ "$mode" = apply ]; then
			if remove_link "$path"; then
				printf '  Removed   %s\n' "$path"
				removed=$((removed + 1))
			else
				printf '  FAILED    %s\n' "$path"
			fi
		else
			printf '  LINK      %s\n' "$path"
		fi
	done < <(legacy_links)
	[ "$n" -gt 0 ] || printf '  None.\n'
	if [ "$mode" = apply ] && [ "$removed" -gt 0 ]; then printf '%d removed. Restart Claude Code.\n' "$removed"; fi
	printf '\n=== Old metrics hook ===\n'
	if hook=$(legacy_hook) && [ -n "$hook" ]; then
		printf '  settings.json line %s\n' "$hook"
		printf '  The core plugin now provides this hook. Remove that entry from settings.json,\n'
		printf '  or every session is logged twice (or the entry fails if the old clone has moved).\n'
	else
		printf '  None.\n'
	fi
	return 0
}

update() {
	local mode=${1:-check}
	local skills_dirs=(
		"$HOME/.copilot/skills"
		"$HOME/.agents/skills"
	)
	local repo skill_dirs=() d
	repo=$(git -C "$skill" rev-parse --show-toplevel 2>/dev/null) || repo=""
	if [ -n "$repo" ] && [ -d "$repo/plugins" ]; then
		for d in "$repo"/plugins/*/skills/tt-*/; do [ -d "$d" ] && skill_dirs+=("$d"); done
	else
		repo=""
	fi

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
		printf '\nLink check (%s):\n' "$skills_dir"
		local ok=0 missing=0 broken=0 name link target expected
		for d in "${skill_dirs[@]}"; do
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
		printf '\nLink check (%s):\n' "$skills_dir"
		for d in "${skill_dirs[@]}"; do
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
				elif [ -L "$link" ] && remove_link "$link" && create_link "$d" "$link"; then
					printf 'Relinked %s\n' "$name"
					changed=$((changed+1))
				else
					printf 'FAILED   %s (existing path is not a replaceable symlink)\n' "$name"
					failed=1
				fi
			fi
		done
		if [ $changed -eq 0 ]; then
			printf 'All %d links already correct.\n' "$ok"
		else
			printf '\n%d link(s) updated, %d already correct.\n' "$changed" "$ok"
		fi
		return "$failed"
	}

	case $mode in
	check | apply) ;;
	*)
		printf 'guide.sh update: unknown mode "%s". Use: check | apply\n' "$mode" >&2
		exit 2
		;;
	esac

	if [ -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]; then
		printf '=== Claude Code ===\n'
		printf 'Auto-update: %s\n' "$(autoupdate_state)"
		case $(autoupdate_state) in
		on) printf 'Claude Code refreshes the toolbox marketplace after your first message of a session and updates\n'
			printf 'the plugins whose version was bumped. A running session keeps the old copy until /reload-plugins.\n' ;;
		absent) printf 'The toolbox marketplace is not declared in your user settings (added for a project, or not added).\n'
			printf 'Turn auto-update on in /plugin: Marketplaces, tims-ai-toolbox, Enable auto-update.\n' ;;
		*) printf 'Off or unset: the plugins only change when you update them yourself.\n' ;;
		esac
		printf 'To update right now:\n'
		printf '  /plugin marketplace update tims-ai-toolbox\n'
		printf '  /plugin update core@tims-ai-toolbox       (and engineering@tims-ai-toolbox, ...)\n'
		printf '  /reload-plugins\n'
		if [ -n "$(legacy_links)" ]; then
			printf '\nOld skill links from before the plugins are still in ~/.claude/skills.\n'
			printf 'Run: guide.sh migrate\n'
		fi
	fi

	[ -n "$repo" ] || return 0

	case $mode in
	check)
		printf '\n=== Clone for Copilot CLI and Codex CLI ===\nRepo: %s\n' "$repo"
		if git -C "$repo" fetch origin --quiet 2>/dev/null; then
			local behind
			behind=$(git -C "$repo" rev-list HEAD..origin/main --count 2>/dev/null || echo 0)
			if [ "${behind:-0}" -gt 0 ]; then
				printf '\nCommits to pull (%s):\n' "$behind"
				git -C "$repo" log HEAD..origin/main --oneline | sed 's/^/  /'
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
		old_head=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
		printf '\n=== Pulling ===\n'
		if git -C "$repo" pull --ff-only origin main; then
			new_head=$(git -C "$repo" rev-parse HEAD 2>/dev/null)
			if [ "$old_head" != "$new_head" ]; then
				printf '\nNew commits:\n'
				git -C "$repo" log "${old_head}..${new_head}" --oneline | sed 's/^/  /'
			fi
		else
			printf '(Pull failed — continuing with link check.)\n'
		fi
		printf '\n=== Link check (Copilot CLI and Codex CLI) ===\n'
		for skills_dir in "${skills_dirs[@]}"; do
			if ! apply_links "$skills_dir"; then
				failures=$((failures+1))
			fi
		done
		printf '\n=== Done ===\n'
		printf 'Restart your client (Copilot CLI or Codex CLI) to pick up new skills.\n'
		[ "$failures" -eq 0 ] || return 1
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

# connections [dir]: the project's connection pack and what is missing. Exit 3
# (no pack for this project) is a normal answer, so it is reported, not failed.
connections() {
	local dir=${1:-.} rc
	[ -d "$dir" ] || { echo "guide.sh: no such folder: $dir" >&2; exit 2; }
	[ -f "$CONNECTIONS" ] || { echo "No connection setup in this toolbox (tt-connections is missing)."; return 0; }
	bash "$CONNECTIONS" status "$dir"
	rc=$?
	[ "$rc" = 3 ] && return 0
	return "$rc"
}

# pack list | save <name> [--replace]: the installed connection packs, or save the
# pack text on stdin as a machine-wide pack (tt-connections validates it)
pack() {
	[ -f "$CONNECTIONS" ] || { echo "No connection setup in this toolbox (tt-connections is missing)."; return 2; }
	case ${1:-} in
	list) bash "$CONNECTIONS" list ;;
	save) shift; bash "$CONNECTIONS" pack save "$@" ;;
	*) usage; exit 2 ;;
	esac
}

cmd=${1:-hello}
[ $# -gt 0 ] && shift
case $cmd in
hello)
	# Self-heal: the SessionStart hook hasn't run yet in a session that
	# installed the plugin, so make sure the other plugins can find tt-common.
	[ -f "$core/../hooks/register.sh" ] && bash "$core/../hooks/register.sh" core >/dev/null 2>&1
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
migrate) migrate "$@" ;;
init) context init "${1:-.}" ;;
refresh) context refresh "${1:-.}" ;;
context) context status "${1:-.}" ;;
connections) connections "${1:-.}" ;;
pack) pack "$@" ;;
quip) quip ;;
-h | --help) usage ;;
*) usage; exit 2 ;;
esac
