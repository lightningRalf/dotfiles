---
description: Timeboxed daily preflight (2/5/10 min) with progressive disclosure and next action output
---
Run a timeboxed preflight for `${1:-.}`.
Timebox minutes: `${2:-5}`.
Optional focus: `${@:3}`.

## Flow
1. Repo census only (use `~/.pi/agent/scripts/preflight-repo-census.sh <scope>`).
2. If timebox <= 2: stop at counts + dirty repos + one recommendation.
3. If timebox <= 5: include top 1 repo shallow topology.
4. If timebox > 5: include top 2 repos + quick risk scan.
5. Output exactly:
   - current focus
   - top risk
   - top opportunity
   - next single action

No file modifications in this command.
