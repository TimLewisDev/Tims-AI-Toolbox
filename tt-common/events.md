# Stage-completion events

The tt skills record each finished stage or gate as one line in a ledger, so
another program (a companion app that awards experience, say) can follow a
feature's progress without reading the documents. This file is the contract:
what is written, when, and the rules a reader should follow.

Events are **facts, not rewards**. A line says that a stage finished; it never
says what that is worth. Experience values, levels and rewards belong to the
reader, so they can change without touching a skill.

## The ledger

`${TT_EVENTS_HOME:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/tt-events}/events.jsonl`
(`TT_EVENTS_LOG` overrides the file). `bash tt-common/scripts/tt-event.sh where`
prints the path.

- Append-only, UTF-8, one JSON object per line, never rewritten or reordered.
  A correction would be a new event, not an edit.
- Written by `tt-common/scripts/tt-event.sh`, silently and best-effort: a
  failure to write never stops a skill. `TT_EVENTS=off` turns writing off.

## A line (schema version 1)

```json
{"v":1,"ts":"2026-10-16T14:03:22Z","event":"plan.scope_closed","key":"P:/work/app|Checkout|plan.scope_closed","route":"full","prefix":"Checkout","folder":"P:/vault/Checkout","project":"P:/work/app","qualifier":"","source":"skill","skill":"tt-adversarial-plan","approx":false}
```

| Field | Meaning |
|---|---|
| `v` | Schema version. Always `1` for now. |
| `ts` | UTC time, ISO 8601. For `"approx":true` it is when the event was noticed, not when it happened. |
| `event` | The event name from the catalog below. |
| `key` | `project|prefix|event` plus `|qualifier` when there is one. **Unique in the file.** |
| `route` | `full`, `lite` or `debug`. |
| `prefix` | The feature's name (the `<Prefix> - …` of its documents). |
| `folder` | The feature folder, absolute, forward slashes. |
| `project` | The git root the skills ran in (or the working folder if none). |
| `qualifier` | Set only where an event repeats within a feature: the work unit, e.g. `WU3`. Otherwise empty. |
| `source` | `skill` (recorded as it happened) or `reconcile` (found later in the documents). |
| `skill` | The skill that recorded it; empty for `reconcile`. |
| `approx` | `true` for reconcile rows. |

## Catalog

| Event | Route | Meaning | Recorded by |
|---|---|---|---|
| `explore.focus_confirmed` | full, lite | The engineer confirmed what they care about in an exploration | `tt-familiarise` |
| `explore.documented` | full | The Familiarisation doc was written | `tt-familiarisation-doc` |
| `plan.familiarisation_closed` | full | The Familiarisation stage was challenged and closed | `tt-adversarial-plan` |
| `plan.requirements_closed` | full | Requirements stage closed | `tt-adversarial-plan` |
| `plan.scope_closed` | full | Scope and constraints stage closed | `tt-adversarial-plan` |
| `plan.approach_closed` | full | Approach stage closed | `tt-adversarial-plan` |
| `plan.design_closed` | full | Technical design stage closed | `tt-adversarial-plan` |
| `plan.whole_closed` | full | The whole-plan challenge closed | `tt-adversarial-plan` |
| `plan.signed_off` | full | The engineer signed off the plan | `tt-plan-signoff` |
| `breakdown.written` | full | The task breakdown was written and its Task Status created | `status-init.sh` |
| `lite.brief_written` | lite | The Lite Brief was written and checked | `tt-lite-brief` |
| `build.unit_validated` | full, lite | A work unit was validated (`qualifier` is its ID) | `status-set.sh` |
| `build.complete` | full, lite | Every work unit is done | `status-set.sh` |
| `debug.root_cause_confirmed` | debug | The engineer confirmed the root cause | `tt-debug` |
| `debug.report_written` | debug | The Debug Report was written | `tt-debug-doc` |

Not events: skipped stages, a stage reopening, individual tasks, plan
amendments, MR reviews.

## One event per key

A stage that reopens after a contradiction and closes again, a skill run twice,
a session resumed, and the backfill all produce the same `key`, and the writer
skips a key it has already recorded. A feature therefore yields each event at
most once. Moving or renaming a feature folder changes the `key`; a reader that
must not double-count should also de-duplicate on `prefix` + `event` +
`qualifier`.

## Backfill

Whenever `tt-workflow` or `tt-workflow-lite` reads a folder's state, it runs
`tt-event.sh reconcile`, which records every event the documents prove that is
missing from the ledger, with `"source":"reconcile","approx":true`. It catches
stages finished by hand, or by a skill run outside the workflow entry. A signed-off plan
no longer has its Stages table, so reconcile records every `plan.*_closed` event for it.
Deleting the ledger therefore rebuilds it (approximately) from the documents.

## For a reader

- Tail or watch the file; remember a byte offset or the last `key` seen.
- De-duplicate on `key`.
- Ignore event names and fields you don't know. New events and fields are added
  freely; an existing name or field is never renamed or removed without a new `v`.
- Treat `approx` rows as "this happened some time before `ts`".
- Never write to the ledger.

## Adding an event

Add the name to `EVENTS` in `scripts/tt-event.sh`, a row to the table above, and
the emit line where the skill (or script) writes the closing state: after the
state is on disk, never before. Prefer a script that already writes the state
(as `status-set.sh` and `status-init.sh` do) to a line in a skill's prose. If
the documents can prove it later, teach `reconcile` too, and add tests to
`tools/test-scripts.sh`.
