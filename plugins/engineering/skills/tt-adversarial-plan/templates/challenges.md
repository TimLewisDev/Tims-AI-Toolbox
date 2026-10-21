# Template: Challenges doc

`<Prefix> - Challenges.md` is the permanent record of what each stage's
adversary attacked and how the engineer resolved it. `tt-adversarial-plan`
creates it at the first challenge, then appends one section per stage (the
adversary's file, appended with `assemble.sh append`) and keeps **At a
glance** and each challenge's **Outcome** and **Resolution** current with small
Edits. Nothing is ever deleted; a challenge raised again with new evidence is a
new `CH` that names the earlier one.

Outcomes: `Open` · `Accepted` (the plan changed; the resolution names the IDs)
· `Rebutted` (the plan stands; the resolution gives the engineer's reason) ·
`Deferred` (to Future Iterations or Open Items) · `Dismissed` (minor, not
taken up).

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

Each stage section has the layout in `briefs/challenge.md`. When a challenge
is resolved, edit its two lines:

```markdown
- **Outcome:** Accepted
- **Resolution:** <date>: R4 reworded to cover a repeated trigger; new R12.
```
