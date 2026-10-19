# tt-connections: set up a project's connections from `tt-guide init`

- **Date:** 2026-10-19

## Added
- `tt-connections`: checks the MCP servers, CLI logins and git settings a project needs and sets up the missing ones one at a time, with a yes or a skip for each. On yes it runs the pack's `claude mcp add` (or fix) command and hands the sign-in step to the engineer; it never takes a secret in chat.
- The list of connections comes from a **connection pack**: a tab-separated `.pack` file installed in `~/.claude/tt-connections/packs/` and matched to the project by globs on its git remote (or linked by hand). The toolbox and the project's repo hold none, so each project can need different things and packs are shared on their own.
- `connections.sh`: `status`, `next [--skip]`, `check`, `which`, `list`, `pack install`, `link`, `unlink`. One `claude mcp list` per run.
- `guide.sh connections [dir]`: reports the same table; "no pack" is a normal answer.
- `tools/fixtures/connections/`: an example pack, a second pack and a stand-in `claude`.

## Changed
- `tt-guide init` checks the project's connections after the scan and, on the engineer's yes, starts `tt-connections`. It is the one skill Tatty may start; her guardrail and description say so. `allowed-tools` gains `Skill`.
- `guide.sh`'s header no longer claims it writes nothing.
- `README.md` describes the skill, the pack format and the new step.
- `tools/test-scripts.sh` covers the connection scripts and `guide.sh connections`.
