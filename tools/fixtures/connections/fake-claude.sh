#!/usr/bin/env bash
# fake-claude.sh: a stand-in for `claude mcp list`, for the connection tests.
# It prints the lines in $FAKE_CLAUDE_LIST, one server per line.
[ "${1:-}" = mcp ] && [ "${2:-}" = list ] || exit 1
[ -n "${FAKE_CLAUDE_CALLS:-}" ] && echo x >>"$FAKE_CLAUDE_CALLS"
echo "Checking MCP server health..."
echo
[ -f "${FAKE_CLAUDE_LIST:-/nonexistent}" ] && cat "$FAKE_CLAUDE_LIST"
exit 0
