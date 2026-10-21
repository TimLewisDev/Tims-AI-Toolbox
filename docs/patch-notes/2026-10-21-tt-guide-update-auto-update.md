# `/tt-guide update` turns on auto-update

- **Date:** 2026-10-21

## Why
With the toolbox installed as plugins, the old update (pull the clone, relink the skills) no longer applies to Claude Code. Third-party marketplaces don't auto-update by default, so people had to run three `/plugin` commands on every release.

## Added
- `guide.sh update` reports `Auto-update: on | off | unset | absent` for the `tims-ai-toolbox` marketplace, read from `settings.json` (`extraKnownMarketplaces`) and `plugins/known_marketplaces.json`. It handles compact and pretty JSON and CRLF, and ignores other marketplaces' settings.
- `/tt-guide update` offers to turn it on and, on a yes, adds `"autoUpdate": true` to the marketplace entry in `settings.json`; it applies from the next session.

## Changed
- The `update` output leads with the auto-update state and lists the three `/plugin` commands as "update right now". The block is skipped when there is no Claude config folder, so Copilot CLI and Codex CLI users running the link script don't see it.
- The Copilot CLI and Codex CLI part (pull the clone, relink) is unchanged.

## Notes
- Auto-update moves a plugin only when its `version` in `plugin.json` changes, so bump it on each release.
- A running session keeps its old copy until `/reload-plugins`.
- The setting is documented by Claude Code but has no CLI command; the same switch is in `/plugin`, under Marketplaces. The flag was accepted by the CLI in a test, but the background refresh itself was not observed.
