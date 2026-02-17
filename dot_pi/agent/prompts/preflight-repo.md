---
description: Targeted repo preflight (shallow topology, risks, and immediate action plan)
---
Run targeted preflight for repo path `$1`.
Optional focus: `${@:2}`.

If `$1` is missing: ask one concise question and stop.

## Steps
1. Confirm repo exists and is a git repo.
2. Read AGENTS.md + README first.
3. Show shallow topology only (`depth=2` default), excluding noise (`.git`, `node_modules`, `.venv`, caches, build artifacts).
   - Prefer: `~/.pi/agent/scripts/preflight-topology.sh <repo-path> 2`
   - Fallback: `eza -T -L 2 -I '<noise-glob>'`.
4. Identify:
   - active branch + dirty state
   - critical scripts/workflows
   - current bottlenecks/risks for this repo
5. Produce:
   - 5 actionable improvements
   - mini Eisenhower-3D table (I/U/D)
   - mini HTN (goal -> tasks -> leaf tasks)
6. Implement the top 1–2 leaf tasks now and validate.

## Output format
- Repo snapshot
- Risk/opportunity list
- Prioritized actions
- Implementation log
