#!/usr/bin/env bash
# lite.sh: the folder link and stage reader for tt-workflow-lite. It is
# tt-workflow's workflow.sh with its own links file, so a small lite task never
# replaces the link to a larger feature kept by tt-workflow. Same commands:
# start, state, link, unlink, new (-h for more). An empty folder suggests a new
# lite task here, not tt-adversarial-plan.
set -u
here=$(readlink -f "$(dirname "$0")" 2>/dev/null) || here=$(cd -P "$(dirname "$0")" && pwd -P)
wf="$(dirname "$(dirname "$here")")/tt-workflow/scripts/workflow.sh"
[ -f "$wf" ] || { echo "lite.sh: tt-workflow is not installed beside tt-workflow-lite ($wf)" >&2; exit 2; }
export TT_WORKFLOW_LINKS=lite-links.tsv
out=$(bash "$wf" "$@"); rc=$?
[ -z "$out" ] || printf '%s\n' "$out" | sed 's|^  → /tt-adversarial-plan <idea, spec or ticket>$|  → a new task: is it a bug or a feature?|'
exit $rc
