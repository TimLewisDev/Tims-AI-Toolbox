#!/usr/bin/env bash
# test-scripts.sh: smoke tests for the tt-common status and continue-mode
# scripts, run against tools/fixtures/demo in a throwaway git repo. Needs bash,
# awk and git only. Prints one line per check and a count; exit 1 on failure.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
core="$root/plugins/core/skills"; eng="$root/plugins/engineering/skills"
S="$core/tt-common/scripts"
F="$root/tools/fixtures/demo"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
# Keep the tests' stage-completion events out of the real ledger.
export TT_EVENTS_HOME="$T/events"
# Register the plugins the way their SessionStart hooks do, in a pointer folder of
# our own: skills in one plugin reach tt-common and each other through it.
export TT_PLUGINS_HOME="$T/tt-plugins"
for p in core engineering design production; do
	CLAUDE_PLUGIN_ROOT="$root/plugins/$p" bash "$root/plugins/$p/hooks/register.sh" "$p"
done
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

echo "# plugin layout, register.sh, tt-path.sh"
# Registering into a fresh pointer folder (the global one was filled at the top).
RH="$T/reg-home"
for p in core engineering design production; do
	TT_PLUGINS_HOME="$RH" CLAUDE_PLUGIN_ROOT="$root/plugins/$p" expect "register.sh $p" 0 bash "$root/plugins/$p/hooks/register.sh" "$p"
	[ "$(readlink -f "$RH/$p")" = "$(readlink -f "$root/plugins/$p")" ] && ok "pointer $p reaches the plugin" || bad "pointer $p reaches the plugin" "$(readlink -f "$RH/$p")"
	cmp -s "$root/plugins/core/hooks/register.sh" "$root/plugins/$p/hooks/register.sh" && ok "register.sh in $p matches core" || bad "register.sh in $p matches core"
	grep -q "register.sh.. $p\"" "$root/plugins/$p/hooks/hooks.json" && ok "hooks.json of $p registers itself" || bad "hooks.json of $p registers itself"
	grep -q "\"name\": \"$p\"" "$root/plugins/$p/.claude-plugin/plugin.json" && ok "plugin.json names $p" || bad "plugin.json names $p"
	grep -q "\"source\": \"./plugins/$p\"" "$root/.claude-plugin/marketplace.json" && ok "marketplace lists $p" || bad "marketplace lists $p"
done
# a second run changes nothing; a pointer to somewhere else is replaced
mkdir "$T/elsewhere"
TT_PLUGINS_HOME="$RH" CLAUDE_PLUGIN_ROOT="$root/plugins/core" expect "register.sh twice" 0 bash "$root/plugins/core/hooks/register.sh" core
cmd //c rmdir "$(cygpath -w "$RH/design")" >/dev/null 2>&1 || rm -f "$RH/design"
MSYS=winsymlinks:nativestrict ln -s "$T/elsewhere" "$RH/design"
TT_PLUGINS_HOME="$RH" CLAUDE_PLUGIN_ROOT="$root/plugins/design" bash "$root/plugins/design/hooks/register.sh" design
[ "$(readlink -f "$RH/design")" = "$(readlink -f "$root/plugins/design")" ] && ok "register.sh replaces a stale pointer" || bad "register.sh replaces a stale pointer"
[ -d "$T/elsewhere" ] && ok "register.sh leaves the old target alone" || bad "register.sh leaves the old target alone"
TT_PLUGINS_HOME="$RH" expect "register.sh with no name" 0 bash "$root/plugins/core/hooks/register.sh"

TP=$(bash -c ". '$S/tt-path.sh'; tt_find tt-workflow")
[ "$(readlink -f "$TP")" = "$(readlink -f "$eng/tt-workflow")" ] && ok "tt_find reaches another plugin through the pointer" || bad "tt_find reaches another plugin through the pointer" "$TP"
TP=$(bash -c ". '$S/tt-path.sh'; tt_find tt-common")
[ "$(readlink -f "$TP")" = "$(readlink -f "$S/..")" ] && ok "tt_find finds a sibling first" || bad "tt_find finds a sibling first" "$TP"
bash -c ". '$S/tt-path.sh'; tt_find tt-nothing" >/dev/null && bad "tt_find says no for a missing skill" || ok "tt_find says no for a missing skill"
bash -c ". '$S/tt-path.sh'; tt_skills" >"$T/skills"
has "tt_skills lists core" "$T/skills" "tt-guide"
has "tt_skills lists engineering" "$T/skills" "tt-execute"
[ "$(sort "$T/skills" | uniq -d | wc -l | tr -d ' ')" = 0 ] && ok "tt_skills lists each skill once" || bad "tt_skills lists each skill once"

# core works without engineering: its guide says where the rest comes from
mkdir "$T/core-only"
(cd "$T/core-only" && TT_PLUGINS_HOME="$T/no-pointers" bash "$core/tt-guide/scripts/guide.sh" hello) >"$T/hello" 2>&1
has "core-only guide names the missing plugin" "$T/hello" "engineering, which isn't installed"
TT_PLUGINS_HOME="$T/no-pointers" expect "core-only about an engineering skill" 0 bash "$core/tt-guide/scripts/guide.sh" about tt-execute
has "core-only about says how to get it" "$T/out" "isn't installed here"

# skills linked into one folder (the Copilot CLI and Codex CLI install) find each
# other and tt-common with no pointer folder at all
FL="$T/flat-skills"; mkdir -p "$FL" "$T/flat-work"
for d in "$root"/plugins/*/skills/tt-*/; do MSYS=winsymlinks:nativestrict ln -s "${d%/}" "$FL/$(basename "$d")"; done
(cd "$T/flat-work" && TT_PLUGINS_HOME="$T/no-pointers" TT_WORKFLOW_HOME="$T/flat-wf" bash "$FL/tt-workflow-lite/scripts/lite.sh" start) >"$T/flat-lite" 2>&1
hasnt "flat: lite.sh finds workflow.sh and tt-common" "$T/flat-lite" "not found"
(cd "$T/flat-work" && TT_PLUGINS_HOME="$T/no-pointers" TT_WORKFLOW_HOME="$T/flat-wf" bash "$FL/tt-workflow/scripts/workflow.sh" start) >"$T/flat-wf.out" 2>&1
hasnt "flat: workflow.sh finds tt-common" "$T/flat-wf.out" "not found"
(cd "$T/flat-work" && TT_PLUGINS_HOME="$T/no-pointers" bash "$FL/tt-guide/scripts/guide.sh" hello) >"$T/flat-hello" 2>&1
hasnt "flat: the guide sees the engineering skills" "$T/flat-hello" "isn't installed"
TT_PLUGINS_HOME="$T/no-pointers" expect "flat: handoff.sh finds its template" 2 bash "$FL/tt-common/scripts/handoff.sh" "$T/load-bd.md" "$T/load-status.md" T99 --run "$T/run" --base-sha abc123
hasnt "flat: handoff.sh found the template" "$T/out" "is engineering installed"
# without engineering, the scripts that read its templates say so instead of dying quietly
CL="$T/core-links"; mkdir -p "$CL"; MSYS=winsymlinks:nativestrict ln -s "$core/tt-common" "$CL/tt-common"
TT_PLUGINS_HOME="$T/no-pointers" expect "no engineering: handoff.sh says so" 2 bash "$CL/tt-common/scripts/handoff.sh" "$T/load-bd.md" "$T/load-status.md" T01 --run "$T/run" --base-sha abc123
has "no engineering: handoff.sh names the plugin" "$T/out" "is engineering installed"
TT_PLUGINS_HOME="$T/no-pointers" expect "no engineering: fix-card.sh says so" 2 bash "$CL/tt-common/scripts/fix-card.sh" "$T/load-bd.md" WU1 --check 2
has "no engineering: fix-card.sh names the plugin" "$T/out" "is engineering installed"

