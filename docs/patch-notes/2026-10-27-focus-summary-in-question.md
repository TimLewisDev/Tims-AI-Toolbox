# The focus question shows what the Focus Log says

- **Date:** 2026-10-27

## Why
At the end of `tt-familiarise` the engineer was asked whether the focus was right, but the question itself said nothing of what the Focus Log held. The statement and topics were shown in prose before the question, and a front end that shows the question on its own (Tatty's question card, for one) never showed them. The log was on disk and the engineer had to go and find it.

## Added
- `tt-familiarise/scripts/focus-summary.sh <focus-log.md>`: a short summary of a Focus Log as markdown. It gives the focus statement, the Focus and Context topics, a count of parked and unrated topics, the wanted change for a lite log, and a link to the log. The link is `[[focus-log]]` in an Obsidian vault and a relative Markdown link elsewhere, with the plain path beside it.

## Changed
- `tt-familiarise` puts that summary inside the `AskUserQuestion` text at **Close** (full and lite mode), so the engineer sees it with the question and can open the log from the link. The Boil-down playback goes in the question text too.

## Notes
- The toolbox still knows nothing of any front end. A front end that follows document links opens the log from the link; in a terminal the path is printed beside it.
- `tt-familiarisation-doc` still shows an unconfirmed focus statement in prose when it is run on a log whose focus is not confirmed. It was not changed.
