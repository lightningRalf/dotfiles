---
description: Progressive-disclosure workspace preflight with expert triad, Eisenhower-3D prioritization, HTN plan, and immediate execution
---
You are running a high-signal preflight.

Goal:
1) understand the workspace fast (without token flood),
2) synthesize feedback from 3 expert lenses,
3) produce at least 10 concrete suggestions,
4) prioritize with Eisenhower-3D,
5) create HTN plan,
6) implement top tasks now.

Inputs:
- Scope path: `${1:-.}`
- Optional objective/context: `${@:2}`

## Hard constraints
- Progressive disclosure only. Start shallow, go deeper only where needed.
- Avoid broad deep trees by default.
- Respect repo policies and AGENTS.md files.
- Ask one concise clarification question only if objective is ambiguous.
- No destructive git actions.

## Phase A — Discovery (progressive)
1. Verify context
   - `pwd`
   - `git rev-parse --show-toplevel || true`
2. Determine if this is a folder-of-repos workspace (e.g. `agents/core/holdingco/softwareco`).
3. Repo census first (not deep tree):
   - Prefer deterministic helper: `~/.pi/agent/scripts/preflight-repo-census.sh <scope>`
   - Fallback: `find <scope>/{agents,core,holdingco,softwareco} -mindepth 1 -maxdepth 5 -type d -name .git -printf '%h\n' | sort`
   - summarize counts per group + branch/dirty for each repo.
4. Only then do targeted topology:
   - choose max 1–2 relevant repos,
   - prefer helper: `~/.pi/agent/scripts/preflight-topology.sh <repo-path> 2`
   - fallback: `eza -T -L 2` or `find -maxdepth 2` with noise filters.

## Phase B — Expert triad synthesis
Use these 3 expert lenses:
1. Systems Architect (multi-repo/platform topology)
2. Governance & Security Engineer (consent, policy, supply chain)
3. Solo-Builder Ops Designer (cognitive load, speed, family-safe ops)

From their combined feedback, produce **at least 10 suggestions**.
Each suggestion must be:
- concrete,
- testable,
- tied to a file/script/template/command.

## Phase C — Eisenhower-3D prioritization
For each suggestion assign:
- **I** = Importance (1-5)
- **U** = Urgency (1-5)
- **D** = Difficulty (1-5)

Map to quadrant:
- Q1 Do now: high I, high U
- Q2 Plan: high I, low U
- Q3 Delegate/Automate: low I, high U
- Q4 Drop/Defer: low I, low U

Sort by: quadrant priority (Q1 > Q2 > Q3 > Q4), then lower D first.

## Phase D — HTN planning
Build HTN:
- G0: Preflight operating system for workspace
  - T1: Discovery protocol
  - T2: Prioritization protocol
  - T3: Execution protocol
  - T4: Validation/reporting protocol

Decompose each into leaf tasks with exact commands/file edits.
Mark dependencies and stopping conditions.

## Phase E — Implementation (execute now)
Implement top Q1 tasks (at least 3 tasks) immediately.
- Prefer prompt templates / scripts first (low-friction).
- Validate each task after changes.
- Show changed paths and validation output.

## Output format
1. Discovery summary
2. Expert feedback synthesis
3. 10+ suggestion table with I/U/D + quadrant
4. HTN tree
5. Implementation log (what changed + validation)
6. Next 3 actions
