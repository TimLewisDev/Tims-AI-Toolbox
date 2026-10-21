# The toolbox is a set of Claude Code plugins, split by discipline

- **Date:** 2026-10-21

## Why
Installing meant cloning the repo and junctioning 27 folders into `~/.claude/skills`, all or nothing. Different disciplines need different parts: an engineer wants the planning and build pipeline, a producer or designer will want their own skills, and everyone wants the guide and the shared setup.

## Added
- A marketplace, `tims-ai-toolbox` (`.claude-plugin/marketplace.json`), with four plugins: `core`, `engineering`, and the placeholders `design` and `production` (no skills yet; each depends on `core`). Install what you need: `/plugin install core@tims-ai-toolbox` plus a discipline plugin.
- `hooks/register.sh` in every plugin, run at `SessionStart`: points `~/.claude/tt-plugins/<plugin>` at the plugin's installed folder, so skills in one plugin can reach `tt-common` (in `core`) and each other. An identical copy ships in each plugin; the tests check it.
- `tt-common/scripts/tt-path.sh`: `tt_find <skill>` and `tt_skills`, looking beside `tt-common` first, then through the pointers.
- `tt-guide migrate [check|apply]`: lists the old `~/.claude/skills/tt-*` links and removes them after a yes; reports an old `record-session.sh` entry in `settings.json`.
- Plugin tests in `tools/test-scripts.sh`: the pointer hook, `tt_find`, a core-only guide, every `SKILL.md` name matching its folder, no engineering text reaching `tt-common` by `..`.

## Changed
- Skills moved to `plugins/core/skills/` (`tt-common`, `tt-guide`, `tt-config`, `tt-connections`, `tt-metrics`) and `plugins/engineering/skills/` (the rest). Folder names, slash commands and cross-references are unchanged.
- Engineering skills find `tt-common` at `~/.claude/tt-plugins/core/skills/tt-common` (or beside them when the skills are linked into one folder). `workflow.sh`, `fix-card.sh`, `handoff.sh` and `session-handoff.sh` look it up instead of assuming a sibling; the `<result template>` path in the coder hand-off is filled in by `handoff.sh`.
- The catalogue moved from `README.md` to `tt-guide/toolbox.md`, which `tt-guide` reads; the README is now the install guide.
- `tt-metrics`: the recorder scripts moved into `tt-metrics/scripts/` and the `SessionEnd` hook comes with `core`, so `/tt-metrics on` no longer edits `settings.json`.
- `tt-guide update` says how to update the plugins; for a clone linked into Copilot CLI or Codex CLI it still pulls and links. `initial-setup.*` became `link-copilot-codex.*`.
- `tt-guide` names `engineering` when its skills are missing instead of suggesting commands that would not run.

## Notes
- Existing users: install the plugins, then run `/tt-guide migrate`. Connection packs, modes, feature links and the token log are under `~/.claude` and carry over.
- A newly installed plugin registers its pointer at the next session start; `/tt-guide` also registers `core` when run. After installing, restart Claude Code or run `/reload-plugins`.
- Copilot CLI and Codex CLI keep the link-based install for now; their plugin formats were not looked at.
