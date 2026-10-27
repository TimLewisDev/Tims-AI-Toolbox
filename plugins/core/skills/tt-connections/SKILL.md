---
name: tt-connections
description: >
  Check the connections a project needs (MCP servers such as an issue tracker,
  wiki, source host or design tool, plus CLI logins and git settings) and set
  up the missing ones one at a time, each with a yes or a skip. The list comes
  from a connection pack installed on the machine and matched to the project by
  its git remote, so each project can need different things and this skill
  names none. Runs claude mcp add after a yes, then walks the user through
  signing in until it works. It also connects the machine's LLM tools (claude,
  copilot, codex) and lists the models each one offers, which tt-config offers
  in turn. Use after tt-guide init, or when asked to set up, check or fix a
  project's MCP or tool connections, or to connect or list LLM tools and models.
argument-hint: "[status | setup | pack install <file> | link <pack> | unlink | list | llms]"
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

## llms

`llms` is about the machine, not the project: which LLM command-line tools are
connected (`claude`, `copilot`, `codex`) and which models they offer. The
models fill the choices `tt-config` offers. Run the script for facts:

```sh
bash "<skill folder>/scripts/llms.sh" <command>
```

- `status`: each tool's state: connected, available (installed, not connected),
  missing (connected but gone from the PATH) or not installed. Show it as it
  prints.
- `models`: the models of the connected tools, with the efforts each takes and
  whether a skill can run it (`runnable`).
- `connect <tool>`: ask first (**Connect**, **Skip**). The script finds the tool
  on the PATH, notes its version and generates its models from the tool's own
  `--help`. Exit 1 means it isn't installed: say how to install it and stop. If
  the tool needs a sign-in, tell the engineer to run it once in a terminal;
  never ask for a token.
- `disconnect <tool>` and `refresh [tool]` (generate the models again). `claude`
  can't be disconnected: it runs the skills.

Today only `claude`'s models are `runnable`. A model of another tool is listed
so it can be seen and chosen later, but `tt-config` won't accept it for a stage
yet, because a subagent can only be spawned on a Claude model. Models a tool
doesn't list can be added, one per line, in
`~/.claude/tt-llms/models.d/<tool>.tsv` (`id`, `label`, `efforts`, `yes|no`,
tab-separated).

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
     show its output, then go to the sign-in loop. If `setup` is `-`, there is
     nothing to run; go to the sign-in loop.
   - `state=auth` or `down`: the connection is already registered, so don't run
     the add command again; go to the sign-in loop.
   - Then stay on this connection with the **sign-in loop** until it is
     connected or the engineer stops. Never leave them at "the next step is yours".
5. Go back to step 1.

### Sign-in loop

A running Claude Code session does not see MCP servers added after it started, so
`/mcp` here shows nothing for a server just added: the sign-in has to happen in a
new session. `connections.sh hint` says how; relay its steps in plain words and
don't improvise them.

1. Run `connections.sh hint <id>` and give the engineer its steps. If the
   `handoff` step is a command that needs a secret or a browser sign-in, tell
   them to type it themselves with the `!` prefix rather than pasting the secret here.
2. Ask with AskUserQuestion: **I've signed in, check now**, **It isn't working,
   help me**, **Stop for now**. (Other also means stop.)
3. **Check now**: run `connections.sh check <id>`.
   - `ok`: say it is connected and go back to the setup loop for the next one.
   - `auth`: still not signed in. Say what usually causes it (the browser step
     wasn't finished, the wrong workspace or account was chosen, or the server
     didn't appear in `/mcp` in that session, so use the other route) and go to 1.
   - `missing`: it isn't registered. Offer to run the pack's `setup` again; run
     it only on a yes. Go to 1.
   - `down`: run `claude mcp get <id>` and show it. If the URL looks wrong, ask
     the engineer for the right one. Only on their explicit yes, run
     `claude mcp remove <id>` with the scope `get` showed, then the corrected
     `claude mcp add`. Go to 1.
4. **Help**: run `claude mcp get <id>` and `claude mcp list`, explain in a line or
   two what they show for this connection, then go to 1.
5. **Stop**: say `/tt-connections setup` starts again at this connection, because
   the state is checked afresh each run, and go to the final status.

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
- Run a pack's `setup` command, or `claude mcp remove`, only after the engineer's
  yes for that connection.
- Never touch git beyond what a pack's own `setup` command says; never commit.