# every skill folder's SKILL.md names itself
badname=""
for f in "$root"/plugins/*/skills/tt-*/SKILL.md; do
	d=$(basename "$(dirname "$f")")
	[ "$(sed -n 's/^name: *//p' "$f" | head -1 | tr -d '\r')" = "$d" ] || badname="$badname $d"
done
[ -z "$badname" ] && ok "every SKILL.md name matches its folder" || bad "every SKILL.md name matches its folder" "$badname"
# a skill in one plugin never reaches the shared folder by ".." (plugins are installed apart);
# the linked-into-one-folder fallback is allowed where the text says so
unrel=""
for f in $(find "$root/plugins/engineering" "$root/plugins/design" "$root/plugins/production" -name '*.md'); do
	# lines joined, so a sentence wrapped after the path still counts
	bare=$(tr '\n' ' ' <"$f" | grep -oE '\.\./tt-common.{0,90}' | grep -v 'one folder' || true)
	[ -z "$bare" ] || unrel="$unrel$f: $bare"$'\n'
done
[ -z "$unrel" ] && ok "no engineering text reaches tt-common by .." || bad "no engineering text reaches tt-common by .." "$unrel"
# core never depends on a file in an engineering skill by path
deps=$(grep -rnE '(\.\./|/)tt-(workflow|workflow-lite|familiarise|familiarisation-doc|adversarial-plan|requirements|scope|approach|technical-design|plan-signoff|tech-proposals|tech-plan|tech-plan-review|task-breakdown|task-status|execute|execute-lite|coder|lite-brief|debug|debug-doc|mr-review)/' "$root/plugins/core" --include=*.sh --include=*.tsv --include=*.txt || true)
[ -z "$deps" ] && ok "core scripts don't name engineering folders" || bad "core scripts don't name engineering folders" "$deps"

echo "# guide.sh"
GD="$core/tt-guide/scripts/guide.sh"
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

# update and migrate, against a fake toolbox clone and a fake home, without
# fetching the real toolbox repository. Claude Code's plugins are updated by
# Claude Code itself, so update only prints how and links Copilot CLI and Codex
# CLI; migrate removes the old ~/.claude/skills links.
U="$T/update-toolbox"
mkdir -p "$U/plugins/core/skills/tt-guide/scripts" "$U/plugins/core/skills/tt-common/scripts" \
	"$U/plugins/core/skills/tt-alpha" "$U/plugins/engineering/skills/tt-beta"
cp "$GD" "$U/plugins/core/skills/tt-guide/scripts/guide.sh"
cp "$S/tt-path.sh" "$U/plugins/core/skills/tt-common/scripts/tt-path.sh"
printf '| [`tt-beta`](x) | The engineering skill |\n| [`tt-alpha`](x) | A core skill |\n' >"$U/plugins/core/skills/tt-guide/toolbox.md"
git init -q "$U"
UG="$U/plugins/core/skills/tt-guide/scripts/guide.sh"
H="$T/update-home"; mkdir -p "$H/.claude/skills" "$H/.copilot/skills"
mkdir "$T/not-alpha"; MSYS=winsymlinks:nativestrict ln -s "$T/not-alpha" "$H/.copilot/skills/tt-alpha"; rmdir "$T/not-alpha"
# An old Claude Code link (from before the plugins) to an engineering skill, and a real folder.
MSYS=winsymlinks:nativestrict ln -s "$U/plugins/engineering/skills/tt-beta" "$H/.claude/skills/tt-beta"
mkdir "$H/.claude/skills/tt-guide"
env -u CLAUDE_CONFIG_DIR HOME="$H" TT_PLUGINS_HOME="$H/tt-plugins" bash "$UG" update check >"$T/update-check" 2>&1
has "update says how Claude Code updates" "$T/update-check" "/plugin marketplace update tims-ai-toolbox"
hasnt "update does not link Claude Code" "$T/update-check" "Link check ($H/.claude/skills)"
has "update checks Copilot skills" "$T/update-check" "Link check ($H/.copilot/skills):"
has "update checks Codex skills" "$T/update-check" "Link check ($H/.agents/skills):"
has "update reports a broken link" "$T/update-check" "BROKEN    tt-alpha"
has "update points at migrate" "$T/update-check" "guide.sh migrate"
has "update reports auto-update absent" "$T/update-check" "Auto-update: absent"
# auto-update state, read from settings.json and the runtime registry
au() { env -u CLAUDE_CONFIG_DIR HOME="$H" TT_PLUGINS_HOME="$H/tt-plugins" bash "$UG" update check 2>&1 | sed -n 's/^Auto-update: //p'; }
printf '{\n  "extraKnownMarketplaces": {\n    "tims-ai-toolbox": {\n      "source": { "source": "github", "repo": "x/y" }\n    }\n  }\n}\n' >"$H/.claude/settings.json"
[ "$(au)" = unset ] && ok "auto-update unset when the entry has no key" || bad "auto-update unset when the entry has no key" "$(au)"
printf '{"extraKnownMarketplaces":{"other":{"autoUpdate":true},"tims-ai-toolbox":{"source":{"a":1}}}}' >"$H/.claude/settings.json"
[ "$(au)" = unset ] && ok "another marketplace's auto-update is not ours" || bad "another marketplace's auto-update is not ours" "$(au)"
printf '{"extraKnownMarketplaces":{"tims-ai-toolbox":{"source":{"a":1},"autoUpdate":false}}}\r\n' >"$H/.claude/settings.json"
[ "$(au)" = off ] && ok "auto-update off" || bad "auto-update off" "$(au)"
printf '{\r\n  "extraKnownMarketplaces": {\r\n    "tims-ai-toolbox": { "source": { "a": 1 }, "autoUpdate": true }\r\n  }\r\n}\r\n' >"$H/.claude/settings.json"
[ "$(au)" = on ] && ok "auto-update on (CRLF settings)" || bad "auto-update on (CRLF settings)" "$(au)"
printf '{"enabledPlugins":{"core@tims-ai-toolbox":true}}' >"$H/.claude/settings.json"
[ "$(au)" = absent ] && ok "an enabled plugin alone is not the marketplace" || bad "an enabled plugin alone is not the marketplace" "$(au)"
mkdir -p "$H/.claude/plugins"; printf '{"tims-ai-toolbox":{"source":{"a":1},"autoUpdate":true}}' >"$H/.claude/plugins/known_marketplaces.json"
[ "$(au)" = on ] && ok "auto-update on in the runtime registry" || bad "auto-update on in the runtime registry" "$(au)"
rm -rf "$H/.claude/plugins" "$H/.claude/settings.json"
H2="$T/copilot-only-home"; mkdir -p "$H2"
env -u CLAUDE_CONFIG_DIR HOME="$H2" bash "$UG" update check >"$T/update-co" 2>&1
hasnt "no Claude Code block without a Claude folder" "$T/update-co" "Auto-update"
expect "update applies Copilot and Codex locations" 0 env -u CLAUDE_CONFIG_DIR HOME="$H" TT_PLUGINS_HOME="$H/tt-plugins" bash "$UG" update apply
[ "$(cd "$H/.copilot/skills/tt-beta" && pwd -P)" = "$(cd "$U/plugins/engineering/skills/tt-beta" && pwd -P)" ] && ok "update links an engineering skill for Copilot" || bad "update links an engineering skill for Copilot"
[ "$(cd "$H/.copilot/skills/tt-alpha" && pwd -P)" = "$(cd "$U/plugins/core/skills/tt-alpha" && pwd -P)" ] && ok "update repairs Copilot link" || bad "update repairs Copilot link"
[ "$(cd "$H/.agents/skills/tt-guide" && pwd -P)" = "$(cd "$U/plugins/core/skills/tt-guide" && pwd -P)" ] && ok "update creates Codex link" || bad "update creates Codex link"
[ ! -e "$H/.claude/skills/tt-alpha" ] && ok "update leaves ~/.claude/skills alone" || bad "update leaves ~/.claude/skills alone"
env -u CLAUDE_CONFIG_DIR HOME="$H" TT_PLUGINS_HOME="$H/tt-plugins" bash "$UG" migrate check >"$T/migrate" 2>&1
has "migrate check lists an old link" "$T/migrate" "LINK      $H/.claude/skills/tt-beta"
has "migrate check keeps a real folder" "$T/migrate" "KEEP      $H/.claude/skills/tt-guide"
[ -L "$H/.claude/skills/tt-beta" ] || [ -d "$H/.claude/skills/tt-beta" ] && ok "migrate check removes nothing" || bad "migrate check removes nothing"
printf '{ "hooks": { "SessionEnd": [ { "hooks": [ { "type": "command", "command": "bash old/record-session.sh" } ] } ] } }\n' >"$H/.claude/settings.json"
env -u CLAUDE_CONFIG_DIR HOME="$H" TT_PLUGINS_HOME="$H/tt-plugins" bash "$UG" migrate apply >"$T/migrate" 2>&1
has "migrate apply removes the link" "$T/migrate" "Removed   $H/.claude/skills/tt-beta"
has "migrate reports the old metrics hook" "$T/migrate" "record-session.sh"
[ ! -e "$H/.claude/skills/tt-beta" ] && [ ! -L "$H/.claude/skills/tt-beta" ] && ok "the old link is gone" || bad "the old link is gone"
[ -d "$U/plugins/engineering/skills/tt-beta" ] && ok "migrate leaves the link's target alone" || bad "migrate leaves the link's target alone"
[ -d "$H/.claude/skills/tt-guide" ] && ok "migrate leaves a real folder alone" || bad "migrate leaves a real folder alone"
expect "migrate unknown mode" 2 bash "$GD" migrate nope

