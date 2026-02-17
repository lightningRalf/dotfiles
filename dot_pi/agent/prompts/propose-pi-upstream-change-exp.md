---
description: Draft an RFC-style upstream pi proposal with options analysis, rollout plan, and submission-ready issue body
---
You are writing an RFC-style upstream proposal for pi-mono / pi-coding-agent maintainers.

Your goal: produce a technically deep proposal that still stays actionable.

## Inputs

Change request:
$1

Observed pain, workaround, or limitation:
$2

Additional context (API ideas, compatibility constraints, code pointers, links):
${@:3}

## Required workflow

- Start from concrete current behavior and real pain.
- Separate facts from assumptions.
- Propose an additive minimal core first, then optional extensions.
- Include alternatives and explicit trade-offs.
- Include rollout/migration/testing strategy.
- Keep compatibility constraints explicit.

## Output format (exact sections)

## A) Executive summary
- 5-8 bullet points: problem, proposed change, expected impact, migration risk.

## B) Current state and pain profile
- Current behavior:
  - ...
- Limitation(s):
  - ...
- Workaround(s) in the wild:
  - ...
- Why workaround is insufficient:
  - ...

## C) Problem statement
- In-scope problem:
  - ...
- Out-of-scope / non-goals:
  - ...
- Success criteria:
  - ...

## D) Design constraints
- Compatibility constraints:
  - ...
- Operational constraints:
  - ...
- Security/safety constraints:
  - ...

## E) Proposed solution
- Core proposal (MVP):
  - ...
- Optional extensions:
  - ...

## F) API proposal (typed)
Provide concise TypeScript-style snippets.

```ts
// proposed API/types
```

## G) Alternatives and trade-offs
Provide at least 3 alternatives.

| Option | Description | Pros | Cons | Why not chosen |
|---|---|---|---|---|
| A | ... | ... | ... | ... |
| B | ... | ... | ... | ... |
| C | ... | ... | ... | ... |

## H) Rollout and migration plan
- Rollout phases:
  - phase 1: ...
  - phase 2: ...
- Migration strategy for existing extensions/templates:
  - ...
- Backward compatibility guarantees:
  - ...

## I) Validation plan
- Unit tests:
  - ...
- Integration tests:
  - ...
- Docs updates:
  - ...
- Failure mode checks:
  - ...

## J) Risks and mitigations
- Risk 1: ... -> mitigation: ...
- Risk 2: ... -> mitigation: ...
- Risk 3: ... -> mitigation: ...

## K) Open questions for maintainers
- Q1: ...
- Q2: ...
- Q3: ...

## L) Copy-paste issue body
Output final issue body ready to submit, with headings:
- What do you want to change?
- Why?
- How? (optional)

Use concise maintainer-facing language.

## M) Optional RFC appendix
Provide only if useful:
- Glossary
- Prior art references
- Pseudocode / implementation sketch
