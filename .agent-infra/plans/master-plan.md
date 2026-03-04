# Master Plan

**Project:** [Project Name]
**Created:** [timestamp]
**Status:** planning | active | complete
**Teams:** [number of active teams]
**Owner:** Orchestrator

---

## Project Goal
[What we're building and why — 2-3 sentences]

## Plans Overview

| # | Plan | Status | Team | File Scope | Depends On |
|---|------|--------|------|------------|------------|
| 1 | [Plan name] | pending / active / complete | — | `src/area/*` | — |
| 2 | [Plan name] | pending / active / complete | — | `src/other/*` | — |
| 3 | [Plan name] | blocked | — | `src/area/*` | Plan 1 |

## Dependency Rules
- Plans sharing file scope MUST run sequentially (never parallel)
- Plans with non-overlapping file scopes CAN run in parallel on separate teams
- When a plan completes, check if any blocked plans are now unblocked

## File Scope Map
Maps which plans touch which areas — used to determine safe parallelism.

```
src/area-1/     → Plan 1, Plan 3 (sequential — same files)
src/area-2/     → Plan 2 (independent — can parallel with Plan 1)
src/area-3/     → Plan 4 (independent)
```

## Team Assignments
- **Team 1:** Plan 1 → then Plan 3 (sequential, shared scope)
- **Team 2:** Plan 2 → then Plan 4 (sequential by availability)

## Completed Plans
[None yet]
