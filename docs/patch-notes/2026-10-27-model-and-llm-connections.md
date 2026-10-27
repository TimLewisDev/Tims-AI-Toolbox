# A model for the main session, a model for every step, and LLM connections

- **Date:** 2026-10-27
- **Plugins:** core 0.2.0, engineering 0.2.0

## Why
A workflow ran on whatever model `claude` defaulted to, and a skill can't change the model of the session it runs in, so there was no way to say "start this workflow on Opus at high effort". Four subagent spawns also had no model setting at all, and a few roles covered several unrelated spawns. The model list was a fixed set of Claude aliases, with no notion of another LLM tool.

## Added
- `tt-connections/scripts/llms.sh` (`/tt-connections llms`): connects the machine's LLM tools (`claude`, `copilot`, `codex`) and generates the models each offers from the tool's own `--help`. State is in `~/.claude/tt-llms/` (`TT_LLMS_HOME`), with `models.d/<tool>.tsv` for models a tool doesn't list. Claude is always connected. Only Claude's models are `runnable`; the others are listed.
- A `session` row in `tt-config`: the model and effort a workflow is started on.
- `model-config.sh args [--model m] [--effort e]`: prints the `claude` flags (`--model … --effort …`) for those values, or for the `session` row, and nothing when they are left to the session.
- `model-config.sh list --tsv`: the table as rows, for a program to read.
- `new-session.sh --model/--effort` and `session-handoff.sh --model/--effort`: start the new session on that model and effort. Without them, the handoff uses the `session` row. `--show` adds a `Flags:` line.
- `workflow.sh start` and `lite.sh start` print the `session` setting when one is set.
- Roles `verify-step`, `plan-drift`, `status-reconcile`, `status-init` and `agent-checks`, and `model-config.sh get` lines at the spawns that had none (`tt-familiarise`'s trace, `tt-familiarisation-doc`, `tt-debug`'s loop, `tt-task-status`'s fallbacks).

## Changed
- `model-config.sh set` accepts the runnable models of the connected tools (and the efforts each takes) instead of a fixed list; without `llms.sh` it falls back to the four Claude aliases.
- The `drift-check` role is gone: its spawns now use `plan-drift`, `status-reconcile`, `status-init` and `agent-checks`, and the step verification in `tt-task-breakdown` uses `verify-step` instead of `unit-writer`. A saved mode that still names `drift-check` keeps working; the row is ignored.

## Notes
- A running session still can't be switched. The `session` row only takes effect when `claude` is launched with it (`new-session.sh`, `session-handoff.sh`, or any launcher that runs `model-config.sh args`).
- Copilot and Codex models can be seen and listed, but a subagent can only be spawned on a Claude model, so they are not yet accepted for a stage.
- The `copilot` and `codex` model lists are read from each tool's `--help` (`--model` choices). That is unverified against the real tools; add models by hand in `models.d/<tool>.tsv` if a tool lists none.
