# Provider-qualified models and provider actions

- **Date:** 2026-11-20
- **Plugins:** core 0.11.0

## Why
A companion app (Tatty) can show every LLM tool the toolbox knows and let a person pick a model from any of them. For that a model must say which tool it belongs to, the toolbox must say what it supports, and an old toolbox must be recognised as old rather than guessed at. This is the toolbox's half of the contract written up in Tatty's `docs/toolbox-contract.md`.

## Added
- `llms.sh capabilities [--tsv]` prints the versioned features: `provider-model-config-v1` and `provider-actions-v1`. A program that needs them checks for the exact tokens; without them it treats the toolbox as too old.
- `llms.sh status --tsv` gains a last column: the actions each provider supports now (`install`, `sign-in`, `connect`, `disconnect`, `refresh`, comma separated, `-` for none). Claude is never offered Disconnect: it runs the skills.
- `model-config.sh` works in `provider:model-id` choices (`claude:sonnet`). `set` and `args` accept only a model the runnable catalog has (a bare id is taken when exactly one model has it, and saved qualified), and there is no built-in list of models any more: with no catalog they refuse. `list --tsv` prints qualified models.
- `get`, `args`, `stage-note` and `family env` give Claude's own id (`sonnet`, `claude-sonnet-5-5`) and refuse a choice of another provider.
- Saved bare values are read as qualified when exactly one catalog model has them. One that matches none, or several, is shown as unresolved (`list`), `get`, `args` and `stage-note` ask for a new choice, and `save` will not copy it.
- `family set <family> claude:<id>` keeps the qualified pin (a bare id is still taken as Claude's); `family list --tsv` shows qualified ids and a last column, `ok` or `unavailable`. While Claude's command is missing a pin is kept, `family set` is refused and `family env` stops with a message.

## Changed
- The shipped `session` role is `claude:sonnet` (it was `-`), so a workflow started with no choice runs on Sonnet. Shipped roles and modes are written as `claude:<alias>`.
- `get <role>` is unchanged for the skills: it still prints `model=<alias> effort=<e>`.

## Notes
- Values saved before this need nothing from the person while exactly one catalog model has them.
- Only Claude's models can run a skill; Copilot's and Codex's are listed, disabled.
