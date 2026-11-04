# Template: Challenges doc

`<Prefix> - Challenges.md` is the permanent record of what each stage's
adversary attacked and how the engineer resolved it. `tt-adversarial-plan`
creates it at the first challenge from the block below. From then on
`tt-common/scripts/challenges.sh` is its only writer: it appends one section
per stage (the adversary's file) with its **At a glance** rows, records the
planner's **Take**, and keeps each challenge's **Outcome** and **Resolution**
current. Nothing is ever deleted; a challenge raised again with new evidence
is a new `CH` that names the earlier one.

Outcomes: `Open` · `Accepted` (the plan changed; the resolution names the IDs,
or reads `To apply: …` until the planner has changed the plan) · `Rebutted`
(the plan stands; the resolution gives the engineer's reason) · `Deferred` (to
Future Iterations) · `Dismissed` (minor, not taken up).

```markdown
<header or tag block matching sibling docs>

# <Feature>: Challenges

- **Comprehensive Tech Plan:** <link> · **Familiarisation:** <link, or omit>
- Each planning stage was challenged by an adversary that saw only the written
  documents and the code, not the conversation. Every challenge was put to the
  engineer.

## At a glance
| CH | Stage | Severity | Target | Outcome |
|---|---|---|---|---|

<one section per stage follows, in the order the stages were challenged>
```

Each stage section has the layout in `briefs/challenge.md`. The script adds the
take and, as the challenge is decided and applied, rewrites its last lines:

```markdown
- **Take:** *Recommend accept.* R4 assumes one trigger per change, but the handler is registered on every open.
- **Outcome:** Accepted
- **Resolution:** <date>: R4 reworded to cover a repeated trigger; new R12.
```