echo "# connections.sh"
CS="$core/tt-connections/scripts/connections.sh"
CF="$root/tools/fixtures/connections"
# The packs, links and `claude mcp list` all stay inside the temp folder.
CN() { TT_CONNECTIONS_HOME="$T/connhome" TT_CLAUDE_BIN="$CF/fake-claude.sh" FAKE_CLAUDE_LIST="$T/mcplist" FAKE_CLAUDE_CALLS="$T/mcpcalls" bash "$CS" "$@"; }
printf 'tracker: https://tracker.example.test/mcp (HTTP) - ✓ Connected\ndesign: https://design.example.test/mcp (HTTP) - ⚠ Needs authentication\n' >"$T/mcplist"
for d in one two three; do
	mkdir -p "$T/conn/$d" && git -C "$T/conn/$d" init -q && git -C "$T/conn/$d" config user.email t@t
done
git -C "$T/conn/one" remote add origin https://example.test/team/project.git
git -C "$T/conn/two" remote add origin https://other.test/x/y.git
git -C "$T/conn/three" remote add origin https://elsewhere.test/a/b.git
expect "no packs installed: no pack" 3 CN which "$T/conn/one"
expect "install a pack" 0 CN pack install "$CF/example.pack"
expect "install a folder of packs" 0 CN pack install "$CF"
printf 'no match line\n# id\n' >"$T/bad.pack"
expect "a pack with no match line is refused" 2 CN pack install "$T/bad.pack"
printf '# match: *x*\nonly\tthree\tfields\n' >"$T/bad2.pack"
expect "a short row is refused" 2 CN pack install "$T/bad2.pack"
expect "pack matched by remote" 0 CN which "$T/conn/one"
has "which names the pack" "$T/out" "example"
expect "second pack matched by remote" 0 CN which "$T/conn/two"
has "which names the other pack" "$T/out" "other"
expect "list shows the packs" 0 CN list
has "list shows a match glob" "$T/out" "*other.test/*"
: >"$T/mcpcalls"
expect "status with gaps" 1 CN status "$T/conn/one"
has "a connected server" "$T/out" "ok             tracker"
has "a server that needs auth" "$T/out" "NEEDS AUTH     design"
has "a failing check" "$T/out" "MISSING        always-fails"
has "a passing command check" "$T/out" "ok             git-email"
has "the count line" "$T/out" "2 of 4 connected. Still to do: design always-fails."
[ "$(wc -l <"$T/mcpcalls" | tr -d ' ')" = 1 ] && ok "claude mcp list runs once per status" || bad "claude mcp list runs once per status" "$(wc -l <"$T/mcpcalls")"
expect "next gives the first gap" 0 CN next "$T/conn/one"
has "next id" "$T/out" "id=design"
has "next state" "$T/out" "state=auth"
has "next hand-off" "$T/out" "handoff=Run /mcp and sign in"
has "next remaining" "$T/out" "remaining=2"
expect "next after a skip" 0 CN next "$T/conn/one" --skip design
has "next goes on to the next gap" "$T/out" "id=always-fails"
expect "next with everything skipped" 1 CN next "$T/conn/one" --skip design,always-fails
has "nothing left" "$T/out" "nothing left to set up"
expect "check a connected server" 0 CN check tracker "$T/conn/one"
expect "check a server needing auth" 1 CN check design "$T/conn/one"
has "check says auth" "$T/out" "auth"
expect "check an unknown id" 2 CN check nope "$T/conn/one"
expect "hint: a server that needs auth" 1 CN hint design "$T/conn/one"
has "hint names the state" "$T/out" "state=auth"
has "hint explains why /mcp shows nothing" "$T/out" "No MCP servers"
has "hint gives a second terminal route" "$T/out" "Route A"
has "hint gives a restart route" "$T/out" "claude --continue"
expect "hint: a connected server" 0 CN hint tracker "$T/conn/one"
has "hint says nothing to do" "$T/out" "Nothing to do."
expect "hint: a failing command check" 1 CN hint always-fails "$T/conn/one"
has "hint shows the next step" "$T/out" "Then: Fix it by hand"
expect "hint: an unknown id" 2 CN hint nope "$T/conn/one"
expect "hint: no pack" 3 CN hint design "$T/conn/three"
expect "other project: wiki missing" 1 CN status "$T/conn/two"
has "wiki is missing" "$T/out" "MISSING        wiki"
expect "hint: an unregistered server" 1 CN hint wiki "$T/conn/two"
has "hint offers the add command" "$T/out" "claude mcp add --transport http wiki https://wiki.other.test/mcp"
printf 'wiki: https://wiki.other.test/mcp (HTTP) - ✓ Connected\n' >>"$T/mcplist"
expect "other project: all connected" 0 CN status "$T/conn/two"
has "all connected" "$T/out" "1 of 1 connected."
expect "no pack for an unrelated remote" 3 CN status "$T/conn/three"
has "says so" "$T/out" "No connection pack for this project."
(cd "$T/conn/three" && CN link example) >"$T/out" 2>&1 && ok "link a pack by hand" || bad "link a pack by hand" "$(cat "$T/out")"
expect "a linked pack applies" 1 CN status "$T/conn/three"
has "linked pack is the example" "$T/out" "Pack: example"
expect "link an unknown pack" 2 CN link nope
(cd "$T/conn/three" && CN unlink) >"$T/out" 2>&1 && ok "unlink" || bad "unlink" "$(cat "$T/out")"
expect "unlinked: back to no pack" 3 CN status "$T/conn/three"
expect "no such folder" 2 CN status "$T/conn/missing"
printf 'wiki: https://wiki.other.test/mcp (HTTP) - ✗ Failed to connect\n' >"$T/mcplist"
expect "a registered server that is down" 1 CN status "$T/conn/two"
has "down is not connected" "$T/out" "NOT CONNECTED  wiki"
expect "hint: a registered server that is down" 1 CN hint wiki "$T/conn/two"
has "hint says it is not reachable" "$T/out" "not reachable"
printf 'tracker: https://tracker.example.test/mcp (HTTP) - ✓ Connected\ndesign: https://design.example.test/mcp (HTTP) - ⚠ Needs authentication\n' >"$T/mcplist"
CNG() { TT_CONNECTIONS_HOME="$T/connhome" TT_CLAUDE_BIN="$CF/fake-claude.sh" FAKE_CLAUDE_LIST="$T/mcplist" bash "$GD" "$@"; }
expect "guide connections reports gaps" 1 CNG connections "$T/conn/one"
has "guide shows the table" "$T/out" "NEEDS AUTH     design"
expect "guide connections: no pack is fine" 0 CNG connections "$T/conn/three"
has "guide says no pack" "$T/out" "No connection pack for this project."
expect "guide connections: no such folder" 2 CNG connections "$T/conn/missing"

