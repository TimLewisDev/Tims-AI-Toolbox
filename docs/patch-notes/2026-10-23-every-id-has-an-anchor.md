# Every ID has an anchor

- **Date:** 2026-10-23

## Why
A link to an `R`, `A`, `S` or `C` item only landed on the bullet in an Obsidian vault; in a plain folder the bullet had no block id, so a link or a reader could only find the section. And nothing said which document owns which prefix, so a tool given a bare `CH5` or `T07` had to guess where to look.

## Added
- `ids.sh index <feature-folder>`: every ID the folder's documents define, one row per ID (`ID`, file, line, form, gloss), taken from the document that owns its prefix. `form` is `heading`, `item` or `row`; a heading or item beats an "at a glance" row in the same document.
- An owner map and an Anchors rule in `planning-protocol.md`: each ID is defined once, in its owning document, as a heading, a bullet ending in its block id, or a table row whose first cell is the ID.
- `ids.sh defined` also sees a bullet that opens with the bold ID and no colon (`- **A1** text`, the Lite Brief's acceptance form), and table rows for Debug Log hypotheses (`| H1 |`) and Task Status decisions (`| D1 |`). `H` and `D` are not cited in prose, so `cited`, `xref` and `linkify` are unchanged for them.

## Changed
- Block ids are written in every folder, vault or not: the plan's `R`, `A`, `S` and `C` bullets and a Lite Brief's acceptance items (`- **A1** <text> ^a1`). Links still follow the folder's style.
- `tt-lite-brief` runs `ids.sh anchor --fix` on the brief after assembling it.

## Notes
- A plan written before this change keeps working; `ids.sh anchor --fix` adds its block ids.
