# tt-connections setup: stay with each connection until it is signed in

- **Date:** 2026-10-19

## Added
- `connections.sh hint <id> [dir]`: what to do next to get one connection working, by its state. For an MCP server that is registered but not signed in it gives two routes: sign in from a second terminal, or restart the session. It explains why `/mcp` shows nothing in the session that ran `claude mcp add` (a running session does not see servers added after it started).

## Changed
- `/tt-connections setup` no longer hands the sign-in over and moves on. A sign-in loop stays on each connection: it shows the `hint` steps, asks "I've signed in, check now / It isn't working, help me / Stop for now", re-checks with `check`, and explains each failure (`auth`, `missing`, `down`) until the connection is ok or the engineer stops. Stopping tells them `/tt-connections setup` resumes at the same connection.
- `claude mcp remove` joins the commands that run only after an explicit yes.
- Packs written by `/tt-guide connections` add MCP servers with `--scope user`, so one sign-in works in every project instead of only the folder they were added from.
- `README.md` describes the loop; `tools/test-scripts.sh` covers `hint`.
