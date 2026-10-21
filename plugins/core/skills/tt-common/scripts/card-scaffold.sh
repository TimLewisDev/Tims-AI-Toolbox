#!/usr/bin/env bash
# card-scaffold.sh: pre-write a work unit's block and task cards from the
# approved skeleton, the plan and the glossary, leaving "<!-- fill: … -->"
# markers only where a card writer's judgement is needed.
set -eu

usage() {
	cat >&2 <<'EOF'
usage: card-scaffold.sh <draft folder> <WU> [--plan <plan.md>] [--force]

Writes, from <draft>/skeleton.md, <draft>/glossary.tsv and the plan (default:
the skeleton's "- Plan:" line):

  <draft>/parts/30-<WU>.md   the unit block: heading, Tasks / Depends on /
      Validated by, and the Validation list in its final order: the unit's
      checks ("## Unit checks"), then each "Done when" item the Done-when map
      places on the unit, copied verbatim from the plan (donewhen.sh), tagged
      "(plan §N)" or "(plan §N; observable from this unit)", and its
      "Checked by". An empty checks block and the How to validate lines.
  <draft>/parts/31-<WU>-<task>.md  each card: heading, the Executor / Work unit
      / Depends on / Plan step (a link to the plan heading) / Traces to table,
      "Plan IDs" with their glossary excerpts, the Files list, the Confirm
      items as the last Steps, and "Validated in".

Everything else is a "<!-- fill: <what goes here> -->" marker. The parts have
no <!-- tt:end --> line: the card writer adds it once every marker is
replaced, so assemble.sh reports them incomplete until then.
Links are Obsidian [[wiki-links]] when <draft>/context.md mentions wiki
links or holds a [[link]], else relative Markdown links.
Existing parts are left alone unless --force. Prints one line per part.

Exit: 0 written (or all skipped), 1 the unit isn't in the skeleton, 2 usage
error.
EOF
	exit 2
}

[ $# -ge 2 ] || usage
case "$1" in -h | --help) usage ;; esac
draft=$1; wu=$2; shift 2
plan=""; force=0
while [ $# -gt 0 ]; do
	case "$1" in
		--plan) plan=${2:?}; shift 2 ;;
		--force) force=1; shift ;;
		*) usage ;;
	esac
