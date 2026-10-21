# Selective project knowledge

The toolbox has two information layers:

- **Mandatory rules** are loaded explicitly by the skill that owns the
  procedure. They contain gates, authority order, escalation, state ownership
  and safety rules. Retrieval must never be the only way to obtain them.
- **Knowledge references** are indexed with scope and topic metadata and are
  loaded only when the current skill declares a matching need.

The project profile is a router, not an authority. It records where relevant
facts may be found and when the profile was generated. Skills must read the
source document when a fact affects a decision.

## Knowledge metadata

Reference Markdown may start with a small YAML-like block:

```yaml
---
kind: knowledge
scope: review
topics: [unity, csharp, performance]
triggers: [unity, csharp, MonoBehaviour]
load: whole
---
```

`scope` is the workflow area (`guide`, `planning`, `breakdown`, `execute`,
`review`, or `general`). `topics` and `triggers` are comma-separated routing
terms. `load` is `section` or `whole`; section loading is preferred.

The index format is tab-separated:

```text
path  scope  topics  triggers  load  source_hash
```

Paths are relative to the repository root. Unknown or malformed metadata is
reported and omitted from automatic retrieval.

## Retrieval contract

An invocation should request:

```text
knowledge.sh get <index> <scope> [topic ...]
```

The command returns matching source paths and metadata, not full document
content. The caller then loads only the named section(s), using `md-section.sh`
when the source declares section loading. A caller may request `--all` only
for a small, explicitly relevant source.

The initial budget is the project profile plus at most two optional references.
When no match exists, the skill reports the miss and reads the authoritative
source directly if it knows the path.

## Cache and freshness

Machine-local state lives under `~/.claude/tt-projects/<project-key>/`:

- `profile.md`: compact routing facts;
- `knowledge.tsv`: the indexed references;
- `state.tsv`: input hashes and the generation revision;
- `retrieval.log`: compact retrieval trace.

The cache is stale when the repository revision, toolbox revision, instruction
files or detected manifests change. A stale cache may still be used for
orientation, but skills must say so and refresh before relying on its facts.
