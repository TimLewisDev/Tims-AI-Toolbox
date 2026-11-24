# Review a design document for what it is missing

- **Date:** 2026-11-24

## Why
A design document is checked for gaps by whoever reads it, and what they find is lost in a chat or a comment. Tatty's new Documents page (design mode) needs a skill that finds the gaps and a writer that records them so each one can be accepted, reworded or rejected, and its wording added to the document.

## Added
- `tt-design-review` (design plugin): reads a design document and lists the areas it may be missing (who it is for, failure and edge cases, data and state, limits and performance, platform differences, dependencies, analytics, accessibility, localisation, security, migration, rollout, open questions), as suggestions in `<Doc> - Design Review.md`. Each has the reason it matters, the heading it belongs under and draft wording in the document's own voice. It proposes only what the document leaves out, never what is already answered or was rejected before, and at most eight at a time. Run on its own it then takes each suggestion in turn (accept, reword, reject, later); `resume` carries on.
- An unattended mode for tools that show the suggestions elsewhere: `review <design doc> <review doc> [<comments file>]` asks nothing. The optional comments file is the designer's own notes on passages of the document; open ones steer what it looks for.
- `design-review.sh` (in the skill's `scripts/`), the only writer of the review and the only thing that adds to the design document. Commands: `init`, `add` (specs on stdin, at most 8 a call), `decide accept|reject|reopen`, `wording`, `confirm`, `list --tsv`, `show --tsv`, `hash` and `check`. `confirm` adds an accepted suggestion's wording to the document as whole blocks at the end of the section under its heading (or as a new `## <area>` section at the end) and records exactly what it added, so a viewer can mark it. `--if <hash>` refuses a change to a suggestion that moved since it was read, and `--doc-if` refuses to add to a document that changed; a lock keeps two writers apart. CRLF documents stay CRLF.

## Changed
- `tt-guide` lists the new skill; the design plugin is 0.3.0 and core 0.11.1 (the guide's hint and catalogue).

## Notes
- Suggestion IDs are `DR01`, `DR02`… and never reused; a rejected suggestion stays in the review, so it is not proposed again.
- Wording can't hold a level 1 or 2 heading (it would change the document's outline); a `###` heading or bold text does.
- The skill is written for Tatty's Documents page first; the toolbox no longer has to work without Tatty.
