#!/usr/bin/env bash
# status-init.sh: create a Task Status document from a finished Task Breakdown,
# with every row taken from the breakdown's tables, so no model writes it.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: status-init.sh [--label <name>] <task breakdown.md> <task status.md>

Writes the Task Status (tt-task-status's template): the breakdown's header
or tag block (a leading "# Tags" block up to its "---", or YAML front
matter), "# Status" (derived through status-set.sh --refresh), "# Resume Here"
pointing at the first unit, the Documents line, both boards from
status-boards.sh with every row Todo, and the empty Work Unit Validation,
Decisions Taken, Breakdown Changes, Step Log and Identified Improvements
sections.
Branch, base, repo and the plan link come from the breakdown header
("**Repo:** `<repo>` · base `<base>` · working branch `<branch>`" and the
"tech plan" line). Links follow the breakdown's style ([[wiki]] or Markdown).
The breakdown's line endings are kept.

--label names the first document in the status ("Lite Brief" for a Lite Brief,
which is its own plan): it replaces "Task Breakdown" and the tech plan link.

Refuses if <task status.md> exists: there is only ever one.
Exit: 0 written, 1 the breakdown has no Task Map, 2 usage error or the
status document exists.
EOF
	exit 2
}

label=""
if [ "${1:-}" = --label ]; then
	[ $# -ge 2 ] || usage
	label=$2; shift 2
fi
[ $# -eq 2 ] || usage
case "$1" in -h | --help) usage ;; esac
bd=$1; st=$2
[ -f "$bd" ] || { echo "status-init.sh: no such file: $bd" >&2; exit 2; }
[ -e "$st" ] && { echo "status-init.sh: $st exists; there is only ever one Task Status. Use it." >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
tr -d '\r' <"$bd" >"$work/bd"
crlf=0; [ "$(head -c 4096 "$bd" | tr -dc '\r' | wc -c)" -gt 0 ] && crlf=1

bash "$here/status-boards.sh" "$work/bd" >"$work/boards" || { echo "status-init.sh: no Task Map in $bd" >&2; exit 1; }

# The header or tag block.
awk 'NR == 1 && /^---[ \t]*$/ { fm = 1; print; next }
fm { print; if (/^---[ \t]*$/) exit; next }
NR == 1 && /^# Tags/ { tags = 1 }
tags { print; if (/^---[ \t]*$/) exit; next }
{ exit }' "$work/bd" >"$work/headblock"

head=$(sed -n '1,30p' "$work/bd")
repoline=$(printf '%s\n' "$head" | grep -m1 '\*\*Repo:\*\*' || true)
repo=$(printf '%s' "$repoline" | sed -n 's/.*\*\*Repo:\*\*[^`]*`\([^`]*\)`.*/\1/p')
base=$(printf '%s' "$repoline" | sed -n 's/.*base `\([^`]*\)`.*/\1/p')
branch=$(printf '%s' "$repoline" | sed -n 's/.*working branch[^`]*`\([^`]*\)`.*/\1/p')
[ -n "$branch" ] || branch=$(printf '%s' "$repoline" | sed -n 's/.*working branch \([^·]*\).*/\1/p' | sed 's/[ \t]*$//')
planline=$(printf '%s\n' "$head" | grep -m1 -i 'tech plan' || true)
style=md; printf '%s\n' "$head" | grep -q '\[\[' && style=wiki
if [ "$style" = wiki ]; then
	planlink=$(printf '%s' "$planline" | grep -o '\[\[[^]]*\]\]' | head -n 1)
	bdlink="[[$(basename "$bd" .md)]]"
else
	planlink=$(printf '%s' "$planline" | grep -o '\[[^]]*\]([^)]*)' | head -n 1)
	bdlink="[${label:-Task Breakdown}]($(basename "$bd" | sed 's/ /%20/g'))"
fi
if [ -n "$label" ]; then if [ "$style" = wiki ]; then docs="$label $bdlink"; else docs=$bdlink; fi; else docs="Comprehensive tech plan ${planlink:-(see the breakdown header)} · Task Breakdown $bdlink"; fi
first=$(awk 'NR > 3 && /^\| WU/ { split($0, c, "|"); gsub(/ /, "", c[2]); print c[2]; exit }' "$work/boards")
case "$branch" in *" "* | "") brline="- Branch: ${branch:-unknown} (base \`${base:-?}\`)" ;; *) brline="- Branch: \`$branch\` (base \`${base:-?}\`)" ;; esac

{
	if [ -s "$work/headblock" ]; then cat "$work/headblock"; echo; fi
	cat <<EOF
# Status
- State: Not Started
- Progress: -
- Current Unit: None
- Current Task: None
- Next: -
- Last Updated: -
$brline
- Blocking Decisions: None
- Outstanding Risks: None

# Resume Here
1. Read this document, then ${first:-the first unit} and its cards in $bdlink.
2. Reconcile: expect branch \`${branch:-?}\`; no task files yet.
3. Waiting on the engineer: nothing.
4. Next action: -.

**Documents:** $docs · Repo \`${repo:-?}\`

EOF
	cat "$work/boards"
	cat <<'EOF'

# Work Unit Validation

# Decisions Taken
| # | Decision | Resolution | Tasks / Units | Date |
|---|---|---|---|---|

# Breakdown Changes
| Date | Tasks / Units | Change | Why | Approved by |
|---|---|---|---|---|

# Step Log

# Identified Improvements
EOF
} >"$work/status"

t=$(mktemp "$(dirname "$st")/.status-init.XXXXXX")
if [ "$crlf" = 1 ]; then sed 's/$/\r/' "$work/status" >"$t"; else cp "$work/status" "$t"; fi
mv "$t" "$st"
bash "$here/status-set.sh" "$st" --refresh >/dev/null || true
nu=$(grep -c '^| WU' "$work/boards" || true); nt=$(awk '/^# Task Board/ { on = 1; next } on && /^\| [A-Z]/ && !/^\| ID/ { n++ } END { print n + 0 }' "$work/boards")
echo "wrote $st: $nu units, $nt tasks, all Todo"
# Stage-completion event (tt-common/events.md): the breakdown is written. A Lite
# Brief is its own plan (tt-lite-brief emits for it), so only a Task Breakdown counts.
# Best-effort: nothing here can change the output or the exit code.
case $(basename "$bd") in
*" - Task Breakdown.md")
	bn=$(basename "$st")
	bash "$here/tt-event.sh" emit breakdown.written --prefix "${bn% - Task Status.md}" --folder "$(dirname "$st")" --skill tt-task-breakdown >/dev/null 2>&1 || true ;;
esac
