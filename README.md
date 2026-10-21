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

## Install

Pick your client. Claude Code installs the toolbox as plugins. GitHub Copilot
CLI and Codex CLI install it by linking the skill folders from a clone, and get
every skill.

| Client | How | Split by discipline |
|---|---|---|
| [Claude Code](#claude-code) | `/plugin install` from the marketplace | Yes: `core` plus the plugins you need |
| [GitHub Copilot CLI](#github-copilot-cli) | clone, then run `link-copilot-codex` | No: all skills |
| [Codex CLI](#codex-cli) | clone, then run `link-copilot-codex` | No: all skills |

The skills are written for Claude Code. They call each other through the Skill
tool, ask questions with `AskUserQuestion` and spawn subagents with the Agent
tool, so another client needs equivalents or does that work itself (see
[Requirements](#requirements)). All of them need bash and git; on Windows that
is Git for Windows (Git Bash).

### Claude Code

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
   meet Tatty, the toolbox's guide. Each plugin's `SessionStart` hook runs at
   session start, so a plugin installed mid-session isn't fully wired up until
   then.

Plugin skills also answer to their full name, `/<plugin>:<skill>` (for example
`/core:tt-guide` or `/engineering:tt-workflow`). Use it if a bare `/tt-guide`
is ambiguous because another skill has the same name.

Claude Code clones the marketplace with your own git credentials, so you need
`git` access to this repository.

**Which plugins to install**

| You are | Install | What you get |
|---|---|---|
| An engineer | `core` + `engineering` | Everything: explore, plan, break down, build, debug, review MRs. |
| A designer | `core` + `design` | The shared base. `design` has no skills yet; it is the place to build them. |
| A producer | `core` + `production` | The shared base. `production` has no skills yet; it is the place to build them. |
| Anyone | `core` alone | Tatty (`tt-guide`), `tt-config` (models and effort), `tt-connections` (MCP servers and logins), `tt-metrics` (token log). |

You can install any combination. The plugins find each other through a pointer
folder, `~/.claude/tt-plugins/`, that a `SessionStart` hook in each plugin keeps
up to date, so `engineering` needs `core` installed and a restarted session.

**Updating.** From inside Claude Code:

```
/plugin marketplace update tims-ai-toolbox
/plugin update core@tims-ai-toolbox
/plugin update engineering@tims-ai-toolbox
```

then `/reload-plugins`, or turn on auto-update for the marketplace in `/plugin`.
A plugin only updates when its `version` in `.claude-plugin/plugin.json` has
been bumped.

**Setting up a team.** To have everyone offered the toolbox when they open a
project, commit this to the project's `.claude/settings.json`; people then
install the plugins they need with `/plugin install`:

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

**Coming from the old install.** Before the plugins, the skills were linked one
by one into `~/.claude/skills` by the old `initial-setup` script. Those links
load every skill a second time next to the plugins, and the metrics hook in
`settings.json` would log each session twice. After installing the plugins, ask
Tatty to clean up. Use the full name, because the old `tt-guide` link doesn't
know `migrate` and a bare `/tt-guide` may still reach it:

```
/core:tt-guide migrate
```

It lists the old `tt-*` links and the old hook entry, and removes the links only
after you say yes. Nothing else of yours is touched: connection packs, modes,
feature links and the token log all live outside the skills and carry over.

### GitHub Copilot CLI

Copilot CLI has no install from this repository yet, so it uses the skill
folders directly. It reads personal skills from `~/.copilot/skills/<skill-name>/SKILL.md`
and from `~/.agents/skills/<skill-name>/SKILL.md`; the link script fills both.

1. **Clone** this repo anywhere:

   ```sh
   git clone https://github.com/TimLewisDev/Tims-AI-Toolbox.git
   ```

2. **Run the link script** from the clone's top folder:
   - Windows: double-click `link-copilot-codex.cmd`.
   - macOS / Linux: run `./link-copilot-codex.sh`.

   It shows what it will pull and link, asks before changing anything, then
   links every `plugins/*/skills/tt-*` folder into the two locations above
   (directory junctions on Windows, no admin rights needed; symlinks elsewhere).
   It is safe to run again.

3. **Restart Copilot CLI.** The skills are then available as `tt-guide`,
   `tt-workflow` and so on; ask for `tt-guide` to meet Tatty.

To update, run the link script again: it pulls the latest and links any new
skills. See the [Copilot CLI skill documentation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills).

### Codex CLI

Codex CLI reads personal skills from `~/.agents/skills/<skill-name>/SKILL.md`
(the older `~/.codex/skills` isn't managed by the link script). The steps are
the same as for Copilot CLI:

1. Clone the repo (`git clone https://github.com/TimLewisDev/Tims-AI-Toolbox.git`).
2. Run `link-copilot-codex.cmd` (Windows) or `./link-copilot-codex.sh`
   (macOS / Linux) from the clone's top folder and say yes when it asks.
3. Restart Codex CLI and ask for `tt-guide`.

To update, run the link script again. See the [Codex skill documentation](https://developers.openai.com/codex/skills).

Both scripts call `plugins/core/skills/tt-guide/scripts/guide.sh update` (`check`
previews, `apply` makes the changes), so you can also run that by hand. In
these two clients the skills find `tt-common` in the folder they are linked
into; the plugin pointer folder isn't used.

## The skills

The catalogue, how the skills fit together, the ideas behind them and a
reference for each skill are in
[`plugins/core/skills/tt-guide/toolbox.md`](plugins/core/skills/tt-guide/toolbox.md).
Or ask Tatty: `/tt-guide about <skill or topic>`.

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
- **Optional, for the token log (Claude Code):** nothing to install;
  `/tt-metrics on` turns on the `SessionEnd` hook that `core` already ships.

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

Or install from your clone like anyone else would, so edits show up after
`/reload-plugins`:

```
/plugin marketplace add <path to your clone>
/plugin install engineering@tims-ai-toolbox
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
a throwaway git repo, including a CRLF copy, and checks the plugin layout and
the linked-into-one-folder install used by Copilot CLI and Codex CLI:

```sh
bash tools/test-scripts.sh
```

Selective knowledge retrieval is traced in each project's machine-local
`retrieval.log`. Summarise one project with
`bash tools/retrieval-report.sh ~/.claude/tt-projects/<project-key>` or all
cached projects with `bash tools/retrieval-report.sh --all ~/.claude/tt-projects`.

## License

[MIT](LICENSE).
