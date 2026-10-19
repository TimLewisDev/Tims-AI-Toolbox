# tt-guide connections: describe your connections in plain English

- **Date:** 2026-10-19

## Added
- `/tt-guide connections [what to include]`: the engineer says which MCP servers, CLI logins and git settings they use. Tatty turns that into pack rows, plays them back in plain English, and only after an explicit yes saves a machine-wide connection pack. She never runs a setup command; `/tt-connections setup` does.
- `connections.sh pack save <name> [--replace]`: validates the pack text on stdin and writes `<name>.pack` to the packs folder. Exit 4 when the name exists and `--replace` was not given.
- `guide.sh pack list` and `guide.sh pack save`: passthroughs to the above.
- Catch-all packs: a pack with `# match: *` applies to every project.

## Changed
- `connections.sh` pack matching: a pack with a specific match always wins over a pack that matches only `*`, whatever the file names. A project with no remote can now use a catch-all pack.
- `valid_pack` (used by `pack install` and `pack save`) refuses a row whose `kind` is not `mcp` or `cmd`.
- `/tt-guide connections` no longer reports status in the skill; `/tt-connections` and `guide.sh connections` still do, and `tt-guide init` still uses the script.
- `tt-guide`'s description and guardrail now name the connection pack as the one file Tatty writes besides the project cache.
- `README.md` and `tools/test-scripts.sh` cover the new command, `pack save` and the matching rule.
