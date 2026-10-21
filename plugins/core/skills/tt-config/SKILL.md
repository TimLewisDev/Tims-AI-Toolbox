---
name: tt-config
description: >
  Choose which model and thinking effort each tt-* stage uses, see the stages
  ranked from where an expensive model pays off most to least, and save
  choices as named modes that can be swapped in one step (for example
  "recommended", "economy", "thorough", or your own). Subagent roles (the
  adversary, the coders, the auditors, the mappers) are applied at spawn time;
  stages that run in your own session (requirements, approach, technical
  design, and so on) are advisory, because only /model and /effort change the
  session. Use when the user wants to change, compare or review the models
  and effort the tt skills use, switch mode, or save a setup.
argument-hint: "[show | mode <name> | save <name> | reset <mode>]"
disable-model-invocation: true
allowed-tools: Bash, AskUserQuestion
metadata:
  version: "1.0"
---

# tt-config

All the work is in one script. Run it as

```sh
bash "<this skill's folder>/../tt-common/scripts/model-config.sh" <command>
```

(`<common>` below is that `tt-common` folder.) Its commands are `list`,
`set <role> <model> <effort>`, `modes`, `use <mode>`, `save <name>`,
`reset <mode>`, `delete <mode>` and `status`. Models are `sonnet`, `opus`,
`haiku`, `fable` or `-`; efforts are `low`, `medium`, `high`, `xhigh`, `max` or
`-`. `-` means "leave it to the session". The roles and their defaults are in
`<common>/model-roles.tsv`. Choices live in `~/.claude/tt-config/`, outside
every repo.

## How it takes effect

- **`subagent` rows** are applied by the skills: at each spawn they run
  `model-config.sh get <role>` and pass the model and effort to the Agent tool.
  A change applies from the next spawn, in any session.
- **`advisory` rows** are stages that run in the engineer's own session, which
  a skill cannot reconfigure. The setting is a recommendation: the stage
  skills tell the engineer once, in one line, if their session differs, and the
  engineer applies it with `/model` and `/effort`.

## Arguments

- **No argument or `show`:** the interactive flow below.
- **`mode <name>`:** `use <name>`, then `list`. Done.
- **`save <name>`:** `save <name>`. Done.
- **`reset <mode>`:** `reset <mode>`. Done.

## The interactive flow

1. Run `status`, then `list`. Show the table as it is (it is ordered highest
   value first: tier 1 is where a stronger model pays off most, tier 4 least)
   and add one sentence on what each tier is for: tier 1 judges and attacks
   reasoning before work builds on it, tier 2 are the gates before code is
   written, tier 3 does the volume work, tier 4 only reads and maps. Show any
   warning from `status` verbatim.
2. Ask what to do (`AskUserQuestion`, one question): **Change a stage**,
   **Switch mode**, **Save as a new mode**, **Done**.
3. **Change a stage.**
   - If the active mode is a shipped one (`modes` marks it `shipped`), say that
     shipped modes stay as they are, ask for a name for the new mode (default
     `custom`), and run `save <name>` first, so the edits go into it.
   - Ask which tier (four options, each labelled with how many of its rows
     differ from the default). Then ask which stage: three stages per question
     and a fourth option **More…** that shows the next three. Label each option
     `role — model / effort` so the current choice is visible.
   - Ask the model: **Sonnet**, **Opus**, **Haiku**, **Session default**.
     For an advisory row, say once that it only recommends.
   - Ask the effort: **Low**, **Medium**, **High**, **Other…** (xhigh, max or
     session default). Keep the current value as the first option's description.
   - Run `set <role> <model> <effort>`, then show that row from `list`.
   - Offer to change another stage; loop back to step 2 otherwise.
4. **Switch mode.** Run `modes`; ask which (modes are the options, the active
   one marked); run `use <mode>`; show `list`.
5. **Save as a new mode.** Ask for a name (lowercase letters, digits, `-`,
   `_`); run `save <name>`. If it exists, ask before using `--force`.
6. **Done.** Say which mode is active. If any advisory row differs from what
   this session is running, say which `/model` and `/effort` commands match it.

Don't edit the registry, the shipped modes or any skill file from here. To add
a mode of your own, `save` it. To drop edits to a shipped mode, `reset` it;
to remove a mode you saved, `delete` it.

## If the model alias doesn't resolve

`opus` and `sonnet` are aliases. On Bedrock or a gateway they resolve through
`ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL`; `status`
warns when an Opus role is set and the variable isn't. If a subagent on the
chosen model fails to start, the skills re-run it on the session model.
