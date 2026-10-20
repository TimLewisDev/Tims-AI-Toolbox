# Plan IDs say what they mean

- **Date:** 2026-10-20

## Why
Chat and documents cited plan IDs bare ("R12", "C16", "Target: C4"), so the engineer had to open the plan to follow a conversation.

## Added
- `ids.sh gloss [--link] <doc> <ID>...`: what each ID says, as a short phrase cut from the document (statement bullets, `CD`/`NB` table rows, `P`/`CH`/`§` headings, ranges). An ID the document does not define prints `?` and exits 1, so a skill cannot invent a meaning. `--link` adds an Obsidian or relative Markdown link.
- `ids.sh anchor [--fix] <plan>`: checks that `R`, `A`, `S` and `C` bullets end in an Obsidian block id (` ^r12`, on the last line of a wrapped bullet); `--fix` adds the missing ones and keeps a Windows line end.
- `ids.sh linkify --def <plan> [--def ...] <doc>`: turns bare single-ID cites into links. Leaves code, fences, existing links, headings, ranges, front matter and the document's own definitions alone, escapes the bar in table cells, and changes nothing the second time.
- `ids.sh style <doc>`: `obsidian` when a `.obsidian` folder sits above the document, else `md`.
- A "Citing IDs" rule in `planning-rules.md` and "Saying what an ID means" in `planning-protocol.md`: the first mention in a message reads `R12 (what it says)`.

## Changed
- Stage exits, the ledger delta, challenge presentation, the break-point and sign-off summaries, the Critical Decision card, the breakdown review and `tt-execute` reports now say what the IDs they name mean.
- `ids.sh defined` prints the same short gloss in its third column (it used to be the line cut at 100 characters), so task-card "Plan IDs" read better.
- The Comprehensive Plan template puts block ids on its `R`, `A`, `S` and `C` bullets (in a vault only).
- `tt-tech-plan`, `tt-tech-proposals` and the Challenges step run `linkify` last. The Comprehensive Plan and the Task Breakdown are never linkified: their text is compared verbatim.

## Notes
- A plan written before this change keeps working; run `ids.sh anchor --fix` on it to get block-id links, otherwise links land on the section.
- `awk` and `grep` in Git for Windows drop the CR of a CRLF file on read, so `ids.sh` detects it with `tr` and puts it back.
