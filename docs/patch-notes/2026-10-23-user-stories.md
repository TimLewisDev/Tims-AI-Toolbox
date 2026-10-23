# User stories from a design document

- **Date:** 2026-10-23

## Why
The design plugin had no skills. Designers turn design documents into user stories by hand, and stories written by hand, or by a model, come out in a different shape every time, which makes them hard to compare, review or load into another tool.

## Added
- `tt-user-stories` (design plugin): reads a design document and writes `<Prefix> - User Stories.md`. It proposes the groups, writes a story for each need the design states, then proposes merged stories where two overlap and stories the design seems to have missed. The designer takes each proposal in turn: Accept, Reject, or Alter (the story is rewritten and proposed again). `resume` carries on the review; running it again on a changed design adds only what's new.
- Unattended modes for tools that show the stories elsewhere: `draft` writes everything and asks nothing (proposals wait as Proposed), and `alter` rewrites one Proposed story from a note file.
- `stories.sh` (in the skill's `scripts/`), the only writer of the document. Every write renders the whole document again from `templates/user-stories.md` and `templates/story.md`, so every story reads the same. Commands: `init`, `add`, `edit`, `set`, `accept`, `reject`, `group add|describe|rename|remove`, `status`, `list --tsv`, `show --tsv`, `check` and `tidy`. `list --tsv` gives each story a hash, and `--if <hash>` refuses a change to a story that moved since it was read; a lock keeps two writers apart. A spec can be passed on stdin (`-`), so an unattended run needs no permission to write files at all: only to run `stories.sh`.

## Changed
- `tt-guide` lists the design plugin's skill, says it comes from design when it isn't installed, and has a User Stories row in the documents table.
- The design plugin is no longer a placeholder (version 0.2.0); core is 0.1.2 for the guide's changes.

## Notes
- Story IDs are `US-01`, `US-02`… and never reused; rejected and merged stories move to the Retired table instead of being deleted.
- The script refuses to write to a document that was edited out of its layout, so nothing in it is lost; `stories.sh check` says why and `stories.sh tidy` lays it out again.
