# Requirements

[Back to the README](../README.md)

- **Claude Code features:** the skills call each other through the Skill tool,
  ask questions with `AskUserQuestion`, and spawn subagents with the Agent tool
  (with a model and effort per role from `tt-config`). Other agents (GitHub
  Copilot CLI, Codex CLI) may need equivalents, or do the subagents' work
  themselves.
- **bash and git** for the scripts (Git Bash on Windows). No other runtime.
- **Git access to this repository,** for the Claude Code marketplace and for
  cloning it for Copilot CLI or Codex CLI.
- **A Sonnet model your provider serves.** The `sonnet` alias resolves through
  `ANTHROPIC_DEFAULT_SONNET_MODEL`; on Bedrock or a gateway, set it to a model
  ID your account accepts if the default doesn't. If a Sonnet subagent fails
  to start, the skills fall back to the default model.
- **A git repo with a base branch:** facts are checked on `origin/<base>`
  after a `git fetch`, not in the working tree.
- **Agent instructions in the repo** (`AGENTS.md`, `CLAUDE.md` or equivalent)
  for build checks and tool-managed files. Without them, the skills ask you.
- **For `tt-connections`:** a connection pack for your project (optional; without
  one the skill has nothing to check) and the `claude` CLI for MCP setup.
- **For `tt-mr-review`:** GitLab, with `glab` or a GitLab MCP server. An
  issue-tracker integration is optional and used to read the linked issue.
- **Optional, for the token log (Claude Code):** nothing to install;
  `/tt-metrics on` turns on the `SessionEnd` hook that the `core` plugin already
  ships.
