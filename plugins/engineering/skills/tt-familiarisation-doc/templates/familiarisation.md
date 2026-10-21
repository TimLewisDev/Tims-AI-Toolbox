# Template: Familiarisation doc

A readable account of how the part of the codebase the engineer cares about
works today. It describes; it agrees nothing. The Requirements stage builds on
**How it works today**, **Rules the code imposes** and **Open questions**; the
Scope & Constraints stage reads **Not covered**. Leave out any section with
nothing in it, except **Open questions** and **Not covered** (write "None").

```markdown
<header or tag block matching sibling docs>

# <Topic>: Familiarisation

- **Status:** Written <YYYY-MM-DD> · **Challenged:** not yet (later: <YYYY-MM-DD>, see <Challenges link>)
- **Read at:** `<base>` @ `<short sha>` on <YYYY-MM-DD> (or "working tree, <YYYY-MM-DD>")
- **Purpose:** <change · debug · plan a feature · learn>
- **Focus Log:** `.tt/<Prefix> - Familiarisation/focus-log.md` (working notes; deleted when a plan built on this doc is signed off)
- **Comprehensive Tech Plan:** <link, added when planning starts; omit until then>

> This document describes the code as it is. Nothing in it is an agreed
> requirement or decision.

## The question
<What the engineer set out to understand, in their own words (quote the seed
and the confirmed focus statement).>

## In short
<Three to five plain-English lines: the essence of the answer.>

## How it works today
<A walkthrough of the Focus topics, in the order things happen. Short
paragraphs or numbered steps, each cited `path:line`. A small text diagram
where there is a flow.>

## Key parts
| Part | Role | Where |
|---|---|---|
| <type, module, asset, service> | <one line> | `path:line` |

## Data and contracts
- <state, schema, message, serialised data or API the Focus depends on; who
  reads and writes it>: `path:line`

## Rules the code imposes
- <a condition, ordering, limit, default, ownership rule, or a file that is
  owned by a tool and edited there, not by hand>: `path:line`

## Gotchas
- <something surprising or easy to get wrong>: `path:line`

## Open questions
Seeds for requirements. **Not agreed.**
- <a question the code doesn't answer, or one the engineer raised> (from:
  <topic>)

## Not covered
Looked at and deliberately left out (Parked):
- <topic name>
```
