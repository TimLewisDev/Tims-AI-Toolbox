# Template: Debug Log

The Debug Log is the investigation's memory on disk. `tt-debug` keeps it
current after every turn; `debug-doc.sh` renders the Debug Report from it
without a model, so every section below is written in the form the report
needs. `tt-lite-brief` reads it to plan a fix. Keep it short and factual. Edit
it in place; never rewrite it whole.

The headings and table headers are fixed: `debug-doc.sh` finds sections by
heading.

Hypothesis status: `Open` · `Supported` (evidence for, not yet confirmed) ·
`Ruled out` (say why under **Against**) · `Root cause` (set only when the
engineer has confirmed it).

```markdown
# Debug Log: <the symptom, in a few words>

- **Symptom:** "<the engineer's description, verbatim>"
- **Expected:** <what should happen> · **Actual:** <what happens>
- **Reproduction:** <steps, and how often it happens>
- **Since / last good:** <when it started, or the last known good commit or state, or "unknown">
- **Folder:** `<doc folder>` · **Prefix:** <Prefix>
- **Repo:** `<absolute path of the repo the bug is in>`
- **Target:** working tree @ `<short sha>` (<clean | dirty: N files>), <YYYY-MM-DD>
- **Status:** Debugging · **Next:** <the next step, in a few words>
  (later, in place of "Debugging": `Root cause confirmed <YYYY-MM-DD>` or `Unresolved <YYYY-MM-DD>`; once the report is written, append ` · Documented <YYYY-MM-DD>: <report path>` and keep the first part. Drop this line.)

## In short
<Three to five plain-English lines: what is wrong, and why. "(draft)" until
the engineer confirms the root cause; empty while the cause is unknown.>

## Hypotheses
| ID | Hypothesis | Status | For | Against | Next test |
|---|---|---|---|---|---|
| H1 | <a candidate cause, one sentence; "(engineer's)" when it is theirs> | Open | <evidence, `path:line`> | <evidence, `path:line`> | <the experiment that would tell it apart> |

## Observations
- <a cited fact about the code or the run> (`path:line`)

## Experiments
| # | What was tried | Who | Result | Points to |
|---|---|---|---|---|
| 1 | <command, edit or check> | engineer · agent | <what was seen> | H1 supported · H2 ruled out |

## Temporary edits
Every line added for debugging carries the marker `TT-DEBUG-TEMP`.
| Path | What | Removed |
|---|---|---|

## Root cause
<The mechanism, in cited sentences: what the code does, why that produces the
symptom, and the observation that confirms it (it reproduces with the cause
present and goes away without it). Empty until confirmed.>

## Fix direction
<The engineer's words only: what they intend to change, or "none yet". Not a
design.>

## Open questions
- <what the code or the run doesn't settle, or "None">
```
