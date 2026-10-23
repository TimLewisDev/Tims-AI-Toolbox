# Working on the toolbox

[Back to the README](../README.md)

## Contents

- [Layout](#layout)
- [Trying your changes](#trying-your-changes)
- [Rules for skills in different plugins](#rules-for-skills-in-different-plugins)
- [Releasing](#releasing)
- [Testing the scripts](#testing-the-scripts)

## Layout

```
.claude-plugin/marketplace.json     the marketplace: lists the four plugins
plugins/core/                       core: tt-guide, tt-config, tt-connections, tt-metrics, tt-common
plugins/engineering/                engineering: the planning, build, debug and review skills
plugins/design/                     design: tt-user-stories
plugins/production/                 a placeholder, ready for skills
link-copilot-codex.*                links the skills into Copilot CLI and Codex CLI
tools/                              the script tests and their fixtures (not shipped)
docs/                               these pages, patch notes and the script-workflow summary
```

To add a skill to a placeholder plugin, see that plugin's `README.md`.

## Trying your changes

Without installing anything, from the repo root:

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

## Rules for skills in different plugins

- Never reach another plugin's files with `..`: plugins are installed in separate
  folders. Reach `tt-common` through `~/.claude/tt-plugins/core/skills/tt-common`
  in skill text, and with `tt-common/scripts/tt-path.sh` (`tt_find <skill>`) in
  scripts, which also finds skills linked into one folder.
- Every plugin ships an identical `hooks/register.sh`, run at `SessionStart`
  with its own name. The test script checks the copies match.
- Core must work without engineering: a script that reads an engineering file
  looks it up with `tt_find` and says "is engineering installed?" when it is
  missing.

## Releasing

Bump `version` in a plugin's `.claude-plugin/plugin.json` when you release it, or
installed copies won't update. Add a note under [`patch-notes/`](patch-notes/).

## Testing the scripts

[`tools/test-scripts.sh`](../tools/test-scripts.sh) runs the breakdown,
execute and status scripts against the fixtures in `tools/fixtures/`
(`demo/`: a plan, a breakdown and a Task Status; `demo-draft/`: a skeleton;
`lite/`: a Lite Brief and a Debug Log) in
a throwaway git repo, including a CRLF copy, and checks the plugin layout and
the linked-into-one-folder install used by Copilot CLI and Codex CLI. It takes
around 15 minutes on Windows.

```sh
bash tools/test-scripts.sh
```

Selective knowledge retrieval is traced in each project's machine-local
`retrieval.log`. Summarise one project with
`bash tools/retrieval-report.sh ~/.claude/tt-projects/<project-key>` or all
cached projects with `bash tools/retrieval-report.sh --all ~/.claude/tt-projects`.

For what the scripts do for a run and how to use them, see
[`script-workflow.md`](script-workflow.md).
