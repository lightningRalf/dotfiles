---
description: Governance/security preflight for selected workspace or repo (consent, secrets, supply chain)
---
Run risk preflight for `${1:-.}` with optional focus `${@:2}`.

## Checklist
1. Consent boundary risks (protected paths, core docs, governance docs).
2. Secret exposure risks (env/auth files, logs, tokens).
3. Supply-chain risks (unpinned tooling, network-only bootstrap dependencies).
4. Recursion/drift risks (L0/L1/L2 contract violations where relevant).
5. CI gate risks (missing smoke/full/deep checks, missing hook install path).

## Output
- Risk register table:
  - risk
  - likelihood (1-5)
  - impact (1-5)
  - mitigation
  - owner
- Top 3 immediate mitigations with concrete file/command actions.

Do not execute destructive actions.
