# Ids: Comprehensive Tech Plan

- **Status:** Signed off 2026-10-01 · **Revision:** 1
- **ID key:** `R` Requirements · `A` Chosen Approach · `S` Scope / Non-Goals · `C` Constraints

## Requirements
### Saving
- **R1:** Settings are kept between runs. Writes happen on quit. ^r1
- **R2:** The loader runs once at start, never twice; a second call is a no-op. ^r2
- **R3:** The save path is e.g. the user data folder, whatever the platform calls it, and it
  must exist before the first write is attempted by any caller. ^r3
- **R4 (removed: merged into R2):** Loader retries. ^r4
- **R5:** The greeting is shown. [[Other Doc|link]] and **bold** text with `code`. (P1) ^r5

## Chosen Approach
- **A1:** Store settings in one file per profile (P1) ^a1

## Scope / Non-Goals
**In scope:** R1–R3

**Not in scope:**
- **S1:** Not a settings editor. ^s1
  - Why: out of the first release.

## Constraints
### Performance
- **C1:** Saving takes under 50 ms on the reference device.
- **C2:** No new third-party packages. ^c9

## Resolved Critical Decisions
| # | Decision | Outcome | Proposal |
|---|---|---|---|
| CD1 | Where settings live | One file per profile | P1 |

## Non-Blocking Review Items
| # | Item | Applied in plan | Alternative | Proposal |
|---|---|---|---|---|
| NB1 | File name casing | Lower case | Keep as typed | P2 |

## Implementation Plan

### §1. Settings store
**Done when:**
- It compiles. (R1)