# pack save: a machine-wide pack written from text on stdin
mkdir -p "$T/conn/four" && git -C "$T/conn/four" init -q
git -C "$T/conn/four" remote add origin https://nowhere.test/q/r.git
mkdir -p "$T/conn/bare" && git -C "$T/conn/bare" init -q
printf '# match: *\ngit-email\tcmd\tGit email\tgit config user.email\tgit config --global user.email "<email>"\t-\n' >"$T/all.pack"
expect "no pack for an unmatched remote before the save" 3 CN which "$T/conn/four"
expect "pack save from stdin" 0 CN pack save personal <"$T/all.pack"
has "save says where" "$T/out" "saved personal.pack"
has "save adds the name line" "$T/connhome/packs/personal.pack" "# name: personal"
has "list shows the saved pack" <(CN list) "personal"
expect "a catch-all pack applies to an unmatched remote" 0 CN which "$T/conn/four"
has "which names the catch-all" "$T/out" "personal"
expect "a catch-all pack applies to a repo with no remote" 0 CN which "$T/conn/bare"
expect "a specific pack still wins over the catch-all" 0 CN which "$T/conn/one"
has "which names the specific pack" "$T/out" "example"
hasnt "the catch-all does not shadow it" "$T/out" "personal"
expect "pack save of an existing name" 4 CN pack save personal <"$T/all.pack"
expect "pack save --replace" 0 CN pack save personal --replace <"$T/all.pack"
expect "pack save: bad name" 2 CN pack save Bad/Name <"$T/all.pack"
expect "pack save: no match line" 2 CN pack save nomatch <"$T/bad.pack"
expect "pack save: short row" 2 CN pack save short <"$T/bad2.pack"
printf '# match: *\nx\tcommand\tX\ttrue\t-\t-\n' >"$T/bad3.pack"
expect "pack save: unknown kind" 2 CN pack save kind <"$T/bad3.pack"
has "pack save names the kind problem" "$T/out" "kind is not mcp or cmd"
[ ! -f "$T/connhome/packs/kind.pack" ] && ok "a refused pack is not written" || bad "a refused pack is not written"
expect "guide pack save passes stdin through" 0 CNG pack save viaguide <"$T/all.pack"
expect "guide pack list" 0 CNG pack list
has "guide pack list shows it" "$T/out" "viaguide"
expect "guide pack: unknown mode" 2 CNG pack nope

echo "# workflow-state.sh"
WS="$core/tt-common/scripts/workflow-state.sh"
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
TY="$core/tt-common/scripts/tatty.sh"
bash "$TY" quip >"$T/quip"
[ "$(wc -l <"$T/quip" | tr -d ' ')" = 1 ] && ! grep -q '^#' "$T/quip" && ok "one quip, not a comment" || bad "one quip, not a comment" "$(cat "$T/quip")"
TT_GUIDE_ASCII=1 bash "$TY" banner >"$T/banner"
has "banner is Tatty" "$T/banner" "Tatty"
grep -q '[^ -~]' "$T/banner" && bad "ASCII banner has no box characters" || ok "ASCII banner has no box characters"
expect "unknown tatty command" 2 bash "$TY" nope
TT_GUIDE_ASCII=1 bash "$TY" celebrate >"$T/celebrate"
has "celebrate is Tatty" "$T/celebrate" "Tatty"
has "celebrate has confetti" "$T/celebrate" "* . *"
grep -q '[^ -~]' "$T/celebrate" && bad "ASCII celebrate has no box characters" || ok "ASCII celebrate has no box characters"

echo "# workflow.sh"
WF="$eng/tt-workflow/scripts/workflow.sh"
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
mkdir -p "$T/wf proj/done a"
printf '# Status\n- State: Complete\n- Progress: 1 of 1 units Done\n' >"$T/wf proj/done a/Done A - Task Status.md"
wf link "$T/wf proj/done a" >/dev/null
TT_GUIDE_ASCII=1 wf start >"$T/out" 2>&1
has "a finished feature gets the party Tatty" "$T/out" "* . *"
has "and still says it is built and validated" "$T/out" "built and validated"
wf link "$T/wf proj/feature a" >/dev/null
TT_GUIDE_ASCII=1 wf start >"$T/out" 2>&1
hasnt "an unfinished feature gets the plain Tatty" "$T/out" "* . *"
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
LITE="$eng/tt-workflow-lite/scripts/lite.sh"
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
has "says to pass --entry" "$T/out" "pass --entry"
expect "a new task with --entry" 0 hf --show --entry tt-workflow-lite "$G/empty"
has "named for the folder, at Start" "$T/out" "Name: empty : Start"
has "starts the entry skill on the folder" "$T/out" 'Prompt: /tt-workflow-lite "'
expect "a new task with --entry and --prefix" 0 hf --show --entry tt-workflow --prefix Sample "$G/empty"
has "the prefix names it" "$T/out" "Name: Sample : Start"
mkdir -p "$HF/done"; sed 's/^- State: .*/- State: Complete/' "$ST" >"$HF/done/Fin - Task Status.md"
expect "nothing left to run" 2 hf --show "$HF/done"
expect "no such folder" 2 hf --show "$HF/none"
wf unlink >/dev/null; lw unlink >/dev/null

unset TT_WORKFLOW_HOME

echo "# knowledge.sh and project-context.sh"
KN="$T/knowledge-repo"; mkdir -p "$KN/docs"
(cd "$KN" && git init -q -b main && git config core.autocrlf false &&
	printf '#!/bin/sh\nexit 0\n' >build.sh &&
	printf 'build: bash build.sh\n' >AGENTS.md &&
	cat >docs/review.md <<'EOF'
---
kind: knowledge
scope: review
topics: [shell, testing]
triggers: [build, check]
load: section
---
# Review reference
Use the build script.
EOF
	git add . && git -c user.email=t@t -c user.name=t commit -qm init)
KNIDX="$T/knowledge.tsv"
expect "index marked knowledge" 0 bash "$S/knowledge.sh" index "$KN" "$KNIDX"
has "knowledge index path" "$KNIDX" "docs/review.md	review	shell;testing	build;check	section"
expect "route by topic" 0 bash "$S/knowledge.sh" get "$KNIDX" review shell
has "routed source" "$T/out" "docs/review.md	review"
expect "unmatched topic" 1 bash "$S/knowledge.sh" get "$KNIDX" review unity
expect "initialize project context" 0 bash "$S/project-context.sh" init "$KN"
expect "context is current" 0 bash "$S/project-context.sh" status "$KN"
printf 'updated\n' >>"$KN/AGENTS.md"
expect "context detects stale inputs" 1 bash "$S/project-context.sh" status "$KN"
expect "trace retrieval" 0 bash "$S/knowledge.sh" trace "$T/cache" tt-review review docs/review.md
expect "retrieval report" 0 bash "$root/tools/retrieval-report.sh" "$T/cache"
has "retrieval report skill" "$T/out" "tt-review / review"

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
roles=$(awk -F'\t' '$1 !~ /^#/ && $2 == "sub" { print $1 }' "$core/tt-common/model-roles.tsv")
used=$(grep -rhoE 'model-config\.sh get [a-z][a-z-]*' "$root"/plugins/*/skills/tt-*/ --include=*.md | awk '{ print $3 }' | sort -u)
for r in $roles; do printf '%s\n' "$used" | grep -qx "$r" && ok "role $r is used by a skill" || bad "role $r is used by a skill" "no 'model-config.sh get $r' in any skill"; done
for r in $used; do printf '%s\n' "$roles" | grep -qx "$r" && ok "skill role $r is registered" || bad "skill role $r is registered"; done
hardcoded=$(grep -rln 'model: sonnet' "$root"/plugins/*/skills/tt-*/ --include=*.md || true)
[ -z "$hardcoded" ] && ok "no skill hard-codes a model" || bad "no skill hard-codes a model" "$hardcoded"
unset TT_CONFIG_DIR

