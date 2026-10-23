# design

The design discipline's skills. Needs **core**.

| Skill | What it does |
|---|---|
| [`tt-user-stories`](skills/tt-user-stories/SKILL.md) | Turns a design document into a `<Prefix> - User Stories.md` of grouped user stories; proposes merges and missed stories for the designer to accept, reject or alter; writes every story from one template by script (`scripts/stories.sh`). |

Install it next to the shared base:

```
/plugin install core@tims-ai-toolbox
/plugin install design@tims-ai-toolbox
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
4. Add a row to the catalogue in `plugins/core/skills/tt-guide/toolbox.md`, a
   row to the table above, a case to `plugin_hint` in
   `plugins/core/skills/tt-guide/scripts/guide.sh`, and bump `version` in
   `.claude-plugin/plugin.json` when you release.
