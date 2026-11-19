# Breaks answered outside the chat

Where a skill would stop and ask the engineer "Continue, or stop here?", or
"run the adversary challenge?", the engineer may answer somewhere other than the
chat: a companion app with Continue, Skip and Stop buttons. `breaks.sh mode`
says which. It prints **`chat`** (the default: ask as the skill says) or
**`elsewhere`** (the session was started with `TT_BREAK=elsewhere`).

Nothing here changes `chat` mode. In `elsewhere` mode the engineer's answer is
recorded by a script, and a skip is carried out by the script that owns it, so
the model never edits the Stages table or the stage profile to skip.

## In `elsewhere` mode

1. **Record the wait**:
   `bash "<common>/scripts/breaks.sh" wait "<folder>" --kind <kind> --step <step> --label "<words>" --prefix "<Prefix>" --skill <this skill>`.
   What comes next decides the kind:
   - `challenge`: the adversary challenge of a planning stage. `step` is the
     stage key (`explore`, `requirements`, `scope`, `approach`, `design`,
     `whole-plan`); the label reads like "the Requirements challenge".
   - `stage`: another stage of the workflow. `step` is its key from
     `stages.sh show` (`scope`, `approach`, `design`, `whole-plan`, `signoff`,
     `breakdown`, `build`, `review`); the label is its name.
   - `skill`: a skill the entry point is about to run. `step` is its name
     (`tt-task-breakdown`, ...); the label says what it will do.
2. **Say in one line what you are waiting for** ("Waiting for you in the app to
   continue or skip the Requirements challenge.") and **end your turn**. Do not
   ask in the chat and do not offer a new session.
3. **When you are next started** (by any message), run
   `bash "<common>/scripts/breaks.sh" take "<folder>"`. It prints:
   - `continue`: go on with the step as if the engineer had said Continue now.
   - `skip`: the step has already been skipped, by script (the Stages row reads
     `Closed (challenge skipped: ...)`, or the stage profile leaves it out).
     Do not do it. Go on with whatever comes next from the documents' state.
   - `stop`: say in a line where things stand, and stop.
   - `waiting`: no answer yet. If the engineer's own message plainly says
     continue, skip or stop, record it with `breaks.sh answer "<folder>" <word>`
     (a refused skip says why: tell them) and `take` again; otherwise say you
     are still waiting at the break and end your turn.
   - `none`: nothing is recorded (it was cleared, or never made): ask in the
     chat, as in `chat` mode.

## What can be skipped

`wait` works out whether the step may be skipped (`show --tsv` prints it, with
the reason when not), and `answer skip` is refused when it may not:

- Any planning stage's adversary challenge, while it is pending.
- A stage the stage profile can leave out and that has not begun: Explore,
  Scope & Constraints, Approach, Whole plan, Review (`stages.sh`).
- Never Requirements, Technical Design, Sign-off, the Task Breakdown once work
  has started, or Build.

Skipping a challenge records `Closed (challenge skipped: skipped by the
engineer)` in the Stages table and the stage's `plan.<stage>_closed` event in the
ledger, exactly as the skill does when the engineer says to skip it.

Every wait is also a `workflow.waiting` row in the event ledger
(`<common>/events.md`), so a program watching it knows the workflow has stopped.
