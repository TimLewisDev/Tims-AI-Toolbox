---
name: tt-connections
description: >
  Check the connections a project needs (MCP servers such as an issue tracker,
  wiki, source host or design tool, plus CLI logins and git settings) and set
  up the missing ones one at a time, each with a yes or a skip. The list comes
  from a connection pack installed on the machine and matched to the project by
  its git remote, so each project can need different things and this skill
  names none. Runs claude mcp add after a yes, then hands the sign-in step to
  the user. Use after tt-guide init, or when asked to set up, check or fix a
  project's MCP or tool connections.
argument-hint: "[status | setup | pack install <file> | link <pack> | unlink | list]"
allowed-tools: Bash, AskUserQuestion
metadata:
  version: "1.0"
---

# tt-connections

Which connections a project needs is not in this skill or in the project's
repo. It is in a **connection pack**: a small text file, shared on its own, that
each engineer installs once. The pack is matched to the project by its git
remote, or by a link the engineer made. A project with no pack needs nothing
from this skill.

Run the script for facts; read no pack by hand:

```sh
bash "<skill folder>/scripts/connections.sh" <command>
```

## status

For `status` (the default), run `connections.sh status`. Show the table as it
prints. Exit 3 means no pack matches this project: say so in one line and tell
the engineer how to get one (`pack install <file>`, then it matches by remote,
or `link <pack>` if the remote doesn't match). Exit 1 means gaps; offer `setup`.

## setup

Work through the gaps **one connection at a time**. Never batch them.

1. Run `connections.sh next --skip <ids skipped so far>`. Exit 1 means nothing
   is left: say everything is connected and stop. Otherwise it prints `id`,
   `state`, `label`, `kind`, `setup`, `handoff` and `remaining`.
2. Ask with AskUserQuestion, naming the connection and what yes will do:
   **Yes, set it up**, **Skip**. (The engineer can pick Other to stop.)
3. **Skip**: add the id to the skip list and go back to step 1. Say nothing
   more about it. Skips last for this run only.
4. **Yes**:
   - `state=missing` and `setup` is a command: if it has `<placeholders>`, ask
     the engineer for each value (never a token or password), then run it and
     show its output. If `setup` is `-`, there is nothing to run; go to the hand-off.
   - `state=auth` or `down`: the connection is already registered, so don't run
     the add command again; go to the hand-off.
   - Give the `handoff` step as the next thing for the engineer to do. When it is
     a command that needs a secret or a browser sign-in, tell them to type it
     themselves with the `!` prefix (or `/mcp` for an MCP sign-in) rather than
     pasting the secret here.
   - Run `connections.sh check <id>` and report the result. If it is still not
     ok, say what is still needed and move on; don't loop on it.
5. Go back to step 1.

At the end run `connections.sh status` once and show it.

## Packs

```sh
connections.sh pack install <file or folder>   # copy .pack files into the packs folder
connections.sh list                            # installed packs and the remotes they match
connections.sh which [dir]                     # the pack that applies to a project
connections.sh link <pack>                     # use a pack for this project whatever its remote
connections.sh unlink                          # back to matching by remote
```

The pack format is in `connections.sh --help`. `kind` is `mcp` (the check is the
server name, looked up in `claude mcp list`) or `cmd` (the check is a shell
command that exits 0 when the connection works). MCP setup uses the `claude`
CLI, so it is Claude Code only.

## Rules

- Never ask for, accept or echo a token, password or key. Secrets are entered in
  the engineer's own shell or browser.
- Never edit `settings.json`, `.mcp.json` or `~/.claude.json` by hand; use the
  pack's `claude mcp add` command.
- Run a pack's `setup` command only after the engineer's yes for that connection.
- Never touch git beyond what a pack's own `setup` command says; never commit.