echo "# tt-event.sh"
EV="$S/tt-event.sh"
LG="$TT_EVENTS_HOME/events.jsonl"
export TT_EVENTS_HOME="$T/ev-emit"; LG="$TT_EVENTS_HOME/events.jsonl"
mkdir -p "$T/evdir"
expect "emit a stage event" 0 bash "$EV" emit plan.scope_closed --prefix Demo --folder "$T/evdir" --skill tt-adversarial-plan
has "recorded" "$T/out" "recorded: "
has "event in the ledger" "$LG" '"event":"plan.scope_closed"'
has "route defaults to full" "$LG" '"route":"full"'
has "source is skill" "$LG" '"source":"skill","skill":"tt-adversarial-plan","approx":false'
expect "the same key again" 0 bash "$EV" emit plan.scope_closed --prefix Demo --folder "$T/evdir"
has "already recorded" "$T/out" "already recorded: "
[ "$(wc -l <"$LG" | tr -d ' ')" = 1 ] && ok "no second line" || bad "no second line"
expect "a qualifier is a new key" 0 bash "$EV" emit build.unit_validated --prefix Demo --folder "$T/evdir" --qualifier WU1
has "qualifier recorded" "$LG" '"qualifier":"WU1"'
expect "a quote in the prefix" 0 bash "$EV" emit plan.signed_off --prefix 'A"B' --folder "$T/evdir"
has "quote escaped" "$LG" '"prefix":"A\"B"'
expect "unknown event" 2 bash "$EV" emit plan.nope --prefix Demo --folder "$T/evdir"
expect "missing prefix" 2 bash "$EV" emit plan.signed_off --folder "$T/evdir"
expect "bad route" 2 bash "$EV" emit plan.signed_off --prefix Demo --folder "$T/evdir" --route sideways
n=$(wc -l <"$LG" | tr -d ' ')
TT_EVENTS=off expect "off switch" 0 bash "$EV" emit plan.approach_closed --prefix Demo --folder "$T/evdir"
[ "$(wc -l <"$LG" | tr -d ' ')" = "$n" ] && ok "off writes nothing" || bad "off writes nothing"
touch "$T/blocker"
TT_EVENTS_HOME="$T/blocker/x" expect "an unusable home still exits 0" 0 bash "$EV" emit plan.approach_closed --prefix Demo --folder "$T/evdir" --source skill
bad_lines=$(awk '!/^\{"v":1,"ts":"[0-9T:Z-]+","event":"[a-z_.]+","key":".+","route":"(full|lite|debug)","prefix":".*","folder":".+","project":".+","qualifier":".*","source":"(skill|reconcile)","skill":".*","approx":(true|false)\}$/' "$LG" | wc -l | tr -d ' ')
[ "$bad_lines" = 0 ] && ok "every ledger line has the v1 shape" || bad "every ledger line has the v1 shape" "$bad_lines bad"
expect "events lists the names" 0 bash "$EV" events
has "events has build.complete" "$T/out" "build.complete"
expect "where" 0 bash "$EV" where
has "where prints the ledger" "$T/out" "events.jsonl"

