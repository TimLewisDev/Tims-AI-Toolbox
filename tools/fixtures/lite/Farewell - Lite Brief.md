# Farewell: Lite Brief

- **Revision:** 1
- **Repo:** `REPO` · base `main` · working branch `feature/farewell`
- **Build check:** `bash build.sh`

## Goal
Print a farewell next to the greeting, so people leaving the tool are told goodbye the same way they are welcomed.

## Acceptance
- **A1** Running the farewell prints "goodbye".
- **A2** The farewell looks right in the tool.

## How it works today
The greeting is one line of shell (`src/greet.sh:1`). Nothing else prints text on exit.

## The change
- Add `src/farewell.sh`, copying the greeting's shape (chosen by the engineer).

## Not in scope
- Localising either message.

## Open items
None.

## Work Units
| ID | After this unit you can… | Tasks | Validated by | Depends on |
|---|---|---|---|---|
| WU1 | Say goodbye | T01, T02 | Agent + Engineer | — |

## Task Map
| ID | Task | Executor | Depends on | Work unit |
|---|---|---|---|---|
| T01 | Add the farewell | Agent | — | WU1 |
| T02 | Look at the farewell in the tool | Engineer | T01 | WU1 |

## WU1 — Say goodbye

**In plain English:** Leaving the tool now prints a goodbye, like the greeting does on arrival.

| | |
|---|---|
| **Tasks** | T01, T02 |
| **Depends on** | — |
| **Validated by** | Agent + Engineer |

**Validation**
- [ ] It compiles (Agent)
- [ ] The farewell prints "goodbye" (A1) (Agent)
- [ ] The farewell looks right in the tool (A2) (Engineer)

**How to validate**

```checks
1 | ok | bash build.sh
2 | nonempty | bash src/farewell.sh
```

- Engineer (read out inline at validation time):
  1. Open the tool and choose Quit → expect "goodbye" in the same colour as the greeting.

### T01 — Add the farewell

**In plain English:** Adds the goodbye message.

| | |
|---|---|
| **Executor** | Agent |
| **Work unit** | WU1 |
| **Depends on** | — |

**Goal:** Add a script that prints the farewell.

**Read first**
- Precedent: `src/greet.sh:1`, for the shape to copy.

**Files** (nothing outside this list)
- new `src/farewell.sh`: prints the farewell

**Steps**
1. Write `src/farewell.sh` so it prints `goodbye`, in the same style as `src/greet.sh`.

**Not in this task**
- Wiring the farewell into the tool (the next task checks it there).

**Validated in:** WU1, checks 1 and 2.

### T02 — Look at the farewell in the tool

**In plain English:** Someone opens the tool and looks at the goodbye.

| | |
|---|---|
| **Executor** | Engineer |
| **Work unit** | WU1 |
| **Depends on** | T01 |

**Goal:** Confirm the farewell shows in the tool.

**Steps**
1. Open the tool and choose Quit.
2. Check that "goodbye" appears.

**Validated in:** WU1, check 3.
