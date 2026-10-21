# Template: work unit block

One per unit, in `parts/30-<WU>.md`, followed by its cards.

````markdown
## <WU ID> — <outcome-style name>

**In plain English:** <2–4 sentences: what someone can do or see once this unit is validated>

| | |
|---|---|
| **Tasks** | <IDs> |
| **Depends on** | <unit IDs, or —> |
| **Validated by** | Agent · Agent + Engineer |

**Why these tasks are validated together:** <one or two sentences: what can only be observed once all of them are done>

**Validation**
- [ ] <unit check, e.g. "the settings module compiles"> (Agent | Engineer | Agent + Engineer)
- [ ] <plan "Done when" item, verbatim> (plan §N) (Agent | Engineer | Agent + Engineer)
- [ ] <plan "Done when" item moved here from §M, verbatim> (plan §M; observable from this unit) (Agent | Engineer | Agent + Engineer)

**How to validate**

```checks
<n> | <ok | empty | nonempty> | <command, run with bash in the repo>
```

- Agent: <anything the checks block can't express: an inspection, a file to read, in order>
- Engineer (read out inline at validation time):
  1. <what to open and do> → expect <what they should see>
  2. …
````

- Every plan "Done when" item placed on this unit by the skeleton's Done-when
  map appears here **verbatim**, tagged with its plan step. Never drop one.
  "Verbatim" is the text `donewhen.sh` gives: for a sub-bullet, "<parent
  text> <child text>". `card-scaffold.sh` writes the list in this order (unit
  checks, then the map's items), so the check numbers in the `checks` block
  follow it; don't reorder it.
- Write each check so its executor can run it exactly: commands for the agent;
  for the engineer, numbered steps, each with its expected result. The
  engineer's part is read out inline at validation, so write instructions, not
  notes.
- **The `checks` block** holds one line per Validation item the agent checks
  with a command. `<n>` is the item's position in the Validation list
  (counting from 1, every item). `run-checks.sh` runs them, so each must be a
  complete command with no placeholders:
  - `ok`: passes when the command exits 0 (a build, a compile check, a test
    run, `test -f <path>`);
  - `empty`: passes when it prints nothing (a `git grep` for something that
    must be gone);
  - `nonempty`: passes when it prints something and exits 0.

  Give an **Agent + Engineer** item a line for its agent part. An Agent check
  that is an inspection rather than a command gets no line; describe it under
  "Agent:". Use the Build check from the breakdown header for compile checks.
  Leave the block out only if no Agent check is a command.
