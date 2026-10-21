# Template: Tech Proposals

The document shell, then one proposal per `## Pn —` section. A new proposal is
written as a part file ending with `<!-- tt:end -->` and appended with
`assemble.sh append`; the compact form drops the option subsections.


````markdown
<header or tag block matching sibling docs>

# <Feature>: Tech Proposals

The options weighed for each decision in this plan, laid out for review. The
decisions are recorded in the <Comprehensive Tech Plan link>; the <Tech Plan
link> summarises them.

- **Last updated:** <YYYY-MM-DD HH:MM>
- **Statuses:** `Open` waiting for a decision · `Default applied` recommendation
  used for now, open for review · `Decided` · `Superseded` replaced by a later
  proposal

## At a glance
| ID | Question | Type | Status | Recommended | Chosen |
|---|---|---|---|---|---|
| P1 | <question> | Approach | Decided | A: <title> | A: <title> |

---

## P1 — <the question, phrased as a question>

| | |
|---|---|
| **Status** | Open · Default applied · Decided <YYYY-MM-DD> · Superseded by Pn (<YYYY-MM-DD>) |
| **Type** | Approach · Requirement or scope · Blocking decision · Review item |
| **Decides** | <IDs in the comprehensive plan, linked> |

### The question
<2–4 plain sentences: what has to be decided, why now, and what depends on it.>

### Options at a glance
| | A: <title> (Recommended) | B: <title> | C: <title> |
|---|---|---|---|
| **In one line** | | | |
| **Effort / churn** | Small · Medium · Large | | |
| **Main benefit** | | | |
| **Main risk** | | | |
| **Fits the codebase** | <precedent, or "new pattern"> | | |

### Option A — <title> (Recommended)
**What it means.** <2–3 sentences.>

**How it would be used.** <1–3 sentences or a short numbered flow.>

**Benefits**
- <benefit>

**Risks / costs**
- <risk>

**Repository impact**
- **Systems and files:** <what changes>
- **Ownership:** <who owns what afterwards>
- **Runtime:** <effect on builds and runtime, or "none">

**Example** <only if it makes the option clearer>
```csharp
<short snippet>
```

### Option B — <title>
<same headings as Option A>

### Recommendation
<Option A, because … 2–4 sentences. Prefer repository consistency and minimal
churn.>

### Decision
<Empty while Open.>
- **Chosen:** Option <X>: <title>
- **By / when:** <engineer>, <YYYY-MM-DD>
- **Why:** <reason>
- **Not chosen:** <B: one-line reason> · <C: one-line reason>

<For Default applied: "**Applied for now:** Option A (the recommendation). Open
for review.">
````
