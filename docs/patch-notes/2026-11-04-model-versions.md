# Pick a specific model version for the main session

- **Date:** 2026-11-04
- **Plugins:** core 0.6.0

## Why
The model list held only the four Claude aliases, so a session could be started on "sonnet" but not on Sonnet 5, or Sonnet 4.5. An alias follows the latest model, and where Claude Code is set up differently (Bedrock, `ANTHROPIC_DEFAULT_<ALIAS>_MODEL`) it can resolve to an older one; the haiku alias runs Haiku 4.5 on one Bedrock setup.

## Added
- `tt-connections/claude-models.tsv`: the specific Claude versions, kept by hand (family, label, first-party id, Bedrock id). Every id in it was run once with `claude --model`.
- `llms.sh models --tsv` has a sixth column, the scope: `any` for an alias, `session` for a specific version. `models.d/<tool>.tsv` takes an optional fifth column `session`.
- Subagent RESULT blocks have a `model:` line, and `orchestration.md` tells the orchestrator to compare it with the model asked for and to tell the engineer when they differ, when a spawn went without a model it should have had, or when it fell back to the session's model.

## Changed
- `model-config.sh set session <version>` and `args --model <version>` accept a specific version, e.g. `claude-sonnet-5-5`. Every other role still takes the aliases only and says why: the Agent tool, which runs a subagent, takes no specific version.
- `llms.sh` picks the Bedrock ids when `CLAUDE_CODE_USE_BEDROCK` is `1` in the environment (or, when it is not set, in `~/.claude/settings.json`).
- A `models.tsv` cache from before this change is generated again on the next `llms.sh` call; no manual refresh is needed.

## Notes
- The ids need maintaining as models ship or retire (Sonnet 4.5 retires on 2026-11-30). Edit `claude-models.tsv`, or add rows to `~/.claude/tt-llms/models.d/claude.tsv` with a fifth column `session`.
- Tools that read `models --tsv` with five columns keep working; they see the extra column or ignore it.
