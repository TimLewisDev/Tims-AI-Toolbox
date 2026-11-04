# Pre-written questions recorded by script, and decided outside the chat

- **Date:** 2026-11-03
- **Plugins:** core 0.5.0, engineering 0.5.0

## Why
Many steps work out a whole list of questions before asking the first one:
- an adversary's challenges after every planning stage;
- the proposals a stage or a plan review puts to the engineer;
- a lite brief's design choices and its independent check's findings;
- the open questions at the Requirements exit;
- the candidate constraints in Scope;
- a work unit's engineer checks.

The session asked each one in its own turn. After each answer it hand-edited the document (the Outcome and Resolution lines, a proposal's Status, Decision and At a glance row, `context.md`), and often applied the change on the spot. That costs one full turn and several edits per question, for a list that was fully known at the start. The questions could also only be answered in the chat.

## Added
- `tt-common/scripts/challenges.sh append | take | decide | applied | list | show | status | check`: the only writer of `<Prefix> - Challenges.md` once it exists.
  - `append` adds a set together with its At a glance rows.
  - `take` records the planner's view as `- **Take:** *Recommend <option>.* …`.
  - `decide` records the engineer's choice:
    - `accept` gives `Accepted`, with the Resolution `To apply: …` until `applied`;
    - `rebut` needs `--note`;
    - `defer` also writes the `fi-notes.md` line;
    - `dismiss` is for minor challenges only.
- `tt-common/scripts/proposals.sh add | decide | applied | supersede | ask | list | show | status | check`: the only writer of `<Prefix> - Tech Proposals.md` once it exists.
  - `add` takes part files and adds their At a glance rows.
  - `decide <A-D>` writes:
    - the Status, `Decided <date>`;
    - the `(Chosen)` marks;
    - the Decision section, with Chosen, By / when, Why and Not chosen;
    - the At a glance row;
    - `Applied: not yet`, until `applied`.
  - Other choices for `decide`:
    - `other --note` records a choice that is none of the options, to settle with the engineer;
    - `leave` keeps a Default applied proposal as it is.
  - `ask` marks a Default applied proposal as put to the engineer.
  - The options are read from the comparison table's `<letter>: <title>` columns and its In one line, Main benefit and Main risk rows.
- `tt-common/scripts/questions.sh init | add | decide | applied | list | show | status | check`: the only writer of a question list, `<feature folder>/.tt/<Prefix> - Questions/<name>.md`, for questions that have no document of their own.
  - Each question has a title, an optional ref, a context, an optional take, and two or more options.
  - An option can be the recommended one, or can need a note.
  - `tt-common/question-lists.md` is how a skill uses one.
- `tt-common/scripts/decide.sh mode | pending | status | show | set` is one way in to everything a folder is waiting on, for the skills and any front end.
  - `mode` reads `TT_DECIDE`:
    - `chat` (the default): the session asks.
    - `elsewhere`: the session records the questions and ends its turn, and the person answers outside the chat.
  - `pending --tsv` columns: `doc kind id state group severity title`.
- `tt-common/scripts/decide-lib.sh`: the lock, line-ending and BOM helpers those scripts share.

## Changed
- **Challenge resolution** (`planning-protocol.md`, `tt-adversarial-plan`):
  - Record the set by script, then write a take on every challenge in one response.
  - Put them to the engineer:
    - `chat`: one at a time, each answer recorded with `decide.sh set` in the same response as the next question;
    - `elsewhere`: end the turn.
  - Apply the accepted ones in one pass, with a single cross-check against the Ledger and each other.
- **Proposals** (`planning-protocol.md` and its new **Putting proposals to the engineer**, `planning-rules.md`, `tt-tech-proposals`, `tt-approach`, `tt-technical-design`, `tt-tech-plan-review`):
  - Every write goes through `proposals.sh`.
  - Technical Design finishes its Critical Decision hunt before asking, then puts the independent Blocking decisions together.
  - Plan review can mark Default applied proposals for review and end its turn.
- **Question lists** (`tt-lite-brief`, `tt-requirements`, `tt-scope`, `tt-execute`, `tt-execute-lite`):
  - The lite brief's design choices and brief-check findings each become a question list. A "leave it" on a finding is now recorded in the brief.
  - The Requirements exit's open questions become a list: answer / carry / drop.
  - The candidate constraints in Scope become a list: accept / reword / reject.
  - With `elsewhere`, a work unit's engineer checks become a list (passed / failed / waived, with the evidence as the note), recorded with `status-record.sh check` when the session carries on.
- **Contradiction handling:** answers to a pre-written list are cross-checked once, together, when they are applied.
- **`workflow-state.sh`:** the primary row of a draft plan, a signed-off plan, a lite exploration, a lite brief or a build adds "N challenges, N proposals and N questions wait for a decision." (or "… wait to be applied.").

## Notes
- Without `TT_DECIDE`, the chat still asks one question at a time. Only the hand edits and the apply-per-answer are gone.
- Older Challenges and Tech Proposals documents still read as they are:
  - a challenge with no Take line has no recommendation;
  - a proposal outside the template's layout is never waiting.
