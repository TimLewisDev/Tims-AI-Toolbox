# core

The shared base every discipline installs.

| Skill | What it is |
|---|---|
| `tt-guide` | Tatty, the toolbox's guide; the catalogue lives in `tt-guide/toolbox.md`. |
| `tt-config` | Model and effort modes for the stages. |
| `tt-connections` | Checks and sets up a project's MCP servers, logins and git settings. |
| `tt-metrics` | Optional token log; its `SessionEnd` hook comes with this plugin. |
| `tt-common` | Not run directly: shared rules, templates and scripts the other plugins use. |

The `SessionStart` hook (`hooks/register.sh`) keeps `~/.claude/tt-plugins/core`
pointing at this plugin's installed folder, so skills in the other tt plugins
can reach `tt-common` (see `tt-common/scripts/tt-path.sh`).

```
/plugin install core@tims-ai-toolbox
```
