# Brief: write or regenerate a Tech Plan (as a subagent)

You render the brief Tech Plan from a signed-off Comprehensive Tech Plan, so
the calling skill doesn't have to. You add, infer and reinterpret nothing.

**You are given:** the comprehensive plan path, the mode (`Write` or
`Regenerate`), and the `tt-common` folder `<common>`.

## Do

1. Read `<common>/subagent-rules.md`.
2. Invoke the `tt-tech-plan` skill (or, if you can't, read its `SKILL.md` in
   the folder above this `briefs/` folder) and follow it in the given mode,
   with the comprehensive plan's path as its argument.
3. Where the skill says to ask or tell the engineer something (the plan isn't
   signed off, something seems missing or wrong in the plan), don't: return it
   as an escalation of type `question` and carry on with the rest where you
   can.

## Return

The RESULT block: `wrote` the Tech Plan path; a summary with the revision it
mirrors and its line count; escalations for anything the plan seemed to be
missing; and `findings` from the `ids.sh xref` check (`none` if clean).
