# User story template

`scripts/stories.sh` renders the fenced block below once per story, in the
`## Stories` section of `user-stories.md`. Nobody writes a story by hand; the
skill hands the script a spec (see the script's usage) and the script fills
this in, so every story reads the same.

- `<id>` is `US-` and at least two digits, never renumbered.
- `<status>` is `Accepted` or `Proposed`.
- `<origin>` is `Design doc`, `Suggested` or `Merge of US-02, US-05`.
- The Altered line is left out until the story has been altered at least once.
- `<source>` is the part of the design document the story comes from (`—` for
  none).
- `<article>` is `a` or `an`, chosen from `<as>` (or given in the spec).
- `<details>` is free text (`—` when empty); `<criteria>` is one
  `- Given …, when …, then …` line per criterion.
- `stories.sh` reads this layout back. Change its parser with the template.

```
### <id>: <title>

- **Group:** <group>
- **Status:** <status>
- **Origin:** <origin>
- **Altered:** <altered>
- **Source:** <source>

**As <article>** <as>, **I want** <want>, **so that** <so_that>.

#### Details

<details>

#### Acceptance criteria

<criteria>
```
