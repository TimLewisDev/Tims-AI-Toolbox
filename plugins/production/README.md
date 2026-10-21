# production

Placeholder for the production discipline's skills. It has no skills yet; it exists so
the plugin can be installed, versioned and built out without changing how the
toolbox is split.

Install it next to the shared base:

```
/plugin install core@tims-ai-toolbox
/plugin install production@tims-ai-toolbox
```

## Adding a skill

1. Make `skills/tt-<name>/SKILL.md` in this folder (the folder name is the
   slash command, so keep the `tt-` prefix).
2. Reach the shared rules, templates and scripts in `tt-common` through
   `~/.claude/tt-plugins/core/skills/tt-common` (or with `tt_find` from
   `tt-common/scripts/tt-path.sh` in a script), never with `..`: plugins are
   installed in separate folders.
3. Keep the `hooks/` folder (`hooks.json` and `register.sh`, an identical copy of
   the one in `plugins/engineering/hooks/` with this plugin's name) so the other
   plugins can find this one.
4. Add a row to the catalogue in `plugins/core/skills/tt-guide/toolbox.md` and
   bump `version` in `.claude-plugin/plugin.json` when you release.
