# Install for GitHub Copilot CLI

Copilot CLI has no install from this repository yet, so it uses the skill
folders directly: you clone the repo and a script links them into Copilot's
personal skill folders. You get every skill; the split by discipline is Claude
Code only for now.

[Back to the README](../README.md)

Copilot CLI reads personal skills from `~/.copilot/skills/<skill-name>/SKILL.md`
and from `~/.agents/skills/<skill-name>/SKILL.md`; the link script fills both.

## Install

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

- The skills are written for Claude Code. Copilot CLI needs equivalents of the
  Skill tool, `AskUserQuestion` and subagents, or does that work itself. See
  [Requirements](requirements.md).
- Copilot CLI's own documentation: [adding skills](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills).
- Using Codex CLI as well? See [Install for Codex CLI](install-codex-cli.md);
  the same script covers both.
