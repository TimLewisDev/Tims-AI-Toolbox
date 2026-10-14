#!/usr/bin/env bash
# test-scripts.sh: smoke tests for the tt-common status and continue-mode
# scripts, run against tools/fixtures/demo in a throwaway git repo. Needs bash,
# awk and git only. Prints one line per check and a count; exit 1 on failure.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
S="$root/tt-common/scripts"
F="$root/tools/fixtures/demo"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
pass=0; fail=0

ok() { pass=$((pass + 1)); echo "ok    $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }
# expect <name> <exit code> <command...>: the command exits with the code
expect() { local n=$1 want=$2; shift 2; "$@" >"$T/out" 2>&1; local rc=$?; [ "$rc" = "$want" ] && ok "$n" || bad "$n" "exit $rc, wanted $want: $(head -c 300 "$T/out")"; }
# has <name> <file> <fixed string>: the file contains the string
has() { grep -qF -- "$3" "$2" && ok "$1" || bad "$1" "missing: $3"; }
hasnt() { grep -qF -- "$3" "$2" && bad "$1" "unexpected: $3" || ok "$1"; }

# A repo the fixture breakdown points at.
mkdir -p "$T/repo/src"
(cd "$T/repo" && git init -q -b feature/demo && git config core.autocrlf false && echo 'exit 0' >build.sh &&
	printf 'echo hi\n# DEBUG\n' >src/store.sh && echo 'echo hello' >src/greet.sh && git add . &&
	git -c user.email=t@t -c user.name=t commit -qm init)
for f in "$F"/*.md; do sed "s#REPO#$T/repo#g" "$f" >"$T/$(basename "$f")"; done
BD="$T/Demo - Task Breakdown.md"; ST="$T/Demo - Task Status.md"

echo "# status-set.sh"
expect "start a task" 0 bash "$S/status-set.sh" "$ST" T01 "In Progress"
has "task row set" "$ST" "| T01 | Add the settings store | Agent | WU1 | — | In Progress |"
has "unit follows the task" "$ST" "| WU1 | Save settings | T01, T02 | Agent | In Progress |"
has "header State" "$ST" "- State: In Progress"
has "Resume Here next action" "$ST" "4. Next action: T01 — Add the settings store (Agent)."
expect "block with a note" 0 bash "$S/status-set.sh" "$ST" T01 Blocked --note "D1: format"
has "Blocking Decisions" "$ST" "- Blocking Decisions: T01 (D1: format)"
has "unit Blocked" "$ST" "| WU1 | Save settings | T01, T02 | Agent | Blocked |"
expect "task Done only through its unit" 2 bash "$S/status-set.sh" "$ST" T01 Done
expect "unknown ID" 2 bash "$S/status-set.sh" "$ST" T99 Todo
expect "unknown status" 2 bash "$S/status-set.sh" "$ST" T01 Finished
hasnt "no report lines in the document" "$ST" " -> "

echo "# status-log.sh"
cat >"$T/T01.md" <<'EOF'
# Result: T01 — Add the settings store

- Task status: implemented

## Files Modified
- new `src/store.sh`: the store

## Summary
Wrote the store.

## To validate
1. Run `bash build.sh` → expect exit 0.

## Follow-up Concerns
none

## Risks
- The store format isn't versioned.

## Improvements
### Version it
- Description: Add a version field.
- Benefits: Safer upgrades.
- Risks/Tradeoffs: One more field.
- Why High Impact: Every unit reads it.

## Critical Decision
none
EOF
expect "apply a result" 0 bash "$S/status-log.sh" "$ST" "$T/T01.md"
has "Step Log entry" "$ST" "## T01 — Add the settings store"
has "validation deferred to the unit" "$ST" "- Validation: Deferred to WU1"
has "task Implemented" "$ST" "| T01 | Add the settings store | Agent | WU1 | — | Implemented |"
has "unit unblocked" "$ST" "| WU1 | Save settings | T01, T02 | Agent | In Progress |"
has "risk added" "$ST" "  - The store format isn't versioned. (T01, "
has "improvement added" "$ST" "## Improvement 1"
expect "apply the same result again" 0 bash "$S/status-log.sh" "$ST" "$T/T01.md"
[ "$(grep -c "The store format isn't versioned" "$ST")" = 1 ] && ok "risk not duplicated" || bad "risk not duplicated"
[ "$(grep -c '^## Improvement' "$ST")" = 1 ] && ok "improvement not duplicated" || bad "improvement not duplicated"
[ "$(grep -c '^## T01 —' "$ST")" = 1 ] && ok "entry replaced, not duplicated" || bad "entry replaced, not duplicated"
printf '# Result: T02 — x\n\n- Task status: blocked\n\n## Files Modified\nnone\n\n## Summary\nStopped.\n\n## Critical Decision\n### Issue\nName clash.\n' >"$T/T02.md"
expect "apply a blocked result" 0 bash "$S/status-log.sh" "$ST" "$T/T02.md"
has "critical decision reported" "$T/out" "critical decision: yes"
printf '# Result: T77 — x\n- Task status: implemented\n' >"$T/bad.md"
expect "result for an unknown task" 2 bash "$S/status-log.sh" "$ST" "$T/bad.md"

echo "# status-record.sh"
expect "decision" 0 bash "$S/status-record.sh" "$ST" decision --decision "Name | clash" --resolution "Rename" --affects T02
has "decision row, pipe escaped" "$ST" "| D1 | Name \| clash | Rename | T02 |"
expect "breakdown change" 0 bash "$S/status-record.sh" "$ST" change --affects T02 --change "Rename the file" --why "D1" --approved-by Engineer
expect "risk close" 0 bash "$S/status-record.sh" "$ST" risk --close "versioned" --how "added a version"
has "risk closed" "$ST" "**Closed "
expect "risk close with no match" 2 bash "$S/status-record.sh" "$ST" risk --close "nothing like this" --how x
expect "unblock T02" 0 bash "$S/status-set.sh" "$ST" T02 Implemented
expect "unit ready" 0 bash "$S/status-set.sh" "$ST" WU1 "Ready to Validate"

echo "# run-checks.sh"
expect "WU1 checks (one fails)" 1 bash "$S/run-checks.sh" "$BD" WU1 "$T/logs/WU1-1"
has "failing check" "$T/logs/WU1-1/attempt.md" "[Agent]: failed. \`git grep -n \"DEBUG\" -- src\`"
has "outcome Failed" "$T/logs/WU1-1/attempt.md" "- Outcome: Failed"
[ -s "$T/logs/WU1-1/check-2.log" ] && ok "check log written" || bad "check log written"
expect "record the attempt" 0 bash "$S/status-record.sh" "$ST" validation WU1 --file "$T/logs/WU1-1/attempt.md"
has "attempt heading" "$ST" "### Attempt 1"
sed -i '/DEBUG/d' "$T/repo/src/store.sh"
(cd "$T/repo" && git add -A && git -c user.email=t@t -c user.name=t commit -qm fix)
expect "WU1 checks after the fix" 0 bash "$S/run-checks.sh" "$BD" WU1 "$T/logs/WU1-2" --why "after fix"
expect "record attempt 2" 0 bash "$S/status-record.sh" "$ST" validation WU1 --file "$T/logs/WU1-2/attempt.md"
has "attempt 2" "$ST" "### Attempt 2"
expect "unit Done" 0 bash "$S/status-set.sh" "$ST" WU1 Done
has "tasks Done with the unit" "$ST" "| T02 | Add the settings loader | Agent | WU1 | T01 | Done |"
has "Step Log follows" "$ST" "- Status: Done"
expect "WU2 checks (engineer pending)" 0 bash "$S/run-checks.sh" "$BD" WU2 "$T/logs/WU2-1"
has "agent + engineer pending" "$T/logs/WU2-1/attempt.md" "[Agent + Engineer]: pending. agent part passed"
sed 's/```checks/```text/' "$BD" >"$T/nochecks.md"
expect "no checks block" 2 bash "$S/run-checks.sh" "$T/nochecks.md" WU1 "$T/logs/x"

echo "# status-record.sh check"
expect "record WU2 attempt" 0 bash "$S/status-record.sh" "$ST" validation WU2 --file "$T/logs/WU2-1/attempt.md"
expect "engineer answers check 2" 0 bash "$S/status-record.sh" "$ST" check WU2 2 passed --evidence "engineer: saw hello"
has "agent evidence kept" "$ST" "agent part passed:"
has "outcome still pending" "$T/out" "outcome: Pending (checks 3)"
expect "engineer answers check 3" 0 bash "$S/status-record.sh" "$ST" check WU2 3 passed
has "outcome Done" "$T/out" "outcome: Done"
expect "no such check" 2 bash "$S/status-record.sh" "$ST" check WU2 9 passed

echo "# validation-checklist.sh"
expect "no open engineer checks" 1 bash "$S/validation-checklist.sh" "$BD" "$ST" WU2
cp "$F/Demo - Task Status.md" "$T/fresh.md"
expect "checklist for a fresh unit" 0 bash "$S/validation-checklist.sh" "$BD" "$T/fresh.md" WU2
has "engineer check listed" "$T/out" "- 3. The greeting looks right in the tool (Engineer)"
has "engineer steps" "$T/out" "Open the tool and run Greet"

echo "# continue-preflight.sh"
expect "preflight (drift, findings)" 1 bash "$S/continue-preflight.sh" "$ST" "$BD"
has "plan drift" "$T/out" "plan: revision 1 -> 2 (drift)"
has "needs model" "$T/out" "needs_model: yes (plan drift"
sed -i 's/plan read: revision 1/plan read: revision 2/' "$BD"
printf '# Result: T03 — x\n- Task status: implemented\n## Files Modified\n- new `src/greet.sh`: g\n## Summary\nok\n' >"$T/T03.md"
bash "$S/status-log.sh" "$ST" "$T/T03.md" >/dev/null
expect "preflight after the plan is read again" 0 bash "$S/continue-preflight.sh" "$ST" "$BD"
has "no model needed" "$T/out" "needs_model: no"
sed -i 's/| T04 | Check the greeting in the tool | Engineer |/| T04 | Check the greeting in the tool | Agent |/' "$ST"
expect "preflight finds an executor mismatch" 1 bash "$S/continue-preflight.sh" "$ST" "$BD"
has "board finding" "$T/out" "board	T04	executor Agent	executor Engineer	fact"

echo "# execute-load.sh"
cp "$F/Demo - Task Status.md" "$T/load-status.md"
sed "s#REPO#$T/repo#g" "$F/Demo - Task Breakdown.md" >"$T/load-bd.md"
expect "load a fresh status" 0 bash "$S/execute-load.sh" "$T/load-status.md" "$T/load-bd.md"
has "status header" "$T/out" "- Next: Start WU1 — Save settings"
has "breakdown header" "$T/out" "- **Build check:** \`bash build.sh\`"
has "work units table" "$T/out" "| WU2 | See a greeting | T03, T04 | Agent + Engineer | WU1 |"
has "unit from Next" "$T/out" "==== unit: WU1"
has "unit checks block" "$T/out" "3 | ok | test -f src/store.sh"
hasnt "no cards" "$T/out" "### T01"
expect "load another unit" 0 bash "$S/execute-load.sh" "$T/load-status.md" "$T/load-bd.md" --unit WU2
has "WU2 engineer steps" "$T/out" "Open the tool and run Greet"
expect "unknown unit" 2 bash "$S/execute-load.sh" "$T/load-status.md" "$T/load-bd.md" --unit WU9

echo "# handoff.sh"
expect "handoff for T02" 0 bash "$S/handoff.sh" "$T/load-bd.md" "$T/load-status.md" T02 --run "$T/run" --base-sha abc123
has "task line" "$T/out" "Implement exactly one task: T02 — Add the settings loader."
has "unit line" "$T/out" "work unit WU1 — Save settings"
has "repo line" "$T/out" "base main @ abc123 · Build check: \`bash build.sh\`"
has "result path" "$T/out" "$T/run/results/T02.md"
has "coder skill" "$T/out" "Invoke the tt-coder skill"
has "changed files left for the coder" "$T/out" "<your changed files>"
grep -qE '<(ID|title|WU ID|name|common|run|base|BASE_SHA|plan path|status path|repo path|breakdown path)>' "$T/out" && bad "every placeholder filled" || ok "every placeholder filled"
expect "unresolvable base" 2 bash "$S/handoff.sh" "$T/load-bd.md" "$T/load-status.md" T02 --run "$T/run"
expect "unknown task" 2 bash "$S/handoff.sh" "$T/load-bd.md" "$T/load-status.md" T99 --run "$T/run" --base-sha abc123

echo "# task-files.sh"
echo 'left over' >"$T/repo/earlier.txt"
expect "snapshot" 0 bash "$S/task-files.sh" snapshot "$T/load-bd.md" "$T/run" T02
has "earlier work in the snapshot" "$T/run/snapshots/T02.tsv" "earlier.txt"
echo 'echo load' >"$T/repo/src/loader.sh"
echo 'echo more' >>"$T/repo/src/store.sh"
echo 'stray' >"$T/repo/stray file.txt"
mkdir -p "$T/repo/.tt" && echo r >"$T/repo/.tt/result.md"
expect "diff flags a file not on the card" 1 bash "$S/task-files.sh" diff "$T/load-bd.md" "$T/run" T02
has "new card file" "$T/out" "new	src/loader.sh	on card"
has "changed card file" "$T/out" "change	src/store.sh	on card"
has "stray file flagged" "$T/out" "new	stray file.txt	NOT ON CARD"
hasnt "earlier work not counted" "$T/out" "earlier.txt"
hasnt "run files ignored" "$T/out" ".tt/"
has "summary" "$T/out" "files: 3 changed, 1 not on the card, 0 card files untouched"
rm "$T/repo/stray file.txt"
expect "diff with every change on the card" 0 bash "$S/task-files.sh" diff "$T/load-bd.md" "$T/run" T02
expect "diff without a snapshot" 2 bash "$S/task-files.sh" diff "$T/load-bd.md" "$T/run" T01

echo "# result-scaffold.sh"
expect "scaffold T02" 0 bash "$S/result-scaffold.sh" "$T/load-bd.md" T02 --run "$T/run"
has "result heading" "$T/out" "# Result: T02 — Add the settings loader"
has "deferred to its unit" "$T/out" "- Validation: Deferred to WU1"
has "changed file listed" "$T/out" "- new \`src/loader.sh\`: <!-- fill: purpose -->"
cp "$T/out" "$T/scaffold.md"
expect "status-log refuses unfilled markers" 2 bash "$S/status-log.sh" "$T/load-status.md" "$T/scaffold.md"
expect "scaffold without a snapshot" 0 bash "$S/result-scaffold.sh" "$T/load-bd.md" T03
has "files marker" "$T/out" "<!-- fill: new|change"
(cd "$T/repo" && git checkout -q -- src/store.sh && rm -rf src/loader.sh earlier.txt .tt)

echo "# fix-card.sh"
expect "fix card for WU1" 0 bash "$S/fix-card.sh" "$T/load-bd.md" WU1 --check 2
has "next ID" "$T/out" "T05"
has "task map row" "$T/out" "| T05 | <title> | Agent | T02 | WU1 | <Plan step> | <Traces to> |"
has "unit tasks" "$T/out" "WU1 Tasks: T01, T02, T05"
has "task board row" "$T/out" "| T05 | <title> | Agent | WU1 | T02 | Todo | |"
has "card heading" "$T/out" "### T05 — <imperative title>"
has "validated in" "$T/out" "**Validated in:** WU1, checks 2"
expect "fix card after a named task" 0 bash "$S/fix-card.sh" "$T/load-bd.md" WU2 --after T03 --executor Engineer
has "engineer executor" "$T/out" "| **Executor** | Engineer |"
expect "unknown unit" 2 bash "$S/fix-card.sh" "$T/load-bd.md" WU9
expect "unknown after task" 2 bash "$S/fix-card.sh" "$T/load-bd.md" WU1 --after T99

echo "# donewhen.sh"
PL="$T/Demo - Comprehensive Tech Plan.md"
expect "list the plan's items" 0 bash "$S/donewhen.sh" "$PL"
has "flat item" "$T/out" "§1	1	It compiles. (R1)"
has "sub-bullet joined to its heading" "$T/out" "§1	2	After a restart: the settings are still there. (R1)"
hasnt "heading bullet not an item" "$T/out" "After a restart:	"
expect "one step" 0 bash "$S/donewhen.sh" "$PL" "§2"
[ "$(wc -l <"$T/out" | tr -d ' ')" = 1 ] && ok "one step's items only" || bad "one step's items only"

echo "# skeleton scripts"
D="$T/draft"; cp -r "$root/tools/fixtures/demo-draft" "$D"; sed -i "s#PLAN#$PL#" "$D/skeleton.md"
expect "skeleton tasks" 0 bash "$S/skeleton-tsv.sh" "$D/skeleton.md" tasks
expect "skeleton units" 0 bash "$S/skeleton-tsv.sh" "$D/skeleton.md" units
has "range expanded" "$T/out" "WU1	Save settings	T01,T02	Agent"
expect "clean skeleton" 0 bash "$S/skeleton-check.sh" "$D"
cp "$D/skeleton.md" "$T/skeleton.good"
sed -i '/^| §1 #3/d; s/| T03 | Add the greeting | Agent | new `src\/greet.sh` |/| T03 | Add the greeting | Agent | new `src\/greet.sh`; change `build.sh` |/' "$D/skeleton.md"
expect "skeleton with defects" 1 bash "$S/skeleton-check.sh" "$D"
has "missing Done-when item" "$T/out" "donewhen	§1 #3	plan item not in the Done-when map"
has "unchanged file" "$T/out" "files	T03	build.sh is marked unchanged"
cp "$T/skeleton.good" "$D/skeleton.md"
expect "render" 0 bash "$S/skeleton-render.sh" "$D"
has "manifest lists a card" "$D/manifest.txt" "parts/31-WU2-T04.md"
has "task map row" "$D/parts/20-task-map.md" "| T02 | Add the settings loader | Agent | T01 | WU1 | §1 | R2, §1 |"
expect "scaffold WU1" 0 bash "$S/card-scaffold.sh" "$D" WU1
expect "scaffold WU2" 0 bash "$S/card-scaffold.sh" "$D" WU2
has "verbatim Done-when item" "$D/parts/30-WU1.md" "- [ ] After a restart: the loader ran once. (R2) (plan §1) (Agent)"
has "unit check first" "$D/parts/30-WU1.md" "- [ ] No debug prints remain (Agent)"
has "plan link" "$D/parts/31-WU1-T02.md" "[[Demo - Comprehensive Tech Plan#§1. Settings store]]"
has "glossary excerpt" "$D/parts/31-WU1-T02.md" '`R2` "Settings load at start."'
has "confirm item" "$D/parts/31-WU1-T02.md" "**Confirm:** Where the loader logs"
expect "scaffold keeps existing parts" 0 bash "$S/card-scaffold.sh" "$D" WU1
has "skipped" "$T/out" "skipped (exists)"
expect "coverage with markers left" 1 bash "$S/coverage.sh" "$D"
has "fill markers reported" "$T/out" "fill	"
for f in "$D"/parts/3*.md; do sed -i 's/<!-- fill: [^>]*-->/Filled in./g' "$f"; echo '<!-- tt:end -->' >>"$f"; done
sed -i '/^Filled in\.$/d' "$D"/parts/30-*.md
expect "coverage once filled" 0 bash "$S/coverage.sh" "$D"
has "coverage part" "$D/parts/80-coverage.md" "| §1 | T01, T02 | WU1 |"
has "creator named" "$D/parts/80-coverage.md" "| \`src/greet.sh\` | T03 (creates) |"
sed -i '/After a restart: the loader ran once/d' "$D/parts/30-WU1.md"
expect "coverage finds a dropped item" 1 bash "$S/coverage.sh" "$D"
has "dropped item" "$T/out" "donewhen	§1 #3	not found verbatim"

echo "# status-init.sh"
expect "init from the breakdown" 0 bash "$S/status-init.sh" "$BD" "$T/init.md"
has "boards" "$T/init.md" "| T04 | Check the greeting in the tool | Engineer | WU2 | T03 | Todo | |"
has "derived header" "$T/init.md" "- Progress: 0 of 2 units Done · 0 of 4 tasks Implemented or Done"
has "branch from the header" "$T/init.md" "- Branch: \`feature/demo\` (base \`main\`)"
expect "init refuses a second document" 2 bash "$S/status-init.sh" "$BD" "$T/init.md"
expect "the new document is consistent" 0 bash "$S/status-counts.sh" "$T/init.md"

echo "# status-boards.sh"
awk '{ print } /^\| WU1 \| Save settings/ { print "| **Second batch** | | | | |" }' "$BD" >"$T/divider.md"
bash "$S/status-boards.sh" "$T/divider.md" >"$T/boards.md"
grep -q '^|  |' "$T/boards.md" && bad "divider row skipped" || ok "divider row skipped"
[ "$(grep -c '^| WU' "$T/boards.md")" = 2 ] && ok "both units kept" || bad "both units kept"

echo "# CRLF documents"
sed 's/$/\r/' "$F/Demo - Task Status.md" >"$T/crlf.md"
expect "set on a CRLF document" 0 bash "$S/status-set.sh" "$T/crlf.md" T01 "In Progress"
[ "$(grep -c $'\r$' "$T/crlf.md")" = "$(wc -l <"$T/crlf.md" | tr -d ' ')" ] && ok "CRLF kept on every line" || bad "CRLF kept on every line"
ls -a "$T" | grep -q '^\.status-' && bad "temp files left behind" || ok "no temp files left behind"

echo "# guide.sh"
GD="$root/tt-guide/scripts/guide.sh"
bash "$GD" quip >"$T/quip"
[ "$(wc -l <"$T/quip" | tr -d ' ')" = 1 ] && ! grep -q '^#' "$T/quip" && ok "one quip, not a comment" || bad "one quip, not a comment" "$(cat "$T/quip")"
bash "$GD" start >"$T/start"
has "start prints the table" "$T/start" "/tt-adversarial-plan"
expect "about a skill" 0 bash "$GD" about tt-execute
has "the skill's entry" "$T/out" "### [\`tt-execute\`]"
expect "about a stage skill" 0 bash "$GD" about scope
has "the planning stages" "$T/out" "### The planning stages"
expect "about a topic" 0 bash "$GD" about "work units"
expect "about nothing known" 1 bash "$GD" about nope
G="$T/guide"; mkdir -p "$G/.tt/Ex - Familiarisation" "$G/empty"; : >"$G/.tt/Ex - Familiarisation/focus-log.md"
printf -- '- **Status:** Draft · **Stage:** Scope\r\n\r\n**Stages**\r\n\r\n| Stage | Status | Output | Challenges |\r\n|---|---|---|---|\r\n| Requirements | Closed | R | |\r\n| Scope & Constraints | Challenge pending | S | |\r\n' >"$G/Draft - Comprehensive Tech Plan.md"
printf -- '- **Status:** Signed off · **Revision:** 3\n' >"$G/Old - Comprehensive Tech Plan.md"
printf -- '- **Mirrors revision:** 2 of the comprehensive plan\n' >"$G/Old - Tech Plan.md"
cp "$ST" "$G/Demo - Task Status.md"
(cd "$G" && bash "$GD" where) >"$T/where" 2>&1
has "draft plan stage" "$T/where" "Draft: planning, draft plan at Scope & Constraints (Challenge pending)."
has "resume planning" "$T/where" "/tt-adversarial-plan resume \"Draft - Comprehensive Tech Plan.md\""
has "signed off, break down" "$T/where" "/tt-task-breakdown \"Old - Comprehensive Tech Plan.md\""
has "stale Tech Plan" "$T/where" "mirrors revision 2; the plan is at 3"
has "Task Status, execute" "$T/where" "/tt-execute \"Demo - Task Status.md\""
has "Focus Log" "$T/where" "/tt-familiarisation-doc \".tt/Ex - Familiarisation/focus-log.md\""
hasnt "no awk warnings" "$T/where" "warning"
bash "$GD" where "$G/empty" >"$T/where"
has "empty folder" "$T/where" "No tt documents in"
expect "no such folder" 2 bash "$GD" where "$G/missing"

# update checks and repairs each supported personal skill location without
# fetching the real toolbox repository.
U="$T/update-toolbox"; mkdir -p "$U/tt-guide/scripts" "$U/tt-alpha" "$U/tt-beta"
cp "$GD" "$U/tt-guide/scripts/guide.sh"
git init -q "$U"
H="$T/update-home"; mkdir -p "$H/.claude/skills" "$H/.copilot/skills"
mkdir "$T/not-alpha"; MSYS=winsymlinks:nativestrict ln -s "$T/not-alpha" "$H/.copilot/skills/tt-alpha"; rmdir "$T/not-alpha"
HOME="$H" bash "$U/tt-guide/scripts/guide.sh" update check >"$T/update-check" 2>&1
has "update checks Claude skills" "$T/update-check" "Symlink check ($H/.claude/skills):"
has "update checks Copilot skills" "$T/update-check" "Symlink check ($H/.copilot/skills):"
has "update checks Codex skills" "$T/update-check" "Symlink check ($H/.agents/skills):"
has "update reports a broken link" "$T/update-check" "BROKEN    tt-alpha"
expect "update applies all skill locations" 0 env HOME="$H" bash "$U/tt-guide/scripts/guide.sh" update apply
[ "$(cd "$H/.claude/skills/tt-beta" && pwd -P)" = "$(cd "$U/tt-beta" && pwd -P)" ] && ok "update creates Claude link" || bad "update creates Claude link"
[ "$(cd "$H/.copilot/skills/tt-alpha" && pwd -P)" = "$(cd "$U/tt-alpha" && pwd -P)" ] && ok "update repairs Copilot link" || bad "update repairs Copilot link"
[ "$(cd "$H/.agents/skills/tt-guide" && pwd -P)" = "$(cd "$U/tt-guide" && pwd -P)" ] && ok "update creates Codex link" || bad "update creates Codex link"


echo "# workflow-state.sh"
WS="$root/tt-common/scripts/workflow-state.sh"
bash "$WS" --tsv "$G" >"$T/rows"
has "building row" "$T/rows" "Demo	primary	building	tt-execute		$G/Demo - Task Status.md	"
has "planning row" "$T/rows" "Draft	primary	planning	tt-adversarial-plan	resume	$G/Draft - Comprehensive Tech Plan.md	"
has "signed-off row" "$T/rows" "Old	primary	signed-off	tt-task-breakdown		$G/Old - Comprehensive Tech Plan.md	"
has "review the plan alt row" "$T/rows" "Old	alt	signed-off	tt-tech-plan-review"
has "stale Tech Plan warn row" "$T/rows" "Old	warn	signed-off	tt-tech-plan"
has "exploring row" "$T/rows" "Ex	primary	exploring	tt-familiarise	resume	$G/.tt/Ex - Familiarisation/focus-log.md	"
has "write-up alt row" "$T/rows" "Ex	alt	exploring	tt-familiarisation-doc"
W2="$T/wstate"; mkdir -p "$W2/.tt/Dr - Task Breakdown"
printf -- '- **Status:** Signed off 2026-10-01 · **Revision:** 1\n' >"$W2/Dr - Comprehensive Tech Plan.md"
printf -- '- **Status:** Signed off 2026-10-01 · **Revision:** 1\n' >"$W2/Bd - Comprehensive Tech Plan.md"
: >"$W2/Bd - Task Breakdown.md"
printf -- '- **Status:** Signed off · **Revision:** 1\n' >"$W2/Fresh - Comprehensive Tech Plan.md"
: >"$W2/Fam - Familiarisation.md"
: >"$W2/Orph - Task Breakdown.md"
sed 's/^- State: .*/- State: Complete/' "$ST" >"$W2/Fin - Task Status.md"
bash "$WS" --tsv "$W2" >"$T/rows"
has "breakdown draft" "$T/rows" "Dr	primary	breakdown-draft	tt-task-breakdown"
has "breakdown, no status" "$T/rows" "Bd	primary	breakdown-written	tt-task-status"
has "ready to break down" "$T/rows" "Fresh	primary	signed-off	tt-task-breakdown"
has "explored" "$T/rows" "Fam	primary	explored	tt-adversarial-plan"
has "orphan breakdown" "$T/rows" "Orph	primary	breakdown-orphan	tt-task-status"
has "complete has no skill" "$T/rows" "Fin	primary	complete	-"
has "complete offers MR review" "$T/rows" "Fin	alt	complete	tt-mr-review"
expect "empty folder is exit 1" 1 bash "$WS" "$G/empty"
has "empty folder row" "$T/out" "/tt-adversarial-plan <idea, spec or ticket>"
expect "bad folder is exit 2" 2 bash "$WS" "$G/missing"
expect "no folder is exit 2" 2 bash "$WS"

echo "# tatty.sh"
TY="$root/tt-common/scripts/tatty.sh"
bash "$TY" quip >"$T/quip"
[ "$(wc -l <"$T/quip" | tr -d ' ')" = 1 ] && ! grep -q '^#' "$T/quip" && ok "one quip, not a comment" || bad "one quip, not a comment" "$(cat "$T/quip")"
TT_GUIDE_ASCII=1 bash "$TY" banner >"$T/banner"
has "banner is Tatty" "$T/banner" "Tatty"
grep -q '[^ -~]' "$T/banner" && bad "ASCII banner has no box characters" || ok "ASCII banner has no box characters"
expect "unknown tatty command" 2 bash "$TY" nope

echo "# workflow.sh"
WF="$root/tt-workflow/scripts/workflow.sh"
export TT_WORKFLOW_HOME="$T/wfhome"
mkdir -p "$T/wf proj/feature a" "$T/other"
(cd "$T/wf proj" && git init -q)
wf() { (cd "$T/wf proj" && bash "$WF" "$@"); }
expect "nothing linked" 0 wf start
has "start says none linked" "$T/out" "No folder linked"
expect "state with no link" 1 wf state
expect "link a folder" 0 wf link "$T/wf proj/feature a"
expect "start shows the link" 0 wf start
has "start shows the folder" "$T/out" "Linked folder: "
has "start shows the state" "$T/out" "No tt documents in"
expect "link replaces" 0 wf link "$T/other"
[ "$(wc -l <"$TT_WORKFLOW_HOME/links.tsv" | tr -d ' ')" = 1 ] && ok "one row per project" || bad "one row per project"
(cd "$T/other" && git init -q && bash "$WF" link "$T/wf proj" >/dev/null)
[ "$(wc -l <"$TT_WORKFLOW_HOME/links.tsv" | tr -d ' ')" = 2 ] && ok "projects kept apart" || bad "projects kept apart"
expect "link a missing folder" 2 wf link "$T/nowhere"
expect "new creates and links" 0 wf new "$T/wf proj" "Feature B"
has "new prints the prefix" "$T/out" "Prefix: Feature B"
[ -d "$T/wf proj/Feature B" ] && ok "new made the folder" || bad "new made the folder"
expect "state follows the new link" 0 wf state
has "state names the new folder" "$T/out" "Feature B"
echo x >"$T/wf proj/Feature B/file.txt"
expect "new refuses a non-empty folder" 2 wf new "$T/wf proj" "Feature B"
expect "new refuses a bad name" 2 wf new "$T/wf proj" "a/b"
expect "new refuses a missing parent" 2 wf new "$T/nowhere" "X"
rm -rf "$T/wf proj/Feature B"
expect "stale link is reported" 2 wf state
has "stale link message" "$T/out" "linked folder is missing"
expect "unlink" 0 wf unlink
expect "unlink again" 1 wf unlink
echo "# lite.sh (its own link)"
LITE="$root/tt-workflow-lite/scripts/lite.sh"
lw() { (cd "$T/wf proj" && bash "$LITE" "$@"); }
expect "lite: nothing linked, whatever tt-workflow links" 1 lw state
wf link "$T/wf proj/feature a" >/dev/null
expect "lite: still nothing linked" 1 lw state
expect "lite: link a folder" 0 lw link "$T/wf proj/feature a"
[ -f "$TT_WORKFLOW_HOME/lite-links.tsv" ] && ok "lite keeps its own links file" || bad "lite keeps its own links file"
expect "lite: new folder" 0 lw new "$T/wf proj" "Lite B"
expect "lite: an empty task folder" 0 lw state
has "lite: asks bug or feature" "$T/out" "a new task: is it a bug or a feature?"
hasnt "lite: no full-pipeline suggestion" "$T/out" "tt-adversarial-plan"
expect "tt-workflow's link is untouched" 0 wf state
has "tt-workflow still on its folder" "$T/out" "No tt documents in"
rm -rf "$T/wf proj/Lite B"
lw unlink >/dev/null; wf unlink >/dev/null

echo "# lite brief: lite-index.sh and lite-check.sh"
LF="$root/tools/fixtures/lite"
mkdir -p "$T/lrepo/src" && (cd "$T/lrepo" && git init -q -b feature/farewell && git config core.autocrlf false && echo 'exit 0' >build.sh &&
	echo 'echo hello' >src/greet.sh && git add . && git -c user.email=t@t -c user.name=t commit -qm init)
mkdir -p "$T/lite"
LB="$T/lite/Farewell - Lite Brief.md"; LS="$T/lite/Farewell - Task Status.md"; LR="$T/lite/.tt/Farewell - Task Status"
sed "s#REPO#$T/lrepo#g" "$LF/Farewell - Lite Brief.md" >"$LB"
expect "the fixture brief is clean" 0 bash "$S/lite-check.sh" "$LB"
expect "tables are up to date" 0 bash "$S/lite-index.sh" --check "$LB"
awk '/^## Work Units/ { s = 1 } /^## WU1/ { s = 0 } !s' "$LB" >"$T/lite/notables.md"
expect "missing tables are flagged" 1 bash "$S/lite-index.sh" --check "$T/lite/notables.md"
expect "lite-index writes them" 0 bash "$S/lite-index.sh" "$T/lite/notables.md"
cmp -s "$LB" "$T/lite/notables.md" && ok "regenerated tables match the written ones" || bad "regenerated tables match the written ones"
sed 's/$/\r/' "$LB" >"$T/lite/crlf.md"; awk '/^## Work Units/ { s = 1 } /^## WU1/ { s = 0 } !s' "$T/lite/crlf.md" >"$T/lite/crlf2.md"
expect "lite-index on a CRLF brief" 0 bash "$S/lite-index.sh" "$T/lite/crlf2.md"
[ "$(grep -c $'\r$' "$T/lite/crlf2.md")" = "$(wc -l <"$T/lite/crlf2.md" | tr -d ' ')" ] && ok "CRLF kept on every line" || bad "CRLF kept on every line"
lc() { sed "$2" "$LB" >"$T/lite/bad.md"; expect "lite-check: $1" 1 bash "$S/lite-check.sh" "$T/lite/bad.md"; }
lc "an Agent card with no Files" '/^- new `src\/farewell.sh`/d'; has "names the card" "$T/out" "card T01: an Agent card needs Files"
lc "a checks line for a missing item" 's/^2 | nonempty/9 | nonempty/'; has "names the line" "$T/out" "checks line 9 names no Validation item"
lc "a checks line for an engineer item" 's/^2 | nonempty/3 | nonempty/'; has "engineer item" "$T/out" "only the engineer checks"
lc "an uncited acceptance item" 's/ (A1) (Agent)/ (Agent)/'; has "names the item" "$T/out" "acceptance A1 is not cited"
lc "an ID inside a code fence" 's/^1 | ok | bash build.sh/1 | ok | bash build.sh # T07/'; has "ID in code" "$T/out" "planning ID in a code block"
lc "an unknown executor" 's/\*\*Executor\*\* | Agent/**Executor** | Robot/'; has "executor" "$T/out" "Executor must be Agent or Engineer"
lc "a dependency on a missing card" 's/\*\*Depends on\*\* | T01/**Depends on** | T09/'; has "dependency" "$T/out" "T09, which is not a card"
lc "no Build check" '/Build check/d'; has "build check" "$T/out" "no **Build check:**"
lc "a stale Task Map" 's/| T02 | Look at the farewell in the tool | Engineer/| T02 | Look at it | Engineer/'; has "stale" "$T/out" "out of date"
lc "a leftover marker" 's/^None\.$/TODO/'; has "marker" "$T/out" "leftover marker"
expect "lite-check: not a file" 2 bash "$S/lite-check.sh" "$T/lite/none.md"
sed 's/^1 | ok | bash build.sh/1 | ok | bash build.sh # T07/' "$LB" >"$T/lite/Spaced - Lite Brief.md"
expect "lite-check: an ID in a code fence, in a file name with spaces" 1 bash "$S/lite-check.sh" "$T/lite/Spaced - Lite Brief.md"
has "the hit is reported" "$T/out" "planning ID in a code block: T07"
{ printf -- '---
tags: [x]
---
'; cat "$LB"; } >"$T/lite/fm.md"
expect "lite-check: YAML front matter before the title" 0 bash "$S/lite-check.sh" "$T/lite/fm.md"
{ printf -- '# Tags
#a
---
'; cat "$LB"; } >"$T/lite/tags.md"
expect "lite-check: a tag block before the title" 0 bash "$S/lite-check.sh" "$T/lite/tags.md"
lc "a title that isn't a Lite Brief" '1s/.*/# Farewell: Task Breakdown/'; has "title" "$T/out" "the title must read"

echo "# the tt-execute scripts on a Lite Brief"
expect "status-init with a label" 0 bash "$S/status-init.sh" --label "Lite Brief" "$LB" "$LS"
has "documents line" "$LS" "**Documents:** [Lite Brief](Farewell%20-%20Lite%20Brief.md) · Repo"
hasnt "no second label" "$LS" "Lite Brief [Lite Brief]"
has "boards from the brief" "$LS" "| T02 | Look at the farewell in the tool | Engineer | WU1 | T01 | Todo | |"
expect "the status is consistent" 0 bash "$S/status-counts.sh" "$LS"
expect "execute-load reads the brief" 0 bash "$S/execute-load.sh" "$LS" "$LB"
has "load: the unit" "$T/out" "==== unit: WU1"
has "load: the checks block" "$T/out" "2 | nonempty | bash src/farewell.sh"
expect "preflight: the brief is its own plan" 0 bash "$S/continue-preflight.sh" "$LS" "$LB" --plan "$LB"
has "preflight says so" "$T/out" "plan: not checked (the document is its own plan)"
expect "handoff for T01" 0 bash "$S/handoff.sh" "$LB" "$LS" T01 --run "$LR" --plan "$LB" --base-sha abc1234
has "handoff names the task" "$T/out" "Implement exactly one task: T01 — Add the farewell."
has "handoff names the unit" "$T/out" "work unit WU1 — Say goodbye"
has "handoff gives the build check" "$T/out" "Build check: \`bash build.sh\`"
mkdir -p "$LR/results"
expect "snapshot" 0 bash "$S/task-files.sh" snapshot "$LB" "$LR" T01
expect "start T01" 0 bash "$S/status-set.sh" "$LS" T01 "In Progress"
echo 'echo goodbye' >"$T/lrepo/src/farewell.sh"
expect "scope check" 0 bash "$S/task-files.sh" diff "$LB" "$LR" T01
bash "$S/result-scaffold.sh" "$LB" T01 --run "$LR" >"$LR/results/T01.md"
has "scaffold lists the card file" "$LR/results/T01.md" "- new \`src/farewell.sh\`"
expect "log refuses unfilled markers" 2 bash "$S/status-log.sh" "$LS" "$LR/results/T01.md"
cat >"$LR/results/T01.md" <<'EOF'
# Result: T01 — Add the farewell

- Task status: implemented
- Validation: Deferred to WU1

## Files Modified
- new `src/farewell.sh`: prints the farewell

## Summary
Wrote it.

## To validate
1. Run `bash src/farewell.sh` → expect goodbye.

## Follow-up Concerns
none

## Risks
- none

## Improvements
none

## Critical Decision
none
EOF
expect "log T01" 0 bash "$S/status-log.sh" "$LS" "$LR/results/T01.md"
bash "$S/status-set.sh" "$LS" T02 "In Progress" >/dev/null
expect "T02 implemented" 0 bash "$S/status-set.sh" "$LS" T02 Implemented
expect "unit ready" 0 bash "$S/status-set.sh" "$LS" WU1 "Ready to Validate"
expect "run the unit's checks" 0 bash "$S/run-checks.sh" "$LB" WU1 "$LR/validation/WU1-attempt1" --why "first run"
has "build passed" "$T/out" "passed	bash build.sh"
expect "record the attempt" 0 bash "$S/status-record.sh" "$LS" validation WU1 --file "$LR/validation/WU1-attempt1/attempt.md"
expect "engineer checklist" 0 bash "$S/validation-checklist.sh" "$LB" "$LS" WU1
has "checklist: the engineer's check" "$T/out" "The farewell looks right in the tool"
expect "engineer check passes" 0 bash "$S/status-record.sh" "$LS" check WU1 3 passed --evidence "saw goodbye"
expect "unit done" 0 bash "$S/status-set.sh" "$LS" WU1 Done
has "all complete" "$LS" "- State: Complete"
expect "no planning IDs in the written code" 0 bash "$S/check-planning-ids.sh" --repo "$T/lrepo" "$T/lrepo/src/farewell.sh"

echo "# workflow-state.sh: the lite route"
L2="$T/lstate"; mkdir -p "$L2/.tt/A - Familiarisation" "$L2/.tt/B - Familiarisation" "$L2/.tt/C - Debug" "$L2/.tt/D - Debug" "$L2/.tt/E - Debug"
printf -- '- **Mode:** lite\n- **Status:** Focus confirmed 2026-10-12\n' >"$L2/.tt/A - Familiarisation/focus-log.md"
printf -- '- **Mode:** lite\n- **Status:** Exploring\n  (later: `Focus confirmed <date>`)\n' >"$L2/.tt/B - Familiarisation/focus-log.md"
printf -- '- **Status:** Debugging · **Next:** x\n' >"$L2/.tt/C - Debug/debug-log.md"
printf -- '- **Status:** Root cause confirmed 2026-10-12 · **Next:** -\n' >"$L2/.tt/D - Debug/debug-log.md"
printf -- '- **Status:** Unresolved 2026-10-12\n' >"$L2/.tt/E - Debug/debug-log.md"
: >"$L2/F - Debug Report.md"; : >"$L2/G - Lite Brief.md"; : >"$L2/H - Lite Brief.md"
cp "$ST" "$L2/H - Task Status.md"
bash "$WS" --tsv "$L2" >"$T/rows"
has "lite focus confirmed" "$T/rows" "A	primary	lite-focus	tt-lite-brief		$L2/.tt/A - Familiarisation/focus-log.md	"
has "lite focus not confirmed" "$T/rows" "B	primary	exploring	tt-familiarise	resume"
hasnt "no write-up offered for a lite exploration" "$T/rows" "B	alt	exploring	tt-familiarisation-doc"
has "debugging" "$T/rows" "C	primary	debugging	tt-debug	resume	$L2/.tt/C - Debug/debug-log.md	"
has "root cause confirmed: the report" "$T/rows" "D	primary	debug-done	tt-debug-doc"
has "root cause confirmed: or fix it" "$T/rows" "D	alt	debug-done	tt-lite-brief"
has "unresolved: the report" "$T/rows" "E	primary	debug-done	tt-debug-doc"
hasnt "unresolved: no fix offered" "$T/rows" "E	alt"
has "report written" "$T/rows" "F	primary	debugged	-"
has "lite brief, not started" "$T/rows" "G	primary	lite-brief	tt-execute-lite		$L2/G - Lite Brief.md	"
has "building a lite brief" "$T/rows" "H	primary	building	tt-execute-lite		$L2/H - Lite Brief.md	"
hasnt "not tt-execute" "$T/rows" "H	primary	building	tt-execute	"
printf -- '- **Status:** Root cause confirmed 2026-10-12 · **Next:** - · Documented 2026-10-12: x
' >"$L2/.tt/C - Debug/debug-log.md"
: >"$L2/C - Debug Report.md"
mkdir -p "$L2/.tt/J - Debug" "$L2/.tt/K - Debug"
printf -- '- **Status:** Unresolved 2026-10-12 · **Next:** - · Documented 2026-10-12: x
' >"$L2/.tt/J - Debug/debug-log.md"; : >"$L2/J - Debug Report.md"
printf -- '- **Status:** Root cause confirmed 2026-10-12 · **Next:** -
' >"$L2/.tt/K - Debug/debug-log.md"; : >"$L2/K - Lite Brief.md"
bash "$WS" --tsv "$L2" >"$T/rows"
has "documented keeps the outcome: the fix is offered" "$T/rows" "C	alt	debugged	tt-lite-brief"
has "unresolved and written up" "$T/rows" "J	primary	debugged	-"
hasnt "unresolved: no fix offered" "$T/rows" "J	alt"
has "a brief before the write-up: the report is still offered" "$T/rows" "K	alt	debug-done	tt-debug-doc"

echo "# debug-doc.sh and debug-temp.sh"
DT="$T/dbg"; mkdir -p "$DT"
sed "s#FOLDER#$DT#" "$LF/Slow - debug-log.md" >"$DT/log.md"
expect "a finished log is complete" 0 bash "$S/debug-doc.sh" --check "$DT/log.md"
expect "render the report" 0 bash "$S/debug-doc.sh" "$DT/log.md" "$DT/Slow - Debug Report.md"
has "outcome" "$DT/Slow - Debug Report.md" "**Outcome:** Root cause found"
has "the root cause" "$DT/Slow - Debug Report.md" "prints the name variable without a fallback"
has "what it wasn't" "$DT/Slow - Debug Report.md" "| The caller passes an empty string (engineer's) |"
has "log path from the prefix" "$DT/Slow - Debug Report.md" ".tt/Slow - Debug/debug-log.md"
has "temporary edits removed" "$DT/Slow - Debug Report.md" "has been removed"
expect "the report is not overwritten" 2 bash "$S/debug-doc.sh" "$DT/log.md" "$DT/Slow - Debug Report.md"
expect "references in the report check out" 0 bash "$S/verify-refs.sh" --repo "$T/lrepo" --worktree --only-problems "$DT/Slow - Debug Report.md"
dd() { sed "$2" "$DT/log.md" >"$DT/bad.md"; expect "debug-doc: $1" 1 bash "$S/debug-doc.sh" --check "$DT/bad.md"; }
dd "a draft In short" 's/^The greeting script prints/(draft) The greeting script prints/'; has "draft" "$T/out" "still marked (draft)"
dd "an unfinished status" 's/Root cause confirmed 2026-10-12/Debugging/'; has "status" "$T/out" "a finished Status"
dd "a temporary edit left" 's/| yes |$/| no |/'; has "left" "$T/out" "temporary edit not removed"
dd "no root cause text" '/^`src\/greet.sh:1` prints/d'; has "root cause" "$T/out" "the Root cause section"
dd "no Root cause hypothesis" 's/| Root cause |/| Supported |/'; has "hypothesis" "$T/out" "Status \"Root cause\""
sed 's/Root cause confirmed 2026-10-12/Unresolved 2026-10-12/; /^`src\/greet.sh:1` prints/d; s/| Root cause |/| Supported |/' "$DT/log.md" >"$DT/unres.md"
expect "an unresolved log is complete" 0 bash "$S/debug-doc.sh" "$DT/unres.md" "$DT/unres-report.md"
has "unresolved outcome" "$DT/unres-report.md" "**Outcome:** Unresolved"
has "where it stands" "$DT/unres-report.md" "## Where it stands"
mkdir -p "$T/dtrepo/.tt" && (cd "$T/dtrepo" && git init -q && echo 'echo hi' >a.sh && git add a.sh && git -c user.email=t@t -c user.name=t commit -qm i)
echo 'echo dbg # TT-DEBUG-TEMP' >"$T/dtrepo/b.sh"; echo 'the marker TT-DEBUG-TEMP' >"$T/dtrepo/.tt/log.md"
expect "debug-temp finds an untracked line" 1 bash "$S/debug-temp.sh" check "$T/dtrepo"
has "names the file" "$T/out" "b.sh:1:"
hasnt "ignores .tt" "$T/out" ".tt/log.md"
expect "debug-temp list never fails" 0 bash "$S/debug-temp.sh" list "$T/dtrepo"
rm "$T/dtrepo/b.sh"
expect "debug-temp clean" 0 bash "$S/debug-temp.sh" check "$T/dtrepo"
echo 'TT-DEBUG-TEMP in a cell' >"$T/dtrepo/Slow - Debug Report.md"
expect "debug-temp ignores a Debug Report" 0 bash "$S/debug-temp.sh" check "$T/dtrepo"

echo "# new-session.sh"
NS="$S/new-session.sh"
if command -v claude >/dev/null 2>&1; then
	expect "print the command" 0 bash "$NS" --print "$T" '/tt-execute-lite "a b.md"'
	has "shows the command" "$T/out" "claude '/tt-execute-lite \"a b.md\"'"
	expect "no such folder" 2 bash "$NS" --print "$T/none" "x"
else
	ok "new-session.sh needs the claude command (skipped)"
fi
expect "new-session usage" 2 bash "$NS"
if command -v claude >/dev/null 2>&1; then
	expect "print the command with a name" 0 bash "$NS" --print --name "Feat : Scope" "$T" '/tt-workflow'
	has "shows the name" "$T/out" "claude -n 'Feat : Scope' '/tt-workflow'"
	expect "print a quote in the name" 0 bash "$NS" --print --name "Bob's : Scope" "$T" '/tt-workflow'
	has "quote survives" "$T/out" "-n 'Bob'\\''s : Scope'"
fi
expect "name needs a value" 2 bash "$NS" --name

echo "# workflow-state.sh: the stage column"
bash "$WS" --tsv "$G" >"$T/rows"
stage_is() { awk -F'\t' -v p="$2" -v k="$3" -v want="$4" '$1 == p && $2 == k { found = 1; got = $9 } END { exit !(found && got == want) }' "$1" && ok "stage: $5" || bad "stage: $5" "$(grep "^$2	$3" "$1")"; }
stage_is "$T/rows" Demo primary Build "building"
stage_is "$T/rows" Draft primary "Scope & Constraints" "a draft plan names its open stage"
stage_is "$T/rows" Old primary "Task Breakdown" "signed off"
stage_is "$T/rows" Ex primary Familiarise "exploring"
bash "$WS" --tsv "$W2" >"$T/rows"
stage_is "$T/rows" Dr primary "Task Breakdown" "breakdown draft"
stage_is "$T/rows" Fam primary Planning "explored"
stage_is "$T/rows" Fin primary "" "complete has no stage"
bash "$WS" --tsv "$L2" >"$T/rows"
stage_is "$T/rows" A primary "Lite Brief" "lite exploration done"
stage_is "$T/rows" D primary "Debug Report" "debug finished"
stage_is "$T/rows" F primary Fix "debugged"
stage_is "$T/rows" G primary Build "lite brief"

echo "# workflow.sh linked, session-handoff.sh"
SHF="$S/session-handoff.sh"
hf() { (cd "$T/wf proj" && bash "$SHF" "$@"); }
HF="$T/wf proj/hand"; mkdir -p "$HF"
cp "$G/Draft - Comprehensive Tech Plan.md" "$HF/Fleet Steer - Comprehensive Tech Plan.md"
expect "linked: nothing linked" 1 wf linked
wf unlink >/dev/null; lw unlink >/dev/null
expect "linked: nothing linked" 1 wf linked
expect "unlinked: the next step's own command" 0 hf --show "$HF"
has "name is feature : stage" "$T/out" "Name: Fleet Steer : Scope & Constraints"
has "own resume command" "$T/out" "Prompt: /tt-adversarial-plan resume \""
expect "link for the handoff" 0 wf link "$HF"
expect "linked prints the folder" 0 wf linked
expect "linked: tt-workflow" 0 hf --show "$HF"
has "tt-workflow command" "$T/out" "Prompt: /tt-workflow"
hasnt "not its own command" "$T/out" "tt-adversarial-plan"
wf unlink >/dev/null; lw link "$HF" >/dev/null
expect "lite-linked: tt-workflow-lite" 0 hf --show "$HF"
has "tt-workflow-lite command" "$T/out" "Prompt: /tt-workflow-lite"
wf link "$HF" >/dev/null
expect "linked both: a full phase uses tt-workflow" 0 hf --show "$HF"
has "tt-workflow when both" "$T/out" "Prompt: /tt-workflow"
hasnt "not lite when both" "$T/out" "tt-workflow-lite"
expect "--entry overrides" 0 hf --show --entry tt-workflow-lite "$HF"
has "entry honoured" "$T/out" "Prompt: /tt-workflow-lite"
expect "bad --entry" 2 hf --show --entry nope "$HF"
cp "$ST" "$HF/Other - Task Status.md"
expect "several features need --prefix" 2 hf --show "$HF"
has "lists the features" "$T/out" "Fleet Steer"
expect "--prefix picks one" 0 hf --show --prefix Other "$HF"
has "building stage" "$T/out" "Name: Other : Build"
expect "--stage and --run override" 0 hf --show --prefix Other --stage "Write-up" --run '/tt-familiarisation-doc "x.md"' "$HF"
has "stage override" "$T/out" "Name: Other : Write-up"
has "run override" "$T/out" 'Prompt: /tt-familiarisation-doc "x.md"'
export CLAUDE_CONFIG_DIR="$T/cc"; mkdir -p "$T/cc/sessions"
expect "a free name is used as it is" 0 hf --show --prefix Other "$HF"
has "no counter when free" "$T/out" "Name: Other : Build"
hasnt "no counter when free (2)" "$T/out" "(2)"
printf '{"pid":1,"name":"Other : Build","nameSource":"user"}' >"$T/cc/sessions/1.json"
expect "a name in use gets (2)" 0 hf --show --prefix Other "$HF"
has "counter added" "$T/out" "Name: Other : Build (2)"
printf '{"pid":3,"name":"Other : Build (2)","nameSource":"user"}' >"$T/cc/sessions/3.json"
expect "and then (3)" 0 hf --show --prefix Other "$HF"
has "next counter" "$T/out" "Name: Other : Build (3)"
printf '{"pid":4,"name":"Other : Build-mighty-kahan","nameSource":"collision"}' >"$T/cc/sessions/4.json"
rm -f "$T/cc/sessions/"[123].json
expect "a suffixed name is not a clash" 0 hf --show --prefix Other "$HF"
has "plain again" "$T/out" "Name: Other : Build"
hasnt "plain again, no counter" "$T/out" "(2)"
unset CLAUDE_CONFIG_DIR
expect "no tt documents" 2 hf --show "$G/empty"
mkdir -p "$HF/done"; sed 's/^- State: .*/- State: Complete/' "$ST" >"$HF/done/Fin - Task Status.md"
expect "nothing left to run" 2 hf --show "$HF/done"
expect "no such folder" 2 hf --show "$HF/none"
wf unlink >/dev/null; lw unlink >/dev/null

unset TT_WORKFLOW_HOME

echo "# model-config.sh"
MC() { bash "$S/model-config.sh" "$@"; }
export TT_CONFIG_DIR="$T/ttconfig"
expect "get defaults to recommended" 0 MC get adversary
has "adversary is opus/high" "$T/out" "model=opus effort=high"
expect "coder is sonnet" 0 MC get coder
has "coder default" "$T/out" "model=sonnet effort=-"
expect "unknown role" 2 MC get nope
expect "set rejects a bad model" 2 MC set coder gpt high
expect "set rejects a bad effort" 2 MC set coder opus loud
expect "set rejects a bad role" 2 MC set nope opus high
expect "set an override" 0 MC set coder opus medium
expect "get sees the override" 0 MC get coder
has "override applied" "$T/out" "model=opus effort=medium"
expect "second set replaces the first" 0 MC set coder haiku -
MC get coder >"$T/out"
has "replaced, not appended" "$T/out" "model=haiku effort=-"
expect "saving from an edited shipped mode" 0 MC save cheap
has "active after save" "$T/out" "active mode: cheap"
expect "save refuses an existing name" 1 MC save cheap
expect "save refuses a shipped name" 2 MC save economy --force
expect "recommended stays pristine" 0 MC use recommended
MC get coder >"$T/out"; has "shipped mode not changed by save" "$T/out" "model=sonnet effort=-"
expect "use a saved mode" 0 MC use cheap
MC get coder >"$T/out"; has "saved mode applies" "$T/out" "model=haiku effort=-"
expect "use an unknown mode" 2 MC use nope
expect "economy has no opus" 0 MC use economy
MC list >"$T/out"; hasnt "economy list has no opus" "$T/out" " opus "
MC use thorough >/dev/null; MC get plan-audit >"$T/out"; has "thorough gates on opus" "$T/out" "model=opus effort=high"
MC set unit-writer opus low >/dev/null
expect "editing a shipped mode shadows it" 0 MC modes
has "shows edited" "$T/out" "thorough (shipped, edited)"
expect "reset drops the edits" 0 MC reset thorough
MC get unit-writer >"$T/out"; has "reset restored the default" "$T/out" "model=sonnet effort=-"
expect "reset refuses a saved mode" 2 MC reset cheap
expect "delete refuses a shipped mode" 2 MC delete economy
MC use cheap >/dev/null
expect "delete a saved mode" 0 MC delete cheap
MC modes >"$T/out"; has "back on recommended after deleting the active mode" "$T/out" "* recommended"
MC list >"$T/out"
tiers=$(awk 'NR > 2 && NF && $1 ~ /^[*]?$|^[1-4]$/ { for (i = 1; i <= NF; i++) if ($i ~ /^[1-4]$/) { print $i; break } }' "$T/out" | tr -d '\n')
[ "$tiers" = "$(printf '%s' "$tiers" | fold -w1 | sort -n | tr -d '\n')" ] && ok "list is ordered by tier" || bad "list is ordered by tier" "$tiers"
expect "stage note for an advisory stage" 0 MC stage-note tt-approach
has "note names the model" "$T/out" "/model opus and /effort high"
MC set tt-scope - - >/dev/null
expect "no note when a stage is left to the session" 0 MC stage-note tt-scope
[ ! -s "$T/out" ] && ok "session-default stage note is empty" || bad "session-default stage note is empty" "$(cat "$T/out")"
expect "no note for a subagent role" 0 MC stage-note adversary
[ ! -s "$T/out" ] && ok "subagent role has no stage note" || bad "subagent role has no stage note"
CLAUDE_CODE_USE_BEDROCK=1 ANTHROPIC_DEFAULT_OPUS_MODEL= HOME="$T/nohome" expect "status" 0 MC status
has "bedrock warning" "$T/out" "warning: this looks like Bedrock"
CLAUDE_CODE_USE_BEDROCK=1 ANTHROPIC_DEFAULT_OPUS_MODEL=x HOME="$T/nohome" expect "status with the alias set" 0 MC status
hasnt "no warning when set" "$T/out" "warning"
# every role is wired into a skill, and every wired role exists
roles=$(awk -F'\t' '$1 !~ /^#/ && $2 == "sub" { print $1 }' "$root/tt-common/model-roles.tsv")
used=$(grep -rhoE 'model-config\.sh get [a-z][a-z-]*' "$root"/tt-*/ --include=*.md | awk '{ print $3 }' | sort -u)
for r in $roles; do printf '%s\n' "$used" | grep -qx "$r" && ok "role $r is used by a skill" || bad "role $r is used by a skill" "no 'model-config.sh get $r' in any skill"; done
for r in $used; do printf '%s\n' "$roles" | grep -qx "$r" && ok "skill role $r is registered" || bad "skill role $r is registered"; done
hardcoded=$(grep -rln 'model: sonnet' "$root"/tt-*/ --include=*.md || true)
[ -z "$hardcoded" ] && ok "no skill hard-codes a model" || bad "no skill hard-codes a model" "$hardcoded"
unset TT_CONFIG_DIR
echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
