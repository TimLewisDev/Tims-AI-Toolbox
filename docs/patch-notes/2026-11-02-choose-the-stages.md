# Choose which stages a feature's workflow includes

- **Date:** 2026-11-02
- **Plugins:** core 0.4.0, engineering 0.4.0

## Why
Every full-pipeline feature ran every planning stage, and the only ways to do less were the separate lite route or answering "skip" to Familiarisation. A small piece of work that still deserved a signed-off plan could not drop the Scope & Constraints, Approach or Whole plan stages, and a folder had no way to say up front that it was a small change or that it needed no review.

## Added
- `tt-common/scripts/stages.sh show [--tsv] | set | check <folder>`: keeps a per-folder stage profile in `<folder>/.tt/workflow-stages.tsv` (one `<stage><TAB>off` line per stage left out; no file means every stage is included) and is its only writer. Stages: `explore`, `plan`, `requirements`, `scope`, `approach`, `design`, `whole-plan`, `signoff`, `breakdown`, `build`, `review`.
  - Can be left out: `explore`, `scope`, `approach`, `whole-plan`, `review`, and `plan` (which also leaves out `breakdown`: a Lite Brief replaces both, the lite route).
  - Always included: `requirements`, `design`, `signoff`, `build`.
  - A stage is locked once its work has begun; `set` refuses it, or an invalid change, with the reason on stderr and exit 1.
  - On a draft plan, `set` also flips that stage's row in the Stages table between `Not started` and `Skipped: not selected`, keeping CRLF line endings.
- A `Left-out stages` rule in `planning-protocol.md`: Setup reads the profile, marks the rows `Skipped: not selected` and writes `_Left out: this stage was not selected._` under the ledger headings those stages would have filled.
- `workflow.sh state` (full entry) points a new folder whose profile leaves out Plan at `/tt-workflow-lite`.

## Changed
- `workflow-state.sh`: the open planning stage no longer names a row whose Status is `Skipped: <reason>` or `Closed (challenge skipped: <reason>)`; both count as done. With `review` left out there is no `tt-branch-review` offer once the build is complete.
- `tt-event.sh reconcile`: for a signed-off plan, `plan.scope_closed`, `plan.approach_closed` and `plan.whole_closed` are no longer recorded for stages the profile left out.
- `tt-adversarial-plan`: passes over `Skipped` rows in its loop, goes to sign-off when Whole plan is skipped, and does not ask whether to explore first when Familiarisation is left out.
- `tt-plan-signoff` accepts `Skipped: not selected` for Scope & Constraints, Approach and Whole plan; `tt-technical-design` records the base branch Constraint (`C1`) when Scope is left out and treats the design choices as Critical Decisions when Approach is left out; the plan audit, coverage audit and `tt-tech-plan` treat a `_Left out_` section as having nothing to check.

## Notes
- A folder without a profile behaves exactly as before.
- The bug route is not affected.
- Turning off a stage that has begun is refused. A stage left out can be turned back on while the plan is still a draft; the loop then comes back to it.
