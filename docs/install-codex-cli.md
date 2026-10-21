# Install for Codex CLI

Codex CLI has no install from this repository yet, so it uses the skill folders
directly: you clone the repo and a script links them into Codex's personal skill
folder. You get every skill; the split by discipline is Claude Code only for
now.

[Back to the README](../README.md)

Codex CLI reads personal skills from `~/.agents/skills/<skill-name>/SKILL.md`.
The older `~/.codex/skills` isn't managed by the link script.

## Install

1. **Clone** this repo anywhere:

   ```sh
   git clone https://github.com/TimLewisDev/Tims-AI-Toolbox.git
   ```

2. **Run the link script** from the clone's top folder:
   - Windows: double-click `link-copilot-codex.cmd`.
   - macOS / Linux: run `./link-copilot-codex.sh`.

   It shows what it will pull and link, asks before changing anything, then
   links every `plugins/*/skills/tt-*` folder into `~/.agents/skills` (directory
   junctions on Windows, no admin rights needed; symlinks elsewhere). It also
   fills `~/.copilot/skills` for Copilot CLI. It is safe to run again.

3. **Restart Codex CLI** and ask for `tt-guide` to meet Tatty, the toolbox's
   guide.

## Updating

Run the link script again: it pulls the latest and links any new skills. Or run
the updater it uses by hand (`check` previews, `apply` makes the changes):

```sh
bash plugins/core/skills/tt-guide/scripts/guide.sh update check
bash plugins/core/skills/tt-guide/scripts/guide.sh update apply
```

In this setup the skills find `tt-common` in the folder they are linked into;
the plugin pointer folder isn't used.

## Notes

- The skills are written for Claude Code. Codex CLI needs equivalents of the
  Skill tool, `AskUserQuestion` and subagents, or does that work itself. See
  [Requirements](requirements.md).
- Codex CLI's own documentation: [skills](https://developers.openai.com/codex/skills).
- Using Copilot CLI as well? See [Install for GitHub Copilot CLI](install-copilot-cli.md);
  the same script covers both.
