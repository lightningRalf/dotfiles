---
description: Prioritize any backlog with Eisenhower-3D and convert into executable HTN plan
---
Use this for the current backlog/context: `$@`

## Method
1. Extract candidate tasks (minimum 8).
2. Score each task:
   - I (Importance 1-5)
   - U (Urgency 1-5)
   - D (Difficulty 1-5)
3. Assign quadrant:
   - Q1 Do now (high I/high U)
   - Q2 Plan (high I/low U)
   - Q3 Delegate/Automate (low I/high U)
   - Q4 Defer (low I/low U)
4. Convert top Q1+Q2 tasks into HTN:
   - G0 -> Tn -> leaf actions
   - each leaf includes exact command or file change
   - include dependencies and validation checks
5. Execute top feasible leaf tasks immediately (safe, non-destructive).

## Output
- Scored backlog table
- HTN tree
- Execution log
- Updated next actions
