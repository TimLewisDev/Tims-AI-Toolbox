# Tims AI Toolbox

Skills for planning and building a feature with an AI coding agent while the
engineer keeps control: every consequential decision is theirs, every plan
change is confirmed, and git is never touched. A separate skill reviews GitLab
merge requests.

The toolbox is a set of Claude Code plugins, split by discipline so each person
installs only what they use. Each skill is a `SKILL.md` file in its own folder,
written for Claude Code and usable with other agents that read the same format
(Codex, GitHub Copilot). They are instructions and document templates, plus
small bash scripts that do the routine copying and checking.

## Quick start (Claude Code)

1. **Add the marketplace**, in Claude Code:

   ```
   /plugin marketplace add TimLewisDev/Tims-AI-Toolbox
   ```

2. **Install the plugins for your discipline** (see the table below). Every
   discipline installs `core`; installing a discipline plugin brings `core`
   with it.

   ```
   /plugin install core@tims-ai-toolbox
   /plugin install engineering@tims-ai-toolbox
   ```

3. **Restart Claude Code** (or run `/reload-plugins`) and type `/tt-guide` to
   meet Tatty, the toolbox's guide.

Update from inside Claude Code with `/plugin marketplace update tims-ai-toolbox`
and `/plugin update`, or turn on auto-update for the marketplace in `/plugin`.

## Which plugins to install

| You are | Install | What you get |
|---|---|---|
| An engineer | `core` + `engineering` | Everything below: explore, plan, break down, build, debug, review MRs. |
| A designer | `core` + `design` | The shared base. `design` has no skills yet; it is the place to build them. |
| A producer | `core` + `production` | The shared base. `production` has no skills yet; it is the place to build them. |
| Anyone | `core` alone | Tatty (`tt-guide`), `tt-config` (models and effort), `tt-connections` (MCP servers and logins), `tt-metrics` (token log). |

You can install any combination. The plugins find each other through a pointer
folder, `~/.claude/tt-plugins/`, that a `SessionStart` hook in each plugin keeps
up to date, so `engineering` needs `core` installed and a restarted session.

## The skills

The catalogue, how the skills fit together, the ideas behind them and a
reference for each skill are in
[`plugins/core/skills/tt-guide/toolbox.md`](plugins/core/skills/tt-guide/toolbox.md).
Or ask Tatty: `/tt-guide about <skill or topic>`.

## Setting up a team

To have everyone offered the toolbox when they open a project, commit this to
the project's `.claude/settings.json`; people then install the plugins they
need with `/plugin install`:

```json
{
  "extraKnownMarketplaces": {
    "tims-ai-toolbox": { "source": { "source": "github", "repo": "TimLewisDev/Tims-AI-Toolbox" } }
  },
  "enabledPlugins": {
    "core@tims-ai-toolbox": true,
    "engineering@tims-ai-toolbox": true
  }
}
```

## Coming from the old install

Before the plugins, the skills were linked one by one into `~/.claude/skills`
by `initial-setup`. Those links load every skill a second time next to the
plugins, and the metrics hook in `settings.json` would log each session twice.
After installing the plugins, ask Tatty to clean up:

```
/tt-guide migrate
```

It lists the old `tt-*` links and the old hook entry, and removes the links only
after you say yes. Nothing else of yours is touched: connection packs, modes,
feature links and the token log all live outside the skills and carry over.

## GitHub Copilot CLI and Codex CLI

Those clients have no plugin install from this repo yet, so they keep the
older route: clone the repo and link the skills into their personal skill
folders. Windows: double-click `link-copilot-codex.cmd`. macOS / Linux: run
`./link-copilot-codex.sh`. It shows what it will pull and link, asks before
changing anything, and is safe to run again; `/tt-guide update` does the same
later. The skill folders are `plugins/*/skills/tt-*`, and the skills find
`tt-common` in the folder they are linked into.

The personal skill locations are:

- GitHub Copilot CLI: `~/.copilot/skills/<skill-name>/SKILL.md` or
  `~/.agents/skills/<skill-name>/SKILL.md`
- Codex CLI: `~/.agents/skills/<skill-name>/SKILL.md`

These follow the [Copilot CLI skill documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
and [Codex skill documentation](https://developers.openai.com/codex/skills).

## Requirements

- **Claude Code features:** the skills call each other through the Skill tool,
  ask questions with `AskUserQuestion`, and spawn subagents with the Agent tool
  (with a model and effort per role from `tt-config`). Other agents may need
  equivalents, or do the subagents' work themselves.
- **bash and git** for the scripts (Git Bash on Windows). No other runtime.
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
- **Optional, for the token log:** nothing to install; `/tt-metrics on` turns on
  the `SessionEnd` hook that `core` already ships.

## Working on the toolbox

```
.claude-plugin/marketplace.json     the marketplace: lists the four plugins
plugins/core/                       core: tt-guide, tt-config, tt-connections, tt-metrics, tt-common
plugins/engineering/                engineering: the planning, build, debug and review skills
plugins/design/, plugins/production/   placeholders, ready for skills
tools/                              the script tests and their fixtures (not shipped)
docs/                               patch notes and the script-workflow summary
```

Try your changes without installing anything, from the repo root:

```sh
claude --plugin-dir plugins/core --plugin-dir plugins/engineering
```

Validate the manifests with `claude plugin validate .` (and each `plugins/*`).
Bump `version` in a plugin's `.claude-plugin/plugin.json` when you release it,
or installed copies won't update.

Rules for skills that live in different plugins:

- Never reach another plugin's files with `..`: plugins are installed in separate
  folders. Reach `tt-common` through `~/.claude/tt-plugins/core/skills/tt-common`
  in skill text, and with `tt-common/scripts/tt-path.sh` (`tt_find <skill>`) in
  scripts, which also finds skills linked into one folder.
- Every plugin ships an identical `hooks/register.sh`, run at `SessionStart`
  with its own name. The test script checks the copies match.

### Testing the scripts

[`tools/test-scripts.sh`](tools/test-scripts.sh) runs the breakdown,
execute and status scripts against the fixtures in `tools/fixtures/`
(`demo/`: a plan, a breakdown and a Task Status; `demo-draft/`: a skeleton;
`lite/`: a Lite Brief and a Debug Log) in
a throwaway git repo, including a CRLF copy, and checks the plugin layout:

```sh
bash tools/test-scripts.sh
```

Selective knowledge retrieval is traced in each project's machine-local
`retrieval.log`. Summarise one project with
`bash tools/retrieval-report.sh ~/.claude/tt-projects/<project-key>` or all
cached projects with `bash tools/retrieval-report.sh --all ~/.claude/tt-projects`.

## License

[MIT](LICENSE).
