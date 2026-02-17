---
description: Draft a high-signal upstream pi proposal (issue-ready) from local extension pain points
---
You are writing an upstream proposal for pi-mono / pi-coding-agent maintainers.

Your goal: produce a clear, actionable, low-drama proposal that maintainers can quickly review.

## Inputs

Change request:
$1

Observed pain, workaround, or limitation:
$2

Additional context (API ideas, compatibility constraints, code pointers, links):
${@:3}

## Required workflow

- Start from concrete current behavior and limitations.
- Distinguish extension-local workaround vs native core capability.
- Propose additive, backwards-compatible API first.
- Keep proposal minimal: smallest useful surface.
- Include migration notes and non-goals.

## Output format (exact sections)

## A) Proposal summary
- One paragraph: what should change and why now.

## B) Current behavior and limitation
- Current behavior:
  - ...
- Limitation:
  - ...
- Current workaround and why it is fragile:
  - ...

## C) Requested change
- Primary change:
  - ...
- Optional follow-up changes:
  - ...

## D) Why this matters
- Developer impact:
  - ...
- Reliability/safety impact:
  - ...
- Ecosystem/tooling impact:
  - ...

## E) Proposed API shape
Provide concise TypeScript-style snippets.

```ts
// example signatures / type additions
```

## F) Compatibility and migration
- Backwards compatibility expectations:
  - ...
- Migration path:
  - ...
- No-break guarantee scope:
  - ...

## G) Alternatives considered
- Alternative 1:
  - ...
- Alternative 2:
  - ...
- Why the proposed approach is preferred:
  - ...

## H) Acceptance criteria
- [ ] ...
- [ ] ...
- [ ] ...

## I) Implementation sketch (maintainer-oriented)
- Discovery/parsing layer changes:
  - ...
- API exposure changes:
  - ...
- Tests/docs updates:
  - ...

## J) Copy-paste issue body
Output final issue body ready to submit, with these headings:
- What do you want to change?
- Why?
- How? (optional)

Keep this section concise and submission-ready.
