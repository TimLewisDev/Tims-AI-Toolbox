# Tims AI Toolbox

Skills for planning and building a feature with an AI coding agent while the
engineer keeps control: every consequential decision is theirs, every plan
change is confirmed, and git is never touched. A separate skill reviews GitLab
merge requests.

Each skill is a `SKILL.md` file in its own folder, written for Claude Code and
usable with other agents that read the same format (Codex, GitHub Copilot).
They are instructions and document templates, plus small bash scripts that do
the routine copying and checking. In Claude Code the toolbox is a set of
plugins, split by discipline so each person installs only what they use.

## Contents

- **Install**
  - [Claude Code](docs/install-claude-code.md): the marketplace and plugins, which to install for your role, updating, team setup, moving from the old install.
  - [GitHub Copilot CLI](docs/install-copilot-cli.md): clone and link the skills.
  - [Codex CLI](docs/install-codex-cli.md): clone and link the skills.
- **Use**
  - [The skills](plugins/core/skills/tt-guide/toolbox.md): the catalogue, how the skills fit together, and a reference for each. Or ask Tatty: `/tt-guide about <skill or topic>`.
  - [Requirements](docs/requirements.md): what the skills need from your tools, models and repo.
- **Contribute**
  - [Working on the toolbox](docs/contributing.md): layout, trying changes, rules across plugins, releasing, tests.
  - [Patch notes](docs/patch-notes/): what changed and why.
- [License](LICENSE)

## Quick start

In Claude Code:

```
/plugin marketplace add TimLewisDev/Tims-AI-Toolbox
/plugin install core@tims-ai-toolbox
/plugin install engineering@tims-ai-toolbox
```

Restart Claude Code (or run `/reload-plugins`), then type `/tt-guide` to meet
Tatty, the toolbox's guide. A producer or designer installs `production` or
`design` instead of `engineering`.

| Client | How | Split by discipline |
|---|---|---|
| [Claude Code](docs/install-claude-code.md) | `/plugin install` from the marketplace | Yes: `core` plus the plugins you need |
| [GitHub Copilot CLI](docs/install-copilot-cli.md) | clone, then run `link-copilot-codex` | No: all skills |
| [Codex CLI](docs/install-codex-cli.md) | clone, then run `link-copilot-codex` | No: all skills |

## License

[MIT](LICENSE).
