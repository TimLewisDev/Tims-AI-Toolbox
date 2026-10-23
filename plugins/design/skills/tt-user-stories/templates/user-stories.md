# User Stories document template

`scripts/stories.sh` renders the fenced block below. Nobody copies it by hand.

- Lines before the first `## ` are the header. Only `init` uses them; after
  that the document keeps its own header (tags, links, notes), and only the
  Status line is changed (by `stories.sh status`).
- `<group rows>`, `<stories>` and `<retired rows>` stand on lines of their own
  and expand to one row or story per item (nothing when there are none). Each
  story is rendered from `story.md`.
- Sections the document has that aren't here are kept, after Retired.
- `stories.sh` reads this layout back. Change its parser with the template.

```
# <title>

- **Source:** <source>
- **Status:** <status>

## Groups

| Group | Description |
|---|---|
<group rows>

## Stories

<stories>

## Retired

| ID | Title | Outcome |
|---|---|---|
<retired rows>
```
