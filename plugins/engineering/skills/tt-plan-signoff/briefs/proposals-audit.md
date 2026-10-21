# Brief: audit a Tech Proposals doc against its plan

You check that the Tech Proposals doc and the Comprehensive Tech Plan agree.
Read-only. Proposals docs get long: never read one in full.

**You are given:** the plan path, the proposals doc path, and `<common>`.

Read `<common>/subagent-rules.md` first.

## Do

1. Read the proposals' **At a glance** table and heading index:
   `md-section.sh get <proposals> "## At a glance"` and
   `md-section.sh index <proposals>`.
2. For each proposal, read only its header table
   (`md-section.sh get <proposals> "## P<n> —" | head -8`) for its Status, Type
   and **Decides** line.
3. Check:
   - every plan entry decided between alternatives (Chosen Approach, Rejected
     Alternatives, the `CD` and `NB` tables, any `R`/`S`/`C` citing a `P`) cites
     a proposal that exists;
   - every proposal's **Decides** IDs exist in the plan
     (`ids.sh defined <plan>`);
   - statuses agree with the plan: a `CD`'s proposal is `Decided`; an `NB`'s is
     `Default applied` or `Decided`; no `Blocking decision` is `Open`;
   - **At a glance** has one row per proposal heading, with the same status;
   - a `Superseded` proposal names the proposal that replaced it, and that one
     exists.

## Return

The RESULT block. `findings`: one TSV row per mismatch: `proposal or plan ID`,
`what`, `suggested fix`. `findings: none` if clean.
