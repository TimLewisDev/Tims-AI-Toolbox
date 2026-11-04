## Requirements — challenged 2026-11-03 @ `abc1234`

**Target:** Ch - Comprehensive Tech Plan, ## Requirements · **Lens:** challenge-lens.md ·
**Found:** 1 blocking, 1 significant, 1 minor

### CH1 — A repeated trigger is not covered
- **Severity:** blocking · **Target:** R2
- **Assumption attacked:** The save runs once per change.
- **Why it may be wrong:** The handler is registered twice when the panel
  is reopened, so the save can run twice for one change.
- **Evidence:** `src/store.sh:2` @ `abc1234`
- **Question for the engineer:** Must a second save for the same change be a no-op?
- **Outcome:** Open
- **Resolution:** —

### CH2 — Success is not observable
- **Severity:** significant · **Target:** R3 | R4
- **Assumption attacked:** The user can tell the save worked.
- **Why it may be wrong:** Nothing is shown on success.
- **Evidence:** "the panel closes" (Familiarisation, How it works today)
- **Question for the engineer:** What does the user see when it works?
- **Outcome:** Open
- **Resolution:** —

### CH3 — Wording of R1
- **Severity:** minor · **Target:** R1
- **Assumption attacked:** "Quickly" is measurable.
- **Why it may be wrong:** No number is given.
- **Evidence:** "saves quickly" (Plan, R1)
- **Question for the engineer:** Is there a time limit?
- **Outcome:** Open
- **Resolution:** —

**Lens points with nothing serious:** 3, 5

<!-- tt:end -->