done
sk="$draft/skeleton.md"
[ -f "$sk" ] || { echo "card-scaffold.sh: no skeleton: $sk" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
[ -n "$plan" ] || plan=$(bash "$here/skeleton-tsv.sh" "$sk" meta | awk -F'\t' '$1 == "plan" { print $2 }')
plan=$(printf '%s' "$plan" | sed 's/^`//; s/`$//')
[ -f "$plan" ] || { echo "card-scaffold.sh: no such plan: ${plan:-?} (pass --plan)" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$draft/parts"

bash "$here/skeleton-tsv.sh" "$sk" tasks >"$work/tasks" || :
bash "$here/skeleton-tsv.sh" "$sk" units >"$work/units" || :
bash "$here/skeleton-tsv.sh" "$sk" donewhen >"$work/map" || :
bash "$here/skeleton-tsv.sh" "$sk" checks >"$work/checks" || :
bash "$here/donewhen.sh" "$plan" >"$work/items" || :
tr -d '\r' <"$plan" | awk '/^#+[ \t]+§[0-9]+[a-z]?\./ { s = $0; sub(/^#+[ \t]+/, "", s); id = s; match(id, /^§[0-9]+[a-z]?/); print substr(id, 1, RLENGTH) "\t" s }' >"$work/headings"
[ -f "$draft/glossary.tsv" ] && tr -d '\r' <"$draft/glossary.tsv" >"$work/glossary" || : >"$work/glossary"
grep -q "^$wu	" "$work/units" || { echo "card-scaffold.sh: $wu is not in the skeleton's Units" >&2; exit 1; }

style=md
if [ -f "$draft/context.md" ] && grep -qiE 'wiki|\[\[' "$draft/context.md"; then style=wiki; fi
pbase=$(basename "$plan" .md)

put() { # file <- stdin, unless it exists
	if [ -e "$1" ] && [ "$force" = 0 ]; then cat >/dev/null; echo "skipped (exists): $1"; return; fi
	local t; t=$(mktemp "$(dirname "$1")/.scaffold.XXXXXX"); cat >"$t"; mv "$t" "$1"; echo "wrote $1"
}

AWK_COMMON='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function fill(what) { return "<!-- fill: " what " -->" }
function link(step,   h, u) {
	h = (step in HEAD) ? HEAD[step] : step
	if (STYLE == "wiki") return "[[" PBASE "#" h "]]"
	u = PBASE ".md"; gsub(/ /, "%20", u); return "[" h "](" u ")"
}
FILENAME ~ /headings$/ { HEAD[$1] = $2; next }
FILENAME ~ /tasks$/ { TT[$1] = $2; TX[$1] = $3; TF[$1] = $4; TD[$1] = $5; TR[$1] = $6; TC[$1] = $7; TS[$1] = $9; next }
FILENAME ~ /units$/ { if ($1 == WU) { UTASKS = $3; UVAL = $4; UDEP = $5 }; next }
FILENAME ~ /glossary$/ { G[$1] = $3; next }
FILENAME ~ /items$/ { IT[$1 " #" $2] = $3; next }
FILENAME ~ /checks$/ { if ($1 == WU) { nc++; CK[nc] = $2; CW[nc] = $3 }; next }
FILENAME ~ /map$/ { if ($3 == WU) { nm++; MK[nm] = $1; MB[nm] = $4 }; next }
'

# The unit block.
awk -F'\t' -v WU="$wu" -v STYLE="$style" -v PBASE="$pbase" "$AWK_COMMON"'
END {
	n = split(UTASKS, ts, ","); for (i = 1; i <= n; i++) HERE[TS[ts[i]]] = 1
	tl = UTASKS; gsub(/,/, ", ", tl)
	print "## " WU " — " fill("outcome-style name")
	print ""
	print "**In plain English:** " fill("2–4 sentences: what someone can do or see once this unit is validated, per the rules in SKILL.md")
	print ""
	print "| | |"; print "|---|---|"
	print "| **Tasks** | " tl " |"; print "| **Depends on** | " UDEP " |"; print "| **Validated by** | " UVAL " |"
	print ""
	print "**Why these tasks are validated together:** " fill("one or two sentences: what can only be observed once all of them are done")
	print ""
	print "**Validation**"
	for (i = 1; i <= nc; i++) print "- [ ] " CK[i] " (" (CW[i] == "" ? fill("Agent, Engineer or Agent + Engineer") : CW[i]) ")"
	for (i = 1; i <= nm; i++) { k = MK[i]; st = k; sub(/ #.*$/, "", st)
		txt = (k in IT) ? IT[k] : fill("plan item " k " not found by donewhen.sh: copy it from the plan verbatim")
		tag = (st in HERE) ? "(plan " st ")" : "(plan " st "; observable from this unit)"
		print "- [ ] " txt " " tag " (" (MB[i] == "" ? fill("Agent, Engineer or Agent + Engineer") : MB[i]) ")" }
	print ""
	print "**How to validate**"
	print ""
	print "```checks"
	print fill("one line per Agent check a command fully decides: its number in the list above, then ok, empty or nonempty, then the command, separated by bars; keep the list order, the numbers depend on it")
	print "```"
	print ""
	print "- Agent: " fill("inspections the checks block cannot express, in order, or none")
	print "- Engineer (read out inline at validation time):"
	print "  1. " fill("what to open and do → expect what they should see")
}' "$work/headings" "$work/tasks" "$work/units" "$work/glossary" "$work/items" "$work/checks" "$work/map" </dev/null | put "$draft/parts/30-$wu.md"

# One card per task.
for t in $(awk -F'\t' -v WU="$wu" '$1 == WU { print $3 }' "$work/units" | tr ',' ' '); do
	awk -F'\t' -v WU="$wu" -v ID="$t" -v STYLE="$style" -v PBASE="$pbase" "$AWK_COMMON"'
	END {
		if (!(ID in TT)) { print "### " ID " — " fill("task not in the skeleton Tasks"); exit }
		print "### " ID " — " TT[ID]
		print ""
		print "**In plain English:** " fill("2–4 sentences for a non-technical reader, per the rules in SKILL.md; write it last")
		print ""
		print "| | |"; print "|---|---|"
		print "| **Executor** | " TX[ID] " |"; print "| **Work unit** | " WU " |"; print "| **Depends on** | " TD[ID] " |"
		print "| **Plan step** | " (TS[ID] == "" ? "—" : link(TS[ID])) " |"; print "| **Traces to** | " TR[ID] " |"
		print ""
		print "**Goal:** " fill("one technical sentence")
		print ""
		print "**Read first**"
		if (TS[ID] != "") print "- Plan: " link(TS[ID]) ", for " fill("what to take from it")
		ids = ""; n = split(TR[ID], tr, /[ ,]+/)
		for (i = 1; i <= n; i++) { x = tr[i]; gsub(/[`*]/, "", x); if (x == "" || x ~ /^(§|T[0-9]|WU)/) continue
			ids = ids (ids == "" ? "" : "; ") "`" x "` " ((x in G) ? "\"" G[x] "\"" : fill("no glossary excerpt: copy one line from the plan")) }
		if (ids != "") print "- Plan IDs: " ids
		print "- " fill("Precedent, Repo rules and API docs lines as templates/task-card.md says, or delete this line")
		print ""
		print "**Files** (nothing outside this list)"
		f = TF[ID]; nf = 0
		while (match(f, /(new|change|changed|delete|deleted)?[ \t]*`[^`]+`/)) {
			seg = substr(f, RSTART, RLENGTH); f = substr(f, RSTART + RLENGTH)
			verb = seg; sub(/[ \t]*`.*/, "", verb); p = seg; sub(/^[^`]*`/, "", p); sub(/`$/, "", p)
			if (verb == "changed") verb = "change"; if (verb == "deleted") verb = "delete"; if (verb == "") verb = "change"
			print "- " verb " `" p "`: " fill(verb == "new" ? "purpose" : "what changes"); nf++ }
		if (!nf) print "- none" (TX[ID] == "Engineer" ? " (an Engineer task)" : "")
		print ""
		print "**Steps**"
		print "1. " fill("concrete, ordered steps with the plan'"'"'s signatures, constants and snippets, no planning IDs in code comments")
		if (TC[ID] != "" && TC[ID] != "—") print "2. **Confirm:** " TC[ID] " " fill("how to confirm it, and what to do with each answer")
		print ""
		print "**Not in this task**"
		print "- " fill("adjacent work, naming the task that owns it or the Non-Goal it falls under")
		print ""
		print "**Validated in:** " WU ", checks " fill("which of the unit'"'"'s checks cover this task")
	}' "$work/headings" "$work/tasks" "$work/units" "$work/glossary" "$work/items" "$work/checks" "$work/map" </dev/null | put "$draft/parts/31-$wu-$t.md"
done
