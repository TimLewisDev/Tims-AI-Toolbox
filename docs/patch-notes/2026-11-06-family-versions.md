# Choose the version an alias means (Sonnet 5.5 by default)

- **Date:** 2026-11-06
- **Plugins:** core 0.7.0

## Why
A subagent is started with an alias (`sonnet`), which the Agent tool can't give a version. The alias means whatever `ANTHROPIC_DEFAULT_<FAMILY>_MODEL` says in the environment of the session that spawns it, and Claude Code falls back to an older model when nothing sets it: Sonnet 4.5 and Haiku 4.5 on Bedrock. A session started by a launcher that is not itself a Claude session (Tatty) has no such variable, so its subagents ran on Sonnet 4.5 while the main session ran on Opus 5.5.

## Added
- `model-config.sh family list [--tsv]`, `family set <family> <id|->`, `family env`: which version each alias means (`chosen`, `own` or `newest`), pinning one, and the `NAME=value` lines a launcher exports. An unpinned alias follows the newest row of `claude-models.tsv` for the backend in use, unless your own environment or `settings.json` already sets it. The choice is machine-wide, in `~/.claude/tt-config/family-versions.tsv`, not part of a mode.
- `llms.sh versions [<family>] [--tsv]`: the specific versions by family, newest first, with the Bedrock ids on Bedrock.
- `/tt-config` and the guide explain it.

## Notes
- A launcher has to export `family env` when it starts `claude`; the toolbox's own `new-session.sh` and `session-handoff.sh` run from inside a Claude session, which already carries the variable, and are unchanged.
- A pinned id the backend doesn't list (for example after switching between Bedrock and first-party) is ignored until it is pinned again.
- Sessions already running keep the version they started with.

## 0.7.1
- `model-config.sh family` and `llms.sh versions` do their work in one awk pass over the files' contents instead of a dozen forks: `family env` went from about 6 seconds to about 1.5 on Windows, where each process costs about 0.1s. A launcher asks for it at every start.
- `family list --tsv` has a sixth column, the versions of the family (`id=label;id=label`, newest first), so a launcher needs no second call.
