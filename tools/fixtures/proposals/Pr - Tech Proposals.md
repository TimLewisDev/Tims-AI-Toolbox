# Pr: Tech Proposals

The options weighed for each decision in this plan, laid out for review. The
decisions are recorded in the [Comprehensive Tech Plan](<Pr - Comprehensive Tech Plan.md>).

- **Last updated:** 2026-11-01 10:00
- **Statuses:** `Open` waiting for a decision · `Default applied` recommendation
  used for now, open for review · `Decided` · `Superseded` replaced by a later
  proposal

## At a glance
| ID | Question | Type | Status | Recommended | Chosen |
|---|---|---|---|---|---|
| P1 | How is the save made safe? | Approach | Decided | A: Write then rename | A: Write then rename |

---

## P1 — How is the save made safe?

| | |
|---|---|
| **Status** | Decided 2026-11-01 |
| **Type** | Approach |
| **Decides** | A1 |

### The question
A save can be cut off half way. How should the file be written so that a crash
never leaves half a document?

### Options at a glance
| | A: Write then rename (Recommended) (Chosen) | B: Write in place |
|---|---|---|
| **In one line** | Write a temp file, then rename it over the old one | Overwrite the file directly |
| **Effort / churn** | Small | Small |
| **Main benefit** | Never half a file | Simplest |
| **Main risk** | A rename across drives | A crash loses the file |

### Option A — Write then rename (Recommended) (Chosen)
**What it means.** The writer writes beside the file and renames.

### Option B — Write in place
**What it means.** The writer truncates and writes.

### Recommendation
Option A, because the repo already writes this way (`src/store.sh:2`).

### Decision
- **Chosen:** Option A: Write then rename
- **By / when:** the engineer, 2026-11-01
- **Why:** it matches the store
- **Not chosen:** B: a crash loses the file
