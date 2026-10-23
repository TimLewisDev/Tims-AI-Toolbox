# Install for Claude Code

Claude Code installs the toolbox as plugins from a marketplace, split by
discipline so each person installs only what they use.

[Back to the README](../README.md)

## Contents

- [Install](#install)
- [Which plugins to install](#which-plugins-to-install)
- [Updating](#updating)
- [Setting up a team](#setting-up-a-team)
- [Coming from the old install](#coming-from-the-old-install)

## Install

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

You need bash and git (Git for Windows provides both as Git Bash). Claude Code
clones the marketplace with your own git credentials, so you need `git` access
to the repository. More in [Requirements](requirements.md).

## Which plugins to install

| You are | Install | What you get |
|---|---|---|
| An engineer | `core` + `engineering` | Everything: explore, plan, break down, build, debug, review MRs. |
| A designer | `core` + `design` | The shared base. `design` adds `tt-user-stories` (user stories from a design document). |
| A producer | `core` + `production` | The shared base. `production` has no skills yet; it is the place to build them. |
| Anyone | `core` alone | Tatty (`tt-guide`), `tt-config` (models and effort), `tt-connections` (MCP servers and logins), `tt-metrics` (token log). |

You can install any combination, for example `engineering` and `production`
together. The plugins find each other through a pointer folder,
`~/.claude/tt-plugins/`, that a `SessionStart` hook in each plugin keeps up to
date, so `engineering` needs `core` installed and a restarted session.

## Updating

Third-party marketplaces don't auto-update by default. Turn it on once and the
plugins keep themselves current:

```
/tt-guide update
```

Tatty reports whether auto-update is on and, after you say yes, adds
`"autoUpdate": true` to the `tims-ai-toolbox` entry in your user
`settings.json`. The same switch is in `/plugin`, under **Marketplaces**, then
`tims-ai-toolbox`. It applies from the next session. After that, Claude Code
refreshes the marketplace once your first message of a session is sent (after a
delay of up to ten minutes) and updates the plugins whose `version` was bumped.
A running session keeps its old copy until you run `/reload-plugins`.

To update right now instead:

```
/plugin marketplace update tims-ai-toolbox
/plugin update core@tims-ai-toolbox
/plugin update engineering@tims-ai-toolbox
```

then `/reload-plugins`. A plugin only updates when its `version` in
`.claude-plugin/plugin.json` has been bumped.

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
by the old `initial-setup` script. Those links load every skill a second time
next to the plugins, and the metrics hook in `settings.json` would log each
session twice. After installing the plugins, ask Tatty to clean up. Use the full
name, because the old `tt-guide` link doesn't know `migrate` and a bare
`/tt-guide` may still reach it:

```
/core:tt-guide migrate
```

It lists the old `tt-*` links and the old hook entry, and removes the links only
after you say yes. Nothing else of yours is touched: connection packs, modes,
feature links and the token log all live outside the skills and carry over.
