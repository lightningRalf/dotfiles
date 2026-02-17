---
description: Fast workspace census for folder-of-repos (counts, branches, dirty state) with no deep tree noise
---
Run a fast workspace census for `${1:-.}`.

## Protocol
1. Detect workspace groups among: `agents core holdingco softwareco`.
2. Enumerate git repos (git roots only):
   - Prefer: `~/.pi/agent/scripts/preflight-repo-census.sh <scope>`
   - Fallback: `find <group-path> -mindepth 1 -maxdepth 5 -type d -name .git -printf '%h\n' | sort`
3. For each repo report:
   - relative path
   - current branch
   - dirty flag (`*` if changes present)
4. Summarize:
   - repo count per group
   - total repos
   - dirty repos
5. Recommend top 2 repos to inspect next based on `${@:2}` objective (if provided).

## Rules
- No deep tree unless explicitly requested.
- Keep output compact and structured.
- Do not modify files in this command.
