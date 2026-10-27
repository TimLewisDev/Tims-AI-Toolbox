# Continue in a new session

A long conversation is the main cost of a long feature. At a break point the
engineer can carry on in a **fresh session**: a skill can't clear its own, but
it can start another, named and started with the command that carries on.

## When to offer

At every point where a skill stops and says "carry on in a fresh session" or
asks "continue now, or stop": a planning stage's break point, the close of an
exploration or a debugging session, a lite brief's hand-off, a finished work
unit, and the confirmation in `tt-workflow` and `tt-workflow-lite`. Add the
option **Continue in a new session** beside the others. Recommend it once the
conversation has run two or more skills or stages, or is long.

Write the state first (close the stage, set the status, save the log): the
new session reads it from disk, and the session's name is the stage it will
work on.

## What it does

Ask first, with `AskUserQuestion`, and say the name it will get. Only on a
yes, run:

```
bash "<common>/scripts/session-handoff.sh" [--entry tt-workflow|tt-workflow-lite] [--prefix "<Prefix>"] "<feature folder>"
```

(`<common>` is the `tt-common` folder beside this skill.) The script:

- names the session `<Prefix> : <Stage>` (for example `Checkout : Scope`),
  with `claude -n`, so it shows in the prompt box, `/resume` and the terminal
  title. If a session with that name is still open (the stage repeats, as with
  `Build` after each work unit), it becomes `Checkout : Build (2)`, `(3)`, and
  so on, rather than the random suffix Claude Code would add;
- opens a new terminal tab in the repo root, started with the command that
  carries on: `/tt-workflow` or `/tt-workflow-lite` (they read the folder link
  and the documents, then ask their usual one question), or, when the folder
  isn't linked, the next step's own command such as
  `/tt-adversarial-plan resume "<plan>"`.

`tt-workflow` passes `--entry tt-workflow` and `tt-workflow-lite` passes
`--entry tt-workflow-lite`. Every other skill passes no `--entry`: the script
finds out from the links. Pass `--prefix` when the folder holds several
features (the script exits `2` and lists them if you don't).
Only when the state alone can't name the step, pass `--stage "<label>" --run
"<command>"` to set both yourself (for example, writing up an exploration that
is confirmed but not yet written up).
`--show` prints the name and command and opens nothing.

Inside a JetBrains IDE terminal (Rider) on Windows, the script opens the session
as a new tab of that terminal: `rider-tab.ps1` sends the new-tab shortcut and
types the launcher command, but only while the IDE is the foreground window with
the Terminal tool window focused (it never types blindly). Otherwise it opens a
Windows Terminal tab as usual. Set `TT_SESSION_TERMINAL=wt` to always use
Windows Terminal. The new tab's shell is assumed to be PowerShell.

## After it

- Exit `0`: say the session is open and its name, then **stop**. The new
  session carries on; don't run anything else here.
- Exit `1`: no terminal could be opened. Give the engineer the command the
  script printed, then stop.
- Exit `2`: tell the engineer why (nothing left to run, or several features),
  then ask the same question again without this option, so they always have a
  way to carry on. Never end the turn on the failure alone.

A folder with no tt documents yet (a new task) can be handed off only with
`--entry`: the new session then starts `/<entry> "<folder>"`, which links the
folder and asks its first question. There is rarely a reason to: a new task has
no long conversation to shed, so `tt-workflow-lite` doesn't offer it there.

Never open a session without a yes.