echo "# tt-event.sh from status-set.sh"
export TT_EVENTS_HOME="$T/ev-set"; LG="$TT_EVENTS_HOME/events.jsonl"
mkdir -p "$T/evset"
for f in "$F"/*.md; do sed "s#REPO#$T/repo#g" "$f" >"$T/evset/$(basename "$f")"; done
EST="$T/evset/Demo - Task Status.md"
expect "a task change emits nothing" 0 bash "$S/status-set.sh" "$EST" T01 "In Progress"
[ ! -f "$LG" ] && ok "no ledger yet" || bad "no ledger yet" "$(cat "$LG")"
expect "unit Done" 0 bash "$S/status-set.sh" "$EST" WU1 Done
has "unit event" "$LG" '"event":"build.unit_validated"'
has "unit qualifier" "$LG" '"qualifier":"WU1"'
hasnt "not complete yet" "$LG" "build.complete"
has "output is unchanged" "$T/out" "WU1: "
expect "unit Done again" 0 bash "$S/status-set.sh" "$EST" WU1 Done
[ "$(wc -l <"$LG" | tr -d ' ')" = 1 ] && ok "a repeat adds nothing" || bad "a repeat adds nothing"
expect "last unit Done" 0 bash "$S/status-set.sh" "$EST" WU2 Done
has "header State Complete reported" "$T/out" "header State: Complete"
has "complete event" "$LG" '"event":"build.complete"'
has "route full" "$LG" '"route":"full"'

echo "# tt-event.sh from status-init.sh"
export TT_EVENTS_HOME="$T/ev-init"; LG="$TT_EVENTS_HOME/events.jsonl"
mkdir -p "$T/evinit"
sed "s#REPO#$T/repo#g" "$F/Demo - Task Breakdown.md" >"$T/evinit/Demo - Task Breakdown.md"
expect "status-init writes a Task Status" 0 bash "$S/status-init.sh" "$T/evinit/Demo - Task Breakdown.md" "$T/evinit/Demo - Task Status.md"
has "wrote line is unchanged" "$T/out" "all Todo"
has "breakdown event" "$LG" '"event":"breakdown.written"'

echo "# tt-event.sh reconcile"
export TT_EVENTS_HOME="$T/ev-rec"; LG="$TT_EVENTS_HOME/events.jsonl"
expect "reconcile a finished feature" 0 bash "$EV" reconcile "$T/evset"
for e in explore.focus_confirmed:no plan.requirements_closed:yes plan.whole_closed:yes plan.signed_off:yes breakdown.written:yes build.unit_validated:yes build.complete:yes; do
	name=${e%%:*}; want=${e##*:}
	if [ "$want" = yes ]; then has "reconciled $name" "$LG" "\"event\":\"$name\""; else hasnt "no $name" "$LG" "\"event\":\"$name\""; fi
done
has "reconciled rows are approximate" "$LG" '"source":"reconcile"'
has "approx flag" "$LG" '"approx":true'
n=$(wc -l <"$LG" | tr -d ' ')
expect "reconcile twice" 0 bash "$EV" reconcile "$T/evset"
[ "$(wc -l <"$LG" | tr -d ' ')" = "$n" ] && ok "second reconcile adds nothing" || bad "second reconcile adds nothing"
# a draft plan: only its Closed stages
mkdir -p "$T/evdraft"
cat >"$T/evdraft/Mini - Comprehensive Tech Plan.md" <<'EOF'
# Mini
- Status: Draft

**Stages**

| Stage | Status | Doc |
|---|---|---|
| Familiarisation | Skipped: known area | |
| Requirements | Closed | |
| Scope & Constraints | Closed (challenge skipped: small) | |
| Approach | In progress | |
EOF
export TT_EVENTS_HOME="$T/ev-draft"; LG="$TT_EVENTS_HOME/events.jsonl"
expect "reconcile a draft plan" 0 bash "$EV" reconcile "$T/evdraft"
has "closed stage" "$LG" '"event":"plan.requirements_closed"'
has "closed with a skipped challenge" "$LG" '"event":"plan.scope_closed"'
hasnt "open stage" "$LG" "plan.approach_closed"
hasnt "skipped stage" "$LG" "plan.familiarisation_closed"
hasnt "not signed off" "$LG" "plan.signed_off"
# the lite and debug routes
mkdir -p "$T/evlite/.tt/Slow - Debug"
cp "$LF/Farewell - Lite Brief.md" "$T/evlite/"; cp "$LF/Slow - debug-log.md" "$T/evlite/.tt/Slow - Debug/debug-log.md"
export TT_EVENTS_HOME="$T/ev-lite"; LG="$TT_EVENTS_HOME/events.jsonl"
expect "reconcile the lite route" 0 bash "$EV" reconcile "$T/evlite"
has "lite brief written" "$LG" '"event":"lite.brief_written"'
has "lite route" "$LG" '"route":"lite"'
has "root cause confirmed" "$LG" '"event":"debug.root_cause_confirmed"'
has "debug route" "$LG" '"route":"debug"'
# workflow.sh state reconciles, and still prints the same state
export TT_EVENTS_HOME="$T/ev-wf"; LG="$TT_EVENTS_HOME/events.jsonl"
TT_WORKFLOW_HOME="$T/wfhome" expect "workflow.sh state" 0 bash "$WF" state "$T/evset"
has "state still prints" "$T/out" "built and validated"
has "state reconciled the ledger" "$LG" '"event":"build.complete"'
unset TT_EVENTS_HOME

echo "# ids.sh gloss, anchor, linkify"
ID="$root/tools/fixtures/ids"; IDS="$S/ids.sh"
mkdir -p "$T/idsv/.obsidian" "$T/idsm"
cp "$ID"/*.md "$T/idsv/"; cp "$ID"/*.md "$T/idsm/"
IP="$T/idsv/Ids - Comprehensive Tech Plan.md"; IC="$T/idsv/Ids - Challenges.md"; IR="$T/idsv/Ids - Tech Proposals.md"
expect "gloss the plain items" 0 bash "$IDS" gloss "$IP" R1 R2 A1 S1 C1 CD1 NB1
has "gloss R1 stops at the sentence" "$T/out" "R1	Settings are kept between runs"
has "gloss R2 stops at the semicolon" "$T/out" "R2	The loader runs once at start, never twice"
has "gloss drops the proposal cite" "$T/out" "A1	Store settings in one file per profile"
has "gloss S1" "$T/out" "S1	Not a settings editor"
has "gloss CD1 is the decision cell" "$T/out" "CD1	Where settings live"
has "gloss NB1 is the item cell" "$T/out" "NB1	File name casing"
expect "gloss a wrapped item and a removed one" 0 bash "$IDS" gloss "$IP" R3 R4 R5
has "gloss keeps e.g. inside a sentence and cuts long text" "$T/out" "R3	The save path is e.g. the user data folder, whatever the platform calls it, and…"
has "gloss marks a removed item" "$T/out" "R4	(removed) Loader retries"
has "gloss strips links and bold from R5" "$T/out" "R5	The greeting is shown"
expect "gloss an undefined ID" 1 bash "$IDS" gloss "$IP" R1 R9
has "undefined ID prints a question mark" "$T/out" "R9	?"
expect "gloss expands a range" 0 bash "$IDS" gloss "$IP" R1–R3
has "range gives R2" "$T/out" "R2	The loader"
expect "gloss with no ID" 2 bash "$IDS" gloss "$IP" nothing
expect "gloss a Challenges heading beats its glance row" 0 bash "$IDS" gloss "$IC" CH1
has "CH1 is its heading title" "$T/out" "CH1	Loader may run twice on resume"
expect "gloss a proposal heading" 0 bash "$IDS" gloss "$IR" P1
has "P1 is its question" "$T/out" "P1	Where should settings be stored?"
expect "gloss --link in a vault" 0 bash "$IDS" gloss --link "$IP" R1 C1 CD1 §1
has "link to a block id" "$T/out" "[[Ids - Comprehensive Tech Plan#^r1|R1]]"
has "link to the section when there is no block id" "$T/out" "[[Ids - Comprehensive Tech Plan#Constraints|C1]]"
has "link to the table's section" "$T/out" "#Resolved Critical Decisions|CD1]]"
has "link to a step heading" "$T/out" "#§1. Settings store|§1]]"
expect "gloss --link outside a vault" 0 bash "$IDS" gloss --link "$T/idsm/Ids - Comprehensive Tech Plan.md" R1
has "relative Markdown link" "$T/out" "[R1](<Ids - Comprehensive Tech Plan.md#requirements>)"
expect "defined gives the same words" 0 bash "$IDS" defined "$IP"
has "defined excerpt is the gloss" "$T/out" "R1	8	Settings are kept between runs."
expect "anchor reports what is missing" 1 bash "$IDS" anchor "$IP"
has "missing block id" "$T/out" "MISSING	C1	27"
has "different block id" "$T/out" "MISMATCH	C2	28	^c9"
expect "anchor --fix leaves a mismatch" 1 bash "$IDS" anchor --fix "$IP"
has "fixed the missing one" "$IP" "- **C1:** Saving takes under 50 ms on the reference device. ^c1"
has "mismatch left alone" "$IP" "- **C2:** No new third-party packages. ^c9"
has "wrapped item anchored on its last line" "$IP" "must exist before the first write is attempted by any caller. ^r3"
cp "$IP" "$T/idsv/before.txt"
bash "$IDS" anchor --fix "$IP" >/dev/null 2>&1; cmp -s "$IP" "$T/idsv/before.txt" && ok "anchor --fix again changes nothing" || bad "anchor --fix again changes nothing"
printf 'x\r\n- **R1:** A thing.\r\n' >"$T/idsv/crlf.md"
bash "$IDS" anchor --fix "$T/idsv/crlf.md" >/dev/null 2>&1
[ "$(tr -cd '\015' <"$T/idsv/crlf.md" | wc -c)" = 2 ] && has "crlf file keeps its line end" "$T/idsv/crlf.md" "- **R1:** A thing. ^r1" || bad "crlf file keeps its line end"
expect "linkify the challenges" 0 bash "$IDS" linkify --def "$IP" --def "$IR" "$IC"
has "target linked" "$IC" "**Target:** [[Ids - Comprehensive Tech Plan#^r2|R2]]"
has "step linked" "$IC" "[[Ids - Comprehensive Tech Plan#§1. Settings store|§1]]"
has "table cell link has an escaped bar" "$IC" "[[Ids - Comprehensive Tech Plan#^c1\\|C1]]"
has "range left bare" "$IC" "The loader (R1–R3) is assumed once"
has "code left bare" "$IC" '`R9`'
has "fence left bare" "$IC" "R1 stays in code"
has "own heading left bare" "$IC" "### CH1 — Loader may run twice on resume"
has "own glance row left bare" "$IC" "| CH1 | R2 | Accepted |"
cp "$IC" "$T/idsv/before.txt"
bash "$IDS" linkify --def "$IP" --def "$IR" "$IC" >/dev/null 2>&1; cmp -s "$IC" "$T/idsv/before.txt" && ok "linkify again changes nothing" || bad "linkify again changes nothing"
expect "linkify proposals" 0 bash "$IDS" linkify --def "$IP" "$IR"
has "decides line linked" "$IR" "**Decides:** [[Ids - Comprehensive Tech Plan#^a1|A1]], [[Ids - Comprehensive Tech Plan#Resolved Critical Decisions|CD1]]"
expect "a linked document still cites the same IDs" 0 bash "$IDS" cited "$IR"
has "linked cite A1 still seen" "$T/out" "A1	"
has "linked cite CD1 still seen" "$T/out" "CD1	"
expect "linkify needs a definition document" 2 bash "$IDS" linkify "$IC"
expect "style inside a vault" 0 bash "$IDS" style "$IP"
has "vault style" "$T/out" "obsidian"
expect "style outside a vault" 0 bash "$IDS" style "$T/idsm/Ids - Comprehensive Tech Plan.md"
has "plain folder style" "$T/out" "md"

echo "# ids.sh index"
cp -r "$ID" "$T/idsx"
expect "index a feature folder" 0 bash "$IDS" index "$T/idsx"
has "R1 is a plan item" "$T/out" "R1	Ids - Comprehensive Tech Plan.md	8	item	Settings are kept between runs."
has "CD1 is a plan row" "$T/out" "CD1	Ids - Comprehensive Tech Plan.md	33	row	Where settings live"
has "§1 is a plan heading" "$T/out" "§1	Ids - Comprehensive Tech Plan.md	42	heading	Settings store"
has "CH1 is its heading, not its glance row" "$T/out" "CH1	Ids - Challenges.md	8	heading	Loader may run twice on resume"
has "P1 is from the proposals" "$T/out" "P1	Ids - Tech Proposals.md	3	heading	Where should settings be stored?"
has "A1 is the plan's when there is a plan" "$T/out" "A1	Ids - Comprehensive Tech Plan.md	16	item"
hasnt "the lite brief's A1 gives way" "$T/out" "A1	Ids - Lite Brief.md"
has "T01 is the lite brief's when there is no breakdown" "$T/out" "T01	Ids - Lite Brief.md	9	heading	Guard the greeting"
has "D1 is a Task Status row" "$T/out" "D1	Ids - Task Status.md	6	row	Keep the loader guard"
has "H1 is a Debug Log row" "$T/out" "H1	.tt/Ids - Debug/debug-log.md	6	row	The loader runs twice on resume"
mkdir -p "$T/idsl"; cp "$ID/Ids - Lite Brief.md" "$T/idsl/"
expect "index a lite folder" 0 bash "$IDS" index "$T/idsl"
has "lite acceptance without a colon" "$T/out" "A1	Ids - Lite Brief.md	4	item	The greeting shows once per run."
has "second acceptance item" "$T/out" "A2	Ids - Lite Brief.md	5	item	A second start shows nothing."
expect "anchor a lite brief" 1 bash "$IDS" anchor "$T/idsl/Ids - Lite Brief.md"
has "lite acceptance without a block id" "$T/out" "MISSING	A2	5"
mkdir -p "$T/idse"
expect "index an empty folder" 1 bash "$IDS" index "$T/idse"
expect "index needs a folder" 2 bash "$IDS" index "$T/idse/none"

echo "# focus-summary.sh"
FS="$eng/tt-familiarise/scripts/focus-summary.sh"; FD="$root/tools/fixtures/focus"
expect "summarise a focus log" 0 bash "$FS" "$FD/.tt/Foc - Familiarisation/focus-log.md"
has "the focus statement" "$T/out" "**Focus statement:** How a setting gets from the form to the file"
has "Focus topics, with a note after the rating" "$T/out" "**Focus topics:** Settings form; Settings store"
has "background topics" "$T/out" "**Background:** Loader"
has "parked count" "$T/out" "**Parked:** 2 topics"
has "unrated count" "$T/out" "**Not yet rated:** 1 topic"
has "a Markdown link outside a vault" "$T/out" "Full focus log: [focus log](.tt/Foc%20-%20Familiarisation/focus-log.md) ("
hasnt "no wanted change in a full log" "$T/out" "Change wanted"
expect "summarise a lite log" 0 bash "$FS" "$FD/lite-focus-log.md"
has "the wanted change" "$T/out" "**Change wanted:** \"Show the greeting only on the first start\""
has "no unrated line when none" "$T/out" "**Parked:** 0 topics"
hasnt "nothing unrated to report" "$T/out" "Not yet rated"
mkdir -p "$T/vault/.obsidian" "$T/vault/f"; cp "$FD/lite-focus-log.md" "$T/vault/f/"
expect "summarise a log in a vault" 0 bash "$FS" "$T/vault/f/lite-focus-log.md"
has "a wiki link in a vault" "$T/out" "Full focus log: [[lite-focus-log]] ("
expect "a log without a focus statement" 1 bash "$FS" "$FD/empty-log.md"
expect "no such log" 2 bash "$FS" "$FD/none.md"
expect "needs a log" 2 bash "$FS"

echo "# stories.sh"
US="$root/plugins/design/skills/tt-user-stories/scripts/stories.sh"
SF="$root/tools/fixtures/stories"
SD="$T/stories"; mkdir -p "$SD"; cp "$SF/Bag - Design.md" "$SD/"
DOC="$SD/Bag - User Stories.md"
bash "$US" init "$SF/Bag - Design.md" "$SD/stdin.md" >/dev/null
us() { bash "$US" "$@"; }
expect "init" 0 us init "$SD/Bag - Design.md" "$DOC"
has "init: title from the prefix" "$DOC" "# Bag - User Stories"
has "init: wiki link to a design doc beside it" "$DOC" "- **Source:** [[Bag - Design]]"
has "init: Drafting" "$DOC" "- **Status:** Drafting "
expect "init refuses an existing document" 2 us init "$SD/Bag - Design.md" "$DOC"
expect "group add" 0 us group add "$DOC" Inventory "Carrying | holding"
has "a pipe in a cell is escaped" "$DOC" "| Inventory | Carrying \| holding |"
expect "group add: a case-insensitive duplicate" 1 us group add "$DOC" inventory
expect "group add: no pipes in names" 1 us group add "$DOC" "a|b"
expect "group add: Ungrouped is not a group" 1 us group add "$DOC" Ungrouped
expect "add" 0 us add "$DOC" "$SF/pickup.txt"
has "add prints the ID" "$T/out" "US-01"
expect "add a second, proposed" 0 us add "$DOC" "$SF/grab.txt" --proposed
has "next ID" "$T/out" "US-02"
# the rendered story is the template, filled
sed -n '/^```$/,/^```$/p' "$root/plugins/design/skills/tt-user-stories/templates/story.md" | sed '1d;$d' |
	sed -e 's/<id>/US-01/; s/<title>/Pick up an item/; s/<group>/Inventory/; s/<status>/Accepted/; s/<origin>/Design doc/' \
		-e '/<altered>/d; s/<source>/§ Pickup/; s/<article>/a/; s/<as>/player/; s/<want>/to pick up items I walk over/; s/<so_that>/I can use them later/' \
		-e 's/<details>/Walking over an item puts it in the bag.\n\nThe design doesn'"'"'t say how many slots there are./' \
		-e 's/<criteria>/- Given a free slot, when I walk over an item, then it goes in my bag\n- Given a full bag, when I walk over an item, then it stays where it is/' >"$T/us01.want"
awk '/^### US-01:/ { p = 1 } /^### US-02:/ { exit } p' "$DOC" | awk '{ l[NR] = $0 } END { n = NR; while (n > 0 && l[n] == "") n--; for (i = 1; i <= n; i++) print l[i] }' >"$T/us01.got"
cmp -s "$T/us01.want" "$T/us01.got" && ok "the story is the template, filled" || bad "the story is the template, filled" "$(diff "$T/us01.want" "$T/us01.got" | head -5)"
has "group name follows the Groups table's case" "$DOC" "- **Group:** Inventory"
has "proposed" "$DOC" "- **Status:** Proposed"
expect "add: an article in the spec is kept" 0 us add "$DOC" "$SF/sort.txt" --proposed
has "an artist" "$DOC" "**As an** artist, **I want** to sort my bag | by rarity"
has "a balanced fence in the details is kept" "$DOC" "rarity: common < rare"
expect "check a written document" 0 us check "$DOC"
# refused specs
printf 'title: X\nas: p\nwant: w\nso_that: s\ndetails:\n  # a heading\ncriteria:\n  - c\n' >"$T/s1"
expect "spec: a details line starting with #" 1 us add "$DOC" "$T/s1"
printf 'title: X\nas: p\nwant: w\nso_that: s\ndetails:\n  ```\ncriteria:\n  - c\n' >"$T/s2"
expect "spec: an unclosed fence" 1 us add "$DOC" "$T/s2"
printf 'title: X\nas: p\nwant: w\nso_that: s\ndetails:\n  - **Status:** Accepted\ncriteria:\n  - c\n' >"$T/s3"
expect "spec: a details line like a field" 1 us add "$DOC" "$T/s3"
printf 'title: X\nas: p\nwant: **w**\nso_that: s\ncriteria:\n  - c\n' >"$T/s4"
expect "spec: ** in the story line" 1 us add "$DOC" "$T/s4"
printf 'title: X\nas: p\nwant: w\nso_that: s\ncriteria:\n' >"$T/s5"
expect "spec: no criteria" 1 us add "$DOC" "$T/s5"
printf 'title: X\n' >"$T/s6"
expect "add: required fields" 1 us add "$DOC" "$T/s6"; has "names them" "$T/out" "needs: as want so_that criteria"
printf 'title: X\nas: p\nwant: w\nso_that: s\ngroup: Nope\ncriteria:\n  - c\n' >"$T/s7"
expect "add: an unknown group" 1 us add "$DOC" "$T/s7"
printf 'title: X\ncolour: red\n' >"$T/s8"
expect "spec: an unknown key" 1 us add "$DOC" "$T/s8"
hasnt "nothing refused was written" "$DOC" "### US-04"
printf 'title: From stdin
as: p
want: w
so_that: s
criteria:
  - c
' >"$T/stdin.spec"
expect "a spec on stdin" 0 bash -c 'bash "$1" add "$2" - --proposed <"$3"' _ "$US" "$SD/stdin.md" "$T/stdin.spec"
has "the stdin spec was written" "$SD/stdin.md" "### US-01: From stdin"
# hashes and edits
h=$(us show "$DOC" US-02 --tsv | awk -F'\t' '{ print $NF }')
printf 'title: Grab items\n' >"$T/e1"
expect "edit with a stale hash" 3 us edit "$DOC" US-02 "$T/e1" --if 12345
expect "edit with the current hash" 0 us edit "$DOC" US-02 "$T/e1" --altered --if "$h"
has "edit changed the title" "$DOC" "### US-02: Grab items"
has "an alteration is counted" "$DOC" "- **Altered:** 1"
has "the rest of the story is kept" "$DOC" "**I want** to grab items from the floor"
expect "set a title" 0 us set "$DOC" US-02 title "Grab items off the floor"
has "set" "$DOC" "### US-02: Grab items off the floor"
expect "set refuses a newline" 1 us set "$DOC" US-02 title $'a\nb'
# merges, accept, reject
expect "add a merge" 0 us add "$DOC" "$SF/merge.txt" --proposed
has "merge ID" "$T/out" "US-04"
printf 'title: X\norigin: Merge of US-01, US-99\nas: p\nwant: w\nso_that: s\ncriteria:\n  - c\n' >"$T/s9"
expect "add: a merge of a story that isn't there" 1 us add "$DOC" "$T/s9"
expect "accept the merge" 0 us accept "$DOC" US-04
has "merged stories are retired" "$DOC" "| US-01 | Pick up an item | Merged into US-04 |"
has "both of them" "$DOC" "| US-02 | Grab items off the floor | Merged into US-04 |"
hasnt "and gone from Stories" "$DOC" "### US-01:"
expect "accept a retired story" 1 us accept "$DOC" US-01
has "says it is retired" "$T/out" "US-01 is retired (Merged into US-04)"
expect "reject" 0 us reject "$DOC" US-03 "Out | of scope"
has "rejected stories are retired" "$DOC" "| US-03 | Sort the bag | Rejected: Out \| of scope |"
expect "an accepted merge is still valid" 0 us check "$DOC"
expect "IDs are never reused" 0 us add "$DOC" "$SF/grab.txt"
has "next after the retired" "$T/out" "US-05"
# groups
expect "group rename" 0 us group rename "$DOC" Inventory Bag
has "rename moves the stories" "$DOC" "- **Group:** Bag"
hasnt "no story keeps the old name" "$DOC" "- **Group:** Inventory"
expect "group add" 0 us group add "$DOC" Combat
expect "set a group (any case)" 0 us set "$DOC" US-05 group combat
has "set group" "$DOC" "- **Group:** Combat"
expect "group remove --to" 0 us group remove "$DOC" Combat --to Bag
hasnt "the group is gone" "$DOC" "| Combat |"
hasnt "its stories moved" "$DOC" "- **Group:** Combat"
expect "group remove to Ungrouped" 0 us group remove "$DOC" Bag
has "stories go to Ungrouped" "$DOC" "- **Group:** Ungrouped"
expect "status" 0 us status "$DOC" Ready
has "status line" "$DOC" "- **Status:** Ready "
# list --tsv
expect "list" 0 us list "$DOC" --tsv
has "list: next ID" "$T/out" "meta	next	US-06"
has "list: escaped newlines" "$T/out" "it stays where it is	"
grep -q $'^retired\tUS-03\tSort the bag\tRejected: Out | of scope$' "$T/out" && ok "list: retired rows unescaped" || bad "list: retired rows unescaped"
# US-03 vs US-030
cp "$DOC" "$SD/many.md"
printf 'title: More\nas: p\nwant: w\nso_that: s\ncriteria:\n  - c\n' >"$T/more"
for _ in $(seq 1 26); do bash "$US" add "$SD/many.md" "$T/more" >/dev/null; done
expect "show US-30" 0 us show "$SD/many.md" US-30 --tsv
expect "US-030 is not US-03 or US-30" 1 us show "$SD/many.md" US-030 --tsv
# CRLF and hand edits
sed 's/$/\r/' "$DOC" >"$SD/crlf.md"
expect "write a CRLF document" 0 us status "$SD/crlf.md" Updated
[ "$(tr -dc '\r' <"$SD/crlf.md" | wc -c | tr -d ' ')" = "$(wc -l <"$SD/crlf.md" | tr -d ' ')" ] && ok "CRLF kept on every line" || bad "CRLF kept on every line"
expect "check a CRLF document" 0 us check "$SD/crlf.md"
sed 's/^- \*\*Status:\*\* Accepted/- **Status:** Maybe/' "$DOC" >"$SD/broken.md"
expect "check a hand-broken story" 1 us check "$SD/broken.md"; has "names the problem" "$T/out" "Status is Accepted or Proposed"
expect "a write refuses a document with problems" 1 us set "$SD/broken.md" US-04 title Z
awk '/^- \*\*Origin:\*\*/ && !d { o = $0; d = 1; next } /^- \*\*Source:\*\*/ && o != "" { print; print o; o = ""; next } { print }' "$DOC" >"$SD/order.md"
expect "check: a field out of order" 1 us check "$SD/order.md"; has "says tidy" "$T/out" "stories.sh tidy"
expect "tidy" 0 us tidy "$SD/order.md"
expect "tidy lays it out again" 0 us check "$SD/order.md"
{ cat "$DOC"; printf '\n## Notes\n\nKeep this.\n'; } >"$SD/notes.md"
expect "a section of its own is fine" 0 us check "$SD/notes.md"
expect "write with a section of its own" 0 us status "$SD/notes.md" Ready
has "the section is kept" "$SD/notes.md" "Keep this."
ls -a "$SD" | grep -qE '^\..*(lock|[0-9]+)$' && bad "no lock or temp files left" || ok "no lock or temp files left"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
