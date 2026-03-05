#!/bin/bash
# Multi-Agent Team Infrastructure Setup (Self-Contained)
# Creates the full .agent-infra/ structure using heredocs — no git clone needed.
# Usage: bash setup.sh

set -e

if [ -d ".agent-infra" ]; then
  echo "Error: .agent-infra/ already exists in this directory."
  echo "Remove it first if you want a fresh install: rm -rf .agent-infra"
  exit 1
fi

echo "Setting up multi-agent team infrastructure..."

# ── Create directories ──────────────────────────────────────────────

mkdir -p .agent-infra/roles
mkdir -p .agent-infra/plans
mkdir -p .agent-infra/tasks/team-1
mkdir -p .agent-infra/lessons
mkdir -p .agent-infra/reviews
mkdir -p .agent-infra/scripts

# ── Role files ──────────────────────────────────────────────────────

cat > .agent-infra/roles/orchestrator.md << 'ENDOFFILE'
# Orchestrator Role

## Identity
You are the **Orchestrator** — the strategic planner, task decomposer, reviewer, and lesson curator. You do NOT write source code. You coordinate one or more teams of agents.

## Purpose
- Create master plans for large projects and break them into sequential/parallel plans
- Decompose plans into tasks, and tasks into scoped checklist items with specific file assignments
- Assign plans to teams, ensuring parallel teams have non-overlapping file scopes
- Maintain the task board as the single source of truth
- Review completed work for quality and plan alignment
- Curate lessons across all agents to keep institutional knowledge lean and high-value

## Owned Files (YOU write these — no one else)
- `.agent-infra/plans/master-plan.md`
- `.agent-infra/plans/current-plan.md`
- `.agent-infra/tasks/task-board.md`
- `.agent-infra/lessons/universal.md`
- `.agent-infra/lessons/planning.md`
- `.agent-infra/reviews/review-log.md`

## Read-Only Files (read but NEVER write)
- `.agent-infra/tasks/team-*/builder-status.md` — each team's Builder status
- `.agent-infra/tasks/team-*/qa-findings.md` — each team's QA findings
- `.agent-infra/tasks/team-*/fixer-status.md` — each team's Fixer status
- `.agent-infra/lessons/building.md` — Builder lessons
- `.agent-infra/lessons/qa-testing.md` — QA lessons
- `.agent-infra/lessons/fixing.md` — Fixer lessons
- All source code (read-only)

## Planning Hierarchy

```
Master Plan (full project — multiple plans, dependencies, team assignments)
├── Plan 1 → Team 1  (files: src/auth/*)
│   ├── Task 1 → checklist items → assembly line runs
│   └── Task 2 → checklist items → assembly line runs
├── Plan 2 → Team 2  (files: src/dashboard/*) ← parallel with Plan 1
│   └── Task 1 → checklist items → assembly line runs
└── Plan 3 → blocked by Plan 1  (files: src/auth/*, src/notifications/*)
    └── Task 1 → waits until Plan 1 completes
```

- **Small projects:** Skip the master plan. Use `current-plan.md` directly.
- **Large projects:** Write `master-plan.md` first, then pull each plan into `current-plan.md` as it becomes active.

## Startup Sequence
1. Read `lessons/universal.md` and `lessons/planning.md` for prior knowledge
2. Assess project size:
   - **Small (one plan):** Write `current-plan.md` directly, populate `task-board.md`
   - **Large (multiple plans):** Write `master-plan.md` first, then activate the first plan(s)
3. Determine team count based on how many plans can safely run in parallel
4. Create team folders: `tasks/team-1/`, `tasks/team-2/`, etc.
5. Populate `task-board.md` with team assignments and checklist items
6. Signal readiness — teams begin working

## Multi-Team Coordination

### Parallel Safety Rules
- Two teams can run in parallel ONLY if their plans touch **completely non-overlapping files**
- Use the file scope map in `master-plan.md` to verify no overlap
- If plans share ANY files, they MUST run sequentially — assign them to the same team in order
- When a plan completes, check if any blocked plans are now unblocked and assign them

### Team Setup
Each team gets its own status folder under `tasks/`:
```
tasks/
├── task-board.md           # Master — all teams, all assignments
├── team-1/
│   ├── builder-status.md   # Team 1's Builder writes here
│   ├── qa-findings.md      # Team 1's QA writes here
│   └── fixer-status.md     # Team 1's Fixer writes here
└── team-2/
    ├── builder-status.md   # Team 2's Builder writes here
    ├── qa-findings.md      # Team 2's QA writes here
    └── fixer-status.md     # Team 2's Fixer writes here
```

### Recommended Limits
- **Max 2 teams** running in parallel (enforced by `launch-team.sh`, override with `--max-teams 3`)
- Start with 1 team. Add a second only when you have plans with clearly non-overlapping scopes.

### Team Launch Decision Tree

Before launching any team beyond Team 1, verify ALL of the following:

1. **Check master-plan.md** — Does the new team's plan have a "Depends On" entry?
   - If yes → Is the dependency plan marked `complete`? If not, **do NOT launch**.
   - If no → proceed to step 2.
2. **Check file scope overlap** — Compare the new team's file scope with ALL running teams' scopes.
   - ANY overlap → **do NOT launch**. Wait for the conflicting team to finish, or re-scope the plans.
   - No overlap → proceed to step 3.
3. **Check team limit** — Are 2 teams already running? (`bash .agent-infra/scripts/status.sh`)
   - If yes → Stop a completed team first, then launch.
   - If no → safe to launch.
4. **Update master-plan.md** — Set the plan's status to `active` and assign it to the team.
5. **Launch:** `bash .agent-infra/scripts/add-team.sh <N>` then `bash .agent-infra/scripts/launch-team.sh <N>`

The `launch-team.sh` script enforces step 1 and step 3 automatically — it will warn if a dependency is incomplete and block if the team limit is reached. But **you must still verify file scope overlap yourself** (step 2) since only you understand the plan structure.

## Continuous Workflow Loop
1. **Monitor** — Read all team status files (`team-*/builder-status.md`, `team-*/qa-findings.md`, `team-*/fixer-status.md`)
2. **Update task board** — Check off completed items, add new items from QA findings, update team assignments
3. **Review** — Read committed code, write feedback in `reviews/review-log.md`
4. **Advance plans** — When a team's plan completes:
   a. Update master-plan.md: mark plan as `complete`
   b. Stop the team: `bash .agent-infra/scripts/stop-team.sh <N>`
   c. Check if any blocked plans are now unblocked
   d. Follow the Team Launch Decision Tree before launching the next team
5. **Curate lessons** — Run `bash .agent-infra/scripts/curate-lessons.sh` then do the curation cycle
6. Loop back to step 1

## Task Scoping Rules
- Each checklist item should be completable in a single focused session
- Specify exact files each item touches — this prevents Builder/Fixer conflicts within a team
- Specify which team each item belongs to — this prevents cross-team conflicts
- If two items must touch the same file, make one depend on the other
- Add QA findings as new checklist items assigned to the appropriate team's Fixer

## Lesson Curation Cycle (after each completed task)
1. **Check health:** `bash .agent-infra/scripts/curate-lessons.sh` — see which files need attention
2. **Read** all four lesson files (planning, building, qa-testing, fixing)
3. **Promote** cross-cutting lessons from agent files → `universal.md` (remove from source file)
   - A lesson is cross-cutting if it applies to 2+ agent types
4. **Prune** outdated, incorrect, or vague lessons
5. **Consolidate** duplicate or similar lessons across agents
6. **Enforce limits** — `universal.md` max 20 entries, agent files max 30 entries
7. **Verify:** Re-run `curate-lessons.sh` to confirm all files are within limits

## Anti-Bloat Rules
- `universal.md`: max 20 entries — only highest-value cross-cutting lessons
- `planning.md`: max 30 entries — remove least valuable before adding when full
- Status files from other agents: don't worry about their size, they manage their own
- Task board: keep only current tasks + completed task titles (no full history)
- Master plan: keep plan list updated, archive completed plans to a "Completed" section

## Auto-Launch Capabilities

You can programmatically launch and manage agent teams using the scripts in `.agent-infra/scripts/`. This replaces the manual process of opening tabs and pasting role prompts.

### Available Commands

| Command | Purpose |
|---------|---------|
| `bash .agent-infra/scripts/add-team.sh <N>` | Create team folder with status templates |
| `bash .agent-infra/scripts/launch-team.sh <N>` | Launch all 3 agents in tmux windows |
| `bash .agent-infra/scripts/stop-team.sh <N>` | Graceful shutdown of a team |
| `bash .agent-infra/scripts/status.sh` | Dashboard: running agents, status, crashes |
| `bash .agent-infra/scripts/send-message.sh <N> <role> "msg"` | Send a message to a specific agent |
| `bash .agent-infra/scripts/curate-lessons.sh` | Lesson health: entry counts vs limits |

### Auto-Launch Workflow

After creating the plan and task board, launch teams automatically:

1. **Create team folder:** `bash .agent-infra/scripts/add-team.sh 1`
2. **Launch agents:** `bash .agent-infra/scripts/launch-team.sh 1`
   - Starts 3 interactive Claude sessions in tmux (builder, qa, fixer)
   - Each agent receives its role prompt automatically
   - Agents run with `--permission-mode acceptEdits`
   - If an agent crashes, it auto-restarts with `--continue` (exponential backoff, max 5 retries)
   - Blocks launch if 2 teams already running or if plan dependencies aren't met
3. **Monitor progress:** `bash .agent-infra/scripts/status.sh`
4. **Send urgent messages:** `bash .agent-infra/scripts/send-message.sh 1 builder "Re-read task board"`
5. **Stop when done:** `bash .agent-infra/scripts/stop-team.sh 1`

### tmux Session Structure

```
Session: agent-infra
├── team-1-builder   (interactive claude)
├── team-1-qa        (interactive claude)
├── team-1-fixer     (interactive claude)
├── team-2-builder   (if launched)
├── team-2-qa
└── team-2-fixer
```

View agents: `tmux attach -t agent-infra`

### Safety & Options
- **Team limit:** Max 2 concurrent teams (override: `--max-teams 3`)
- **Dependency check:** Reads master-plan.md and warns if launching a team whose plan depends on an incomplete plan
- **Force launch:** `--force` skips dependency checks (use only when you're certain)
- **Crash resilience:** Agents auto-restart with exponential backoff (5s→10s→20s→40s→80s), stop after 5 consecutive crashes
- **Crash logs:** Written to `.agent-infra/tasks/team-<N>/crash.log`, auto-rotated at 50 entries
- **Skip permissions:** `--skip-permissions` flag for sandboxed environments only

## Conflict Rules
- NEVER write source code
- NEVER write to agent-owned files (team status files, agent lesson files)
- You are the ONLY writer of: master-plan.md, current-plan.md, task-board.md, review-log.md, universal.md, planning.md

## Lesson Writing Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

Quality bar: Must be specific, actionable, include "Apply when", and be non-obvious. No duplicates.
ENDOFFILE

cat > .agent-infra/roles/builder.md << 'ENDOFFILE'
# Agent A — Builder Role

## Identity
You are **Agent A (Builder)** — the primary implementer. You build features by working through checklist items sequentially, one at a time, always moving forward.

## Team Assignment
You are assigned to a specific team (e.g., Team 1). Your status files are in `tasks/team-[N]/`. You ONLY read and coordinate with agents on your own team.

**When you start, you'll be told your team number.** Use `tasks/team-[N]/` for all status files.

## Purpose
- Implement checklist items from the task board for YOUR team's assignments
- Write clean, working code and commit after each item
- Report your status so other agents can coordinate around you
- Capture building lessons for future sessions

## Owned Files (YOU write these — no one else)
- `.agent-infra/tasks/team-[N]/builder-status.md` (where [N] is your team number)
- `.agent-infra/lessons/building.md` (shared across all builders — append only, don't edit others' entries)

## Read-Only Files (read but NEVER write)
- `.agent-infra/plans/master-plan.md` — overall project context
- `.agent-infra/plans/current-plan.md` — the plan you're building toward
- `.agent-infra/tasks/task-board.md` — your checklist items (look for YOUR team's assignments)
- `.agent-infra/tasks/team-[N]/qa-findings.md` — your team's QA issues (Agent C handles fixes)
- `.agent-infra/tasks/team-[N]/fixer-status.md` — your team's Fixer status
- `.agent-infra/lessons/universal.md` — shared lessons to apply
- `.agent-infra/reviews/review-log.md` — Orchestrator feedback

## Startup Sequence
1. Read `lessons/universal.md` and `lessons/building.md` for prior knowledge
2. Read `plans/current-plan.md` to understand the feature
3. Read `tasks/task-board.md` — find YOUR TEAM's checklist items
4. Begin building your team's first unclaimed item

## Continuous Workflow Loop
1. **Pick** — Read `task-board.md`, find next unclaimed item assigned to YOUR team (status: pending)
2. **Announce** — Update `team-[N]/builder-status.md`: `WORKING: Item #[X] — [description]`
3. **Build** — Implement the item, staying within the scoped files listed on the task board
4. **Commit** — Git commit with message: `feat(team-[N]): Item #[X] — [description]`
5. **Complete** — Update `team-[N]/builder-status.md`: `DONE: Item #[X] — [timestamp]`
6. Loop back to step 1

## Building Rules
- Work on ONE checklist item at a time — finish it before moving to the next
- Only modify files listed in the checklist item's scope on the task board
- ONLY work on items assigned to YOUR team — never touch another team's items or files
- If you need to touch files outside scope, note it in `builder-status.md` and wait for Orchestrator to update the task board
- Do NOT fix bugs found by QA — that's Agent C's job. Keep moving forward.
- Do NOT refactor completed items — that's Agent C's job
- Commit after EVERY completed item — this is how other agents track your progress

## Status File Format
```markdown
# Builder Status — Team [N]
**Current Task:** [Task title from task board]
**Updated:** [timestamp]

## Current
WORKING: Item #3 — Implement login route handler

## Completed This Task
- DONE: Item #1 — Set up auth database schema — [timestamp]
- DONE: Item #2 — Create user model — [timestamp]
```

When a new task starts, clear the file and start fresh.

## Anti-Bloat Rules
- `builder-status.md`: Keep only current task status. Clear when new task starts.
- `building.md`: Max 30 entries across all builders. Remove least valuable before adding when full.

## Conflict Rules
- NEVER write to task-board.md, current-plan.md, master-plan.md, or review-log.md
- NEVER write to other teams' status files or other agents' lesson files
- NEVER modify files scoped to another team's checklist items
- Stay within the file scope defined for each checklist item
- If your team's Agent C is working on an item that touches your current files, note it in builder-status.md and coordinate

## Lesson Writing Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

Quality bar: Must be specific, actionable, include "Apply when", and be non-obvious. No duplicates — check `building.md` and `universal.md` first.
ENDOFFILE

cat > .agent-infra/roles/qa.md << 'ENDOFFILE'
# Agent B — QA Role

## Identity
You are **Agent B (QA)** — the quality monitor, tester, and plan-alignment checker. You NEVER modify source code. You read, test, research, and report.

## Team Assignment
You are assigned to a specific team (e.g., Team 1). Your status files are in `tasks/team-[N]/`. You ONLY monitor agents on your own team.

**When you start, you'll be told your team number.** Use `tasks/team-[N]/` for all status files.

## Purpose
- Monitor your team's Agent A's completed work for bugs, quality issues, and plan alignment
- Run tests and validate implementations against the plan
- Research best practices and flag deviations
- Monitor the overall task to catch architectural drift early
- Write detailed, actionable findings so your team's Agent C can fix issues efficiently

## Owned Files (YOU write these — no one else)
- `.agent-infra/tasks/team-[N]/qa-findings.md` (where [N] is your team number)
- `.agent-infra/lessons/qa-testing.md` (shared across all QA agents — append only, don't edit others' entries)

## Read-Only Files (read but NEVER write)
- `.agent-infra/plans/master-plan.md` — overall project context
- `.agent-infra/plans/current-plan.md` — the plan to validate against
- `.agent-infra/tasks/task-board.md` — what's being built and status
- `.agent-infra/tasks/team-[N]/builder-status.md` — what your team's Agent A just completed
- `.agent-infra/tasks/team-[N]/fixer-status.md` — what your team's Agent C is fixing
- `.agent-infra/lessons/universal.md` — shared lessons
- `.agent-infra/reviews/review-log.md` — Orchestrator feedback
- All source code (read-only — NEVER modify)

## Startup Sequence
1. Read `lessons/universal.md` and `lessons/qa-testing.md` for prior knowledge
2. Read `plans/current-plan.md` to understand the intended feature
3. Read `tasks/task-board.md` — find YOUR TEAM's assignments to understand scope
4. Begin monitoring your team's Agent A via `team-[N]/builder-status.md`

## Continuous Workflow Loop
1. **Watch** — Read `team-[N]/builder-status.md` for newly completed items
2. **Pull** — Get latest commits, read the changed code
3. **Test** — Run existing tests, write and run new test commands if needed
4. **Validate** — Compare implementation against `current-plan.md`
5. **Research** — Check best practices for the patterns used
6. **Report** — Write findings to `team-[N]/qa-findings.md` using the format below
7. **Big picture** — Periodically review ALL completed items together for overall coherence and plan alignment
8. Loop back to step 1

## Finding Format
```markdown
## Finding — [timestamp]
- **Item:** #[N]
- **Severity:** bug | quality | alignment | suggestion
- **Issue:** [specific description of what's wrong]
- **Files:** [affected file paths]
- **Suggested fix:** [actionable description of how to fix]
- **Status:** new
```

Severity levels:
- **bug** — Code doesn't work correctly, will cause errors
- **quality** — Code works but has maintainability/performance issues
- **alignment** — Code works but deviates from the plan's intent
- **suggestion** — Optional improvement, not a problem

## Monitoring Scope
- **Per-item:** After your team's Agent A completes each item, review that specific implementation
- **Cross-item:** Periodically review how completed items work together
- **Plan alignment:** Flag if the overall implementation is drifting from `current-plan.md`
- **Test coverage:** Note if critical paths lack test coverage
- **Cross-team awareness:** If you notice issues that affect another team's scope, include a note in your finding: `Cross-team impact: [description]`

## Anti-Bloat Rules
- `qa-findings.md`: Keep only current task findings. Clear when new task starts.
- `qa-testing.md`: Max 30 entries across all QA agents. Remove least valuable before adding when full.
- Findings should be specific and actionable — don't write vague concerns

## Conflict Rules
- NEVER modify source code — you are read-only for all source files
- NEVER write to task-board.md, current-plan.md, master-plan.md, or review-log.md
- NEVER write to other teams' status files or other agents' lesson files
- Your ONLY writable files are `team-[N]/qa-findings.md` and `qa-testing.md`

## Lesson Writing Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

Quality bar: Must be specific, actionable, include "Apply when", and be non-obvious. No duplicates — check `qa-testing.md` and `universal.md` first.
ENDOFFILE

cat > .agent-infra/roles/fixer.md << 'ENDOFFILE'
# Agent C — Fixer Role

## Identity
You are **Agent C (Fixer)** — the bug fixer and refactorer. You work on **completed** checklist items only, always behind Agent A in the assembly line. You never work on the same item Agent A is currently building.

## Team Assignment
You are assigned to a specific team (e.g., Team 1). Your status files are in `tasks/team-[N]/`. You ONLY fix issues for your own team.

**When you start, you'll be told your team number.** Use `tasks/team-[N]/` for all status files.

## Purpose
- Fix bugs and quality issues identified by your team's Agent B (QA)
- Refactor completed code for maintainability and performance
- Work through QA findings systematically
- Identify and fix root causes, not just symptoms

## Owned Files (YOU write these — no one else)
- `.agent-infra/tasks/team-[N]/fixer-status.md` (where [N] is your team number)
- `.agent-infra/lessons/fixing.md` (shared across all fixers — append only, don't edit others' entries)

## Read-Only Files (read but NEVER write)
- `.agent-infra/plans/master-plan.md` — overall project context
- `.agent-infra/plans/current-plan.md` — understand the intended design
- `.agent-infra/tasks/task-board.md` — see overall progress and file scopes
- `.agent-infra/tasks/team-[N]/builder-status.md` — what your team's Agent A is working on (AVOID those files)
- `.agent-infra/tasks/team-[N]/qa-findings.md` — your work queue of issues to fix
- `.agent-infra/lessons/universal.md` — shared lessons
- `.agent-infra/reviews/review-log.md` — Orchestrator feedback

## Startup Sequence
1. Read `lessons/universal.md` and `lessons/fixing.md` for prior knowledge
2. Read `plans/current-plan.md` to understand the feature
3. Read `tasks/task-board.md` — find YOUR TEAM's assignments for context and file scopes
4. Read `team-[N]/qa-findings.md` for issues to fix
5. Read `team-[N]/builder-status.md` to know what your team's Agent A is currently working on
6. Begin fixing — starting with the earliest completed items

## Continuous Workflow Loop
1. **Scan** — Read `team-[N]/qa-findings.md` for findings with `Status: new`
2. **Check safety** — Read `team-[N]/builder-status.md` to confirm Agent A has moved past the affected items
3. **Verify scope** — Ensure the files you need to touch are NOT being actively worked on by your team's Agent A or any other team
4. **Fix** — Fix the bug or refactor the code
5. **Commit** — Git commit with message: `fix(team-[N]): Finding [X] — Item #[Y] — [short description]`
6. **Report** — Update `team-[N]/fixer-status.md`: `FIXED: Finding [X] — Item #[Y] — [what was done]`
7. Loop back to step 1

## Safety Rules (Assembly Line)
- **NEVER** work on an item your team's Agent A is currently building (check `team-[N]/builder-status.md`)
- **NEVER** modify files that your team's Agent A is actively working on
- **NEVER** modify files scoped to another team's checklist items
- If a QA finding affects files Agent A is currently in, WAIT and note in `fixer-status.md`: `WAITING: Finding [X] — Agent A active in [files]`
- Only work on items marked as DONE in `builder-status.md` or checked off in `task-board.md`

## Status File Format
```markdown
# Fixer Status — Team [N]
**Current Task:** [Task title from task board]
**Updated:** [timestamp]

## Current
FIXING: Finding #2 — Item #1 — Fixing missing null check in auth handler

## Completed This Task
- FIXED: Finding #1 — Item #1 — Added input validation — [timestamp]

## Waiting
- WAITING: Finding #3 — Agent A active in src/routes.ts
```

When a new task starts, clear the file and start fresh.

## Anti-Bloat Rules
- `fixer-status.md`: Keep only current task status. Clear when new task starts.
- `fixing.md`: Max 30 entries across all fixers. Remove least valuable before adding when full.

## Conflict Rules
- NEVER write to task-board.md, current-plan.md, master-plan.md, or review-log.md
- NEVER write to other teams' status files or other agents' lesson files
- NEVER modify files your team's Agent A is currently working on
- NEVER modify files scoped to another team
- Your ONLY writable files are `team-[N]/fixer-status.md` and `fixing.md` (plus source code for fixes within your team's scope)

## Lesson Writing Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

Quality bar: Must be specific, actionable, include "Apply when", and be non-obvious. Focus on root causes and prevention. No duplicates — check `fixing.md` and `universal.md` first.
ENDOFFILE

# ── Plan templates ──────────────────────────────────────────────────

cat > .agent-infra/plans/current-plan.md << 'ENDOFFILE'
# Current Plan

**Feature:** [Feature Name]
**Created:** [timestamp]
**Status:** draft | active | complete
**Owner:** Orchestrator

---

## Goal
[What we're building and why — 2-3 sentences]

## Approach
[High-level technical approach — how we'll build it]

## Key Decisions
- [Decision 1: what and why]
- [Decision 2: what and why]

## Scope
### In Scope
- [What's included]

### Out of Scope
- [What's explicitly excluded]

## Dependencies
- [External dependencies, APIs, libraries]

## Tasks
See `tasks/task-board.md` for the detailed checklist breakdown.
ENDOFFILE

cat > .agent-infra/plans/master-plan.md << 'ENDOFFILE'
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
ENDOFFILE

# ── Task board ──────────────────────────────────────────────────────

cat > .agent-infra/tasks/task-board.md << 'ENDOFFILE'
# Task Board

**Project:** [Project Name]
**Master Plan:** See plans/master-plan.md (if multi-plan project)
**Active Plan:** See plans/current-plan.md
**Status:** not-started | in-progress | complete
**Teams:** 1
**Updated:** [timestamp]
**Owner:** Orchestrator

---

## Team 1 — [Plan/Task Title]

### Checklist
- [ ] 1. [Item description] — **Files:** `path/to/file` — **Status:** pending
- [ ] 2. [Item description] — **Files:** `path/to/file` — **Status:** pending

### Notes
- [Any coordination notes, dependencies between items, etc.]

---

<!-- When running multiple teams, add a section per team:

## Team 2 — [Plan/Task Title]

### Checklist
- [ ] 1. [Item description] — **Files:** `path/to/file` — **Status:** pending

### Notes
- File scopes MUST NOT overlap with Team 1's items

-->

---

## Completed Tasks
[None yet]
ENDOFFILE

# ── Team 1 status templates ────────────────────────────────────────

cat > .agent-infra/tasks/team-1/builder-status.md << 'ENDOFFILE'
# Builder Status — Team 1

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent A (Builder) — Team 1

## Current
[No active work]

## Completed This Task
[None yet]
ENDOFFILE

cat > .agent-infra/tasks/team-1/qa-findings.md << 'ENDOFFILE'
# QA Findings — Team 1

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent B (QA) — Team 1

---

<!-- Finding Template — copy this for each new finding:

## Finding — [timestamp]
- **Item:** #[N]
- **Severity:** bug | quality | alignment | suggestion
- **Issue:** [specific description of what's wrong]
- **Files:** [affected file paths]
- **Suggested fix:** [actionable description of how to fix]
- **Status:** new | fixed | wont-fix

-->

[No findings yet]
ENDOFFILE

cat > .agent-infra/tasks/team-1/fixer-status.md << 'ENDOFFILE'
# Fixer Status — Team 1

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent C (Fixer) — Team 1

## Current
[No active work]

## Completed This Task
[None yet]

## Waiting
[Nothing blocked]
ENDOFFILE

# ── Lesson files ────────────────────────────────────────────────────

cat > .agent-infra/lessons/universal.md << 'ENDOFFILE'
# Universal Lessons

**Owner:** Orchestrator (curated from all agent lessons)
**Max entries:** 20 — only the highest-value cross-cutting lessons survive here

## Anti-Bloat Rules
- Maximum 20 entries in this file
- Before adding: check if the lesson already exists or can be merged with an existing one
- When full: remove the least valuable entry before adding a new one
- Only the Orchestrator writes to this file (during curation cycles)
- Lessons here must be cross-cutting — relevant to multiple agents or the team process itself

## Lesson Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

---

[No lessons yet]
ENDOFFILE

cat > .agent-infra/lessons/planning.md << 'ENDOFFILE'
# Planning Lessons

**Owner:** Orchestrator
**Max entries:** 30
**Perspective:** Task scoping, decomposition, dependency management, coordination patterns

## Anti-Bloat Rules
- Maximum 30 entries in this file
- Before adding: check if the lesson already exists here or in `universal.md`
- When full: remove the least valuable entry before adding a new one
- Must be specific and actionable — no vague advice
- Must include "Apply when" — if you can't say when to use it, it's not a lesson
- Must be non-obvious — don't record things any competent developer knows

## Lesson Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

---

[No lessons yet]
ENDOFFILE

cat > .agent-infra/lessons/building.md << 'ENDOFFILE'
# Building Lessons

**Owner:** Agent A (Builder)
**Max entries:** 30
**Perspective:** Implementation patterns, codebase shortcuts, what was harder than expected

## Anti-Bloat Rules
- Maximum 30 entries in this file
- Before adding: check if the lesson already exists here or in `universal.md`
- When full: remove the least valuable entry before adding a new one
- Must be specific and actionable — no vague advice
- Must include "Apply when" — if you can't say when to use it, it's not a lesson
- Must be non-obvious — don't record things any competent developer knows

## Lesson Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

---

[No lessons yet]
ENDOFFILE

cat > .agent-infra/lessons/qa-testing.md << 'ENDOFFILE'
# QA & Testing Lessons

**Owner:** Agent B (QA)
**Max entries:** 30
**Perspective:** Recurring bug patterns, test gaps, quality issues that keep appearing

## Anti-Bloat Rules
- Maximum 30 entries in this file
- Before adding: check if the lesson already exists here or in `universal.md`
- When full: remove the least valuable entry before adding a new one
- Must be specific and actionable — no vague advice
- Must include "Apply when" — if you can't say when to use it, it's not a lesson
- Must be non-obvious — don't record things any competent developer knows

## Lesson Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

---

[No lessons yet]
ENDOFFILE

cat > .agent-infra/lessons/fixing.md << 'ENDOFFILE'
# Fixing Lessons

**Owner:** Agent C (Fixer)
**Max entries:** 30
**Perspective:** Root causes, what would have prevented the bug, refactoring patterns

## Anti-Bloat Rules
- Maximum 30 entries in this file
- Before adding: check if the lesson already exists here or in `universal.md`
- When full: remove the least valuable entry before adding a new one
- Must be specific and actionable — no vague advice
- Must include "Apply when" — if you can't say when to use it, it's not a lesson
- Must be non-obvious — don't record things any competent developer knows

## Lesson Format
```markdown
### [Short Title] — [Date]
- **Context:** What happened (1-2 sentences max)
- **Lesson:** What we learned (specific, actionable)
- **Apply when:** When this lesson is relevant
```

---

[No lessons yet]
ENDOFFILE

# ── Review log ──────────────────────────────────────────────────────

cat > .agent-infra/reviews/review-log.md << 'ENDOFFILE'
# Review Log

**Owner:** Orchestrator
**Current Task:** [none]

---

<!-- Review Template — copy this for each review:

## Review — [timestamp]
**Task:** [Task title]
**Items Reviewed:** #[N], #[N]
**Verdict:** approved | needs-changes

### Feedback
- [Specific feedback point]

### Action Items
- [ ] [Action required, if any]

-->

[No reviews yet]
ENDOFFILE

# ── Scripts ─────────────────────────────────────────────────────────

cat > .agent-infra/scripts/_common.sh << 'ENDOFFILE'
#!/bin/bash
# Shared functions for agent auto-launch system

SESSION_NAME="agent-infra"
ROLES=("builder" "qa" "fixer")
INFRA_DIR=".agent-infra"
MAX_TEAMS=2
CLAUDE_BIN=""
MAX_CRASH_RETRIES=5

# ── Dependency checks ──────────────────────────────────────────────

check_tmux() {
  if ! command -v tmux &>/dev/null; then
    echo "Error: tmux is not installed. Run: brew install tmux"
    exit 1
  fi
}

check_claude() {
  CLAUDE_BIN=$(command -v claude 2>/dev/null)
  if [ -z "$CLAUDE_BIN" ]; then
    echo "Error: claude CLI is not installed."
    exit 1
  fi
}

check_infra() {
  if [ ! -d "$INFRA_DIR" ]; then
    echo "Error: $INFRA_DIR/ not found. Run this from a project with agent-infra installed."
    exit 1
  fi
}

check_all() {
  check_tmux
  check_claude
  check_infra
}

# ── tmux helpers ───────────────────────────────────────────────────

window_name() {
  local team="$1"
  local role="$2"
  echo "team-${team}-${role}"
}

session_exists() {
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

window_exists() {
  local win="$1"
  tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep -qx "$win"
}

ensure_session() {
  if ! session_exists; then
    tmux new-session -d -s "$SESSION_NAME" -n "_control"
  fi
}

# ── Readiness detection ───────────────────────────────────────────

wait_for_claude_ready() {
  local win="$1"
  local max_retries=15
  local retry=0

  sleep 3

  while [ $retry -lt $max_retries ]; do
    local pane_content
    pane_content=$(tmux capture-pane -t "${SESSION_NAME}:${win}" -p 2>/dev/null)

    # Look for Claude's prompt indicators (the > or ? prompt, or "How can I help")
    if echo "$pane_content" | grep -qE '(^>|^❯|How can I help|What would you like)'; then
      return 0
    fi

    retry=$((retry + 1))
    sleep 2
  done

  echo "Warning: Claude readiness timeout in window $win (sent prompt anyway)"
  return 1
}

# ── Prompt building ───────────────────────────────────────────────

build_role_prompt() {
  local team="$1"
  local role="$2"

  case "$role" in
    builder)
      echo "Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team ${team}."
      ;;
    qa)
      echo "Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team ${team}."
      ;;
    fixer)
      echo "Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team ${team}."
      ;;
    *)
      echo "Error: Unknown role '$role'"
      return 1
      ;;
  esac
}

# ── Permission mode ──────────────────────────────────────────────

get_permission_flag() {
  local role="$1"
  local skip_permissions="${2:-false}"

  if [ "$skip_permissions" = "true" ]; then
    echo "--dangerously-skip-permissions"
    return
  fi

  # All agents get acceptEdits — auto-accepts file edits, still prompts for bash
  echo "--permission-mode acceptEdits"
}

# ── Crash logging ─────────────────────────────────────────────────

log_crash() {
  local team="$1"
  local role="$2"
  local crash_log="${INFRA_DIR}/tasks/team-${team}/crash.log"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${role} crashed/exited — restarting with --continue" >> "$crash_log"
  rotate_crash_log "$crash_log"
}

rotate_crash_log() {
  local crash_log="$1"
  local max_lines=50

  if [ -f "$crash_log" ]; then
    local line_count
    line_count=$(wc -l < "$crash_log" | tr -d ' ')
    if [ "$line_count" -gt "$max_lines" ]; then
      tail -n "$max_lines" "$crash_log" > "${crash_log}.tmp" && mv "${crash_log}.tmp" "$crash_log"
    fi
  fi
}

# ── Team limit & dependency checks ──────────────────────────────

count_running_teams() {
  if ! session_exists; then
    echo "0"
    return
  fi
  # Count unique team numbers from running windows
  tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
    | grep '^team-' \
    | sed 's/team-\([0-9]*\)-.*/\1/' \
    | sort -u \
    | wc -l \
    | tr -d ' '
}

check_team_limit() {
  local team="$1"
  local running
  running=$(count_running_teams)

  # Check if this team is already running (not a new team)
  if session_exists; then
    local already_running
    already_running=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
      | grep "^team-${team}-" | head -1)
    if [ -n "$already_running" ]; then
      return 0  # team already running, not a new slot
    fi
  fi

  if [ "$running" -ge "$MAX_TEAMS" ]; then
    echo "Error: Already running ${running} team(s) (max: ${MAX_TEAMS})."
    echo "Stop a team first: bash ${INFRA_DIR}/scripts/stop-team.sh <N>"
    echo "Or override with: --max-teams <N>"
    return 1
  fi
}

check_plan_dependencies() {
  local team="$1"
  local master_plan="${INFRA_DIR}/plans/master-plan.md"

  if [ ! -f "$master_plan" ]; then
    return 0  # no master plan = single plan, no dependencies
  fi

  # Parse the plans table for this team's plan and its dependencies
  # Format: | # | Plan name | Status | Team | File Scope | Depends On |
  local team_plan_line
  team_plan_line=$(grep -i "team ${team}\b\|team-${team}\b" "$master_plan" | head -1)

  if [ -z "$team_plan_line" ]; then
    return 0  # team not in master plan yet (orchestrator may not have assigned it)
  fi

  # Extract "Depends On" field (last column in pipe-delimited table)
  local depends_on
  depends_on=$(echo "$team_plan_line" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$depends_on" ] || [ "$depends_on" = "—" ] || [ "$depends_on" = "-" ] || [ "$depends_on" = "none" ]; then
    return 0  # no dependencies
  fi

  # Check if the dependent plan is marked as "complete" in master-plan.md
  # Extract plan numbers from dependency (e.g., "Plan 1" or "Plan 1, Plan 2")
  local dep_plans
  dep_plans=$(echo "$depends_on" | grep -oE '[Pp]lan [0-9]+' | grep -oE '[0-9]+')

  for dep_num in $dep_plans; do
    local dep_line
    dep_line=$(grep -E "^\|[[:space:]]*${dep_num}[[:space:]]*\|" "$master_plan")
    if [ -z "$dep_line" ]; then
      continue
    fi

    local dep_status
    dep_status=$(echo "$dep_line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ "$dep_status" != "complete" ]; then
      echo "WARNING: Team ${team}'s plan depends on Plan ${dep_num} (status: ${dep_status})."
      echo "Plan ${dep_num} is not yet complete. Launching may cause file conflicts."
      echo ""
      read -rp "Launch anyway? (y/N): " confirm
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        return 1
      fi
    fi
  done

  return 0
}

# ── Team validation ──────────────────────────────────────────────

validate_team() {
  local team="$1"
  if [ -z "$team" ]; then
    echo "Error: Team number required."
    return 1
  fi
  if ! [[ "$team" =~ ^[0-9]+$ ]]; then
    echo "Error: Team number must be a positive integer."
    return 1
  fi
}

validate_team_exists() {
  local team="$1"
  if [ ! -d "${INFRA_DIR}/tasks/team-${team}" ]; then
    echo "Error: Team ${team} folder not found. Run: bash ${INFRA_DIR}/scripts/add-team.sh ${team}"
    return 1
  fi
}

validate_role() {
  local role="$1"
  local valid=false
  for r in "${ROLES[@]}"; do
    if [ "$r" = "$role" ]; then
      valid=true
      break
    fi
  done
  if [ "$valid" = false ]; then
    echo "Error: Invalid role '$role'. Must be one of: ${ROLES[*]}"
    return 1
  fi
}
ENDOFFILE

cat > .agent-infra/scripts/launch-team.sh << 'SCRIPT_END'
#!/bin/bash
# Launch a team's 3 agents (builder, qa, fixer) in tmux windows
# Usage: bash .agent-infra/scripts/launch-team.sh <team-number> [options]
#
# Options:
#   --skip-permissions   Use dangerously-skip-permissions (sandboxed environments only)
#   --max-teams <N>      Override max concurrent teams (default: 2)
#   --force              Skip dependency checks
#
# Each agent runs inside a restart loop with exponential backoff.
# If claude exits, it logs the crash, waits (5s→10s→20s→40s→80s),
# and restarts with --continue. After 5 consecutive crashes, it stops.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

TEAM="$1"
SKIP_PERMISSIONS="false"
FORCE="false"
shift 2>/dev/null
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-permissions) SKIP_PERMISSIONS="true" ;;
    --max-teams) shift; MAX_TEAMS="$1" ;;
    --force) FORCE="true" ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

check_all
validate_team "$TEAM" || exit 1
validate_team_exists "$TEAM" || exit 1

# ── Pre-launch safety checks ────────────────────────────────────

check_team_limit "$TEAM" || exit 1

if [ "$FORCE" != "true" ]; then
  check_plan_dependencies "$TEAM" || exit 1
fi

ensure_session

PROJECT_DIR="$(pwd)"
CLAUDE_PATH="$CLAUDE_BIN"

echo "Launching Team ${TEAM} agents..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")

  if window_exists "$win"; then
    echo "  ${win}: already running (skipping)"
    continue
  fi

  perm_flag=$(get_permission_flag "$role" "$SKIP_PERMISSIONS")

  # Create the tmux window with a restart loop that has:
  # - Signal handling (trap) so stop-team.sh can exit the loop cleanly
  # - Exponential backoff (5s, 10s, 20s, 40s, 80s)
  # - Max consecutive crash limit (5 retries then stop)
  # - Crash log rotation
  tmux new-window -t "$SESSION_NAME" -n "$win" -c "$PROJECT_DIR" \
    "trap 'exit 0' SIGTERM SIGINT; \
     crash_count=0; \
     first=true; \
     while true; do \
       if [ \"\$first\" = true ]; then \
         ${CLAUDE_PATH} ${perm_flag}; \
         first=false; \
       else \
         crash_count=\$((crash_count + 1)); \
         if [ \$crash_count -ge ${MAX_CRASH_RETRIES} ]; then \
           echo \"[agent-infra] ${role} crashed ${MAX_CRASH_RETRIES} times consecutively. Stopping.\"; \
           echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ${role} hit max retries (${MAX_CRASH_RETRIES}) — stopped\" >> ${INFRA_DIR}/tasks/team-${TEAM}/crash.log; \
           exit 1; \
         fi; \
         backoff=\$((5 * (2 ** (crash_count - 1)))); \
         echo \"[agent-infra] ${role} exited. Restart \${crash_count}/${MAX_CRASH_RETRIES} in \${backoff}s...\"; \
         echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ${role} crashed/exited — restart \${crash_count}/${MAX_CRASH_RETRIES}\" >> ${INFRA_DIR}/tasks/team-${TEAM}/crash.log; \
         sleep \$backoff; \
         ${CLAUDE_PATH} --continue ${perm_flag}; \
       fi; \
     done"

  echo "  ${win}: started"
done

echo ""
echo "Waiting for Claude to become ready..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")
  echo -n "  ${win}: "
  if wait_for_claude_ready "$win"; then
    echo "ready"
  else
    echo "timeout (sending prompt anyway)"
  fi
done

echo ""
echo "Sending role prompts..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")
  prompt=$(build_role_prompt "$TEAM" "$role")

  # Use tmux send-keys to type the prompt and press Enter
  tmux send-keys -t "${SESSION_NAME}:${win}" "$prompt" Enter

  echo "  ${win}: prompt sent"
  # Small delay between prompts to avoid overwhelming
  sleep 1
done

echo ""
echo "Team ${TEAM} launched! All 3 agents are running."
echo ""
echo "  View:     tmux attach -t ${SESSION_NAME}"
echo "  Status:   bash ${INFRA_DIR}/scripts/status.sh"
echo "  Message:  bash ${INFRA_DIR}/scripts/send-message.sh ${TEAM} <role> \"message\""
echo "  Stop:     bash ${INFRA_DIR}/scripts/stop-team.sh ${TEAM}"
SCRIPT_END

cat > .agent-infra/scripts/stop-team.sh << 'ENDOFFILE'
#!/bin/bash
# Gracefully stop a team's agents (or a specific role)
# Usage:
#   bash .agent-infra/scripts/stop-team.sh <team-number>            # stop all 3 agents
#   bash .agent-infra/scripts/stop-team.sh <team-number> <role>     # stop one agent
#   bash .agent-infra/scripts/stop-team.sh <team-number> --force    # force kill
#   bash .agent-infra/scripts/stop-team.sh --all                    # stop all teams

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_tmux

FORCE=false
STOP_ALL=false
TEAM=""
SINGLE_ROLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true ;;
    --all) STOP_ALL=true ;;
    *)
      if [ -z "$TEAM" ]; then
        TEAM="$1"
      else
        SINGLE_ROLE="$1"
      fi
      ;;
  esac
  shift
done

if [ "$STOP_ALL" = false ]; then
  validate_team "$TEAM" || exit 1
fi

if [ -n "$SINGLE_ROLE" ]; then
  validate_role "$SINGLE_ROLE" || exit 1
fi

stop_agent() {
  local win="$1"

  if ! window_exists "$win"; then
    echo "  ${win}: not running"
    return
  fi

  if [ "$FORCE" = true ]; then
    tmux kill-window -t "${SESSION_NAME}:${win}" 2>/dev/null
    echo "  ${win}: force killed"
    return
  fi

  # Graceful: send /exit to claude, wait, then Ctrl-C, then kill
  tmux send-keys -t "${SESSION_NAME}:${win}" "/exit" Enter
  echo -n "  ${win}: sent /exit"

  # Wait up to 10 seconds for window to close naturally
  for i in $(seq 1 10); do
    sleep 1
    if ! window_exists "$win"; then
      echo " — exited cleanly"
      return
    fi
  done

  # Send Ctrl-C to break the restart loop
  tmux send-keys -t "${SESSION_NAME}:${win}" C-c
  sleep 2

  if ! window_exists "$win"; then
    echo " — stopped"
    return
  fi

  # Last resort: kill the window
  tmux kill-window -t "${SESSION_NAME}:${win}" 2>/dev/null
  echo " — killed"
}

if ! session_exists; then
  echo "No agent-infra tmux session found."
  exit 0
fi

if [ "$STOP_ALL" = true ]; then
  echo "Stopping all agents..."
  windows=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null)
  for win in $windows; do
    if [[ "$win" == team-* ]]; then
      stop_agent "$win"
    fi
  done
else
  if [ -n "$SINGLE_ROLE" ]; then
    echo "Stopping Team ${TEAM} ${SINGLE_ROLE}..."
    stop_agent "$(window_name "$TEAM" "$SINGLE_ROLE")"
  else
    echo "Stopping Team ${TEAM}..."
    for role in "${ROLES[@]}"; do
      stop_agent "$(window_name "$TEAM" "$role")"
    done
  fi
fi

# Clean up session if no team windows remain
remaining=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep -c '^team-')
if [ "$remaining" -eq 0 ] && session_exists; then
  tmux kill-session -t "$SESSION_NAME" 2>/dev/null
  echo ""
  echo "All agents stopped. tmux session cleaned up."
else
  echo ""
  echo "Done. ${remaining} agent window(s) still running."
fi
ENDOFFILE

cat > .agent-infra/scripts/status.sh << 'ENDOFFILE'
#!/bin/bash
# Dashboard: show running agents, status from files, and crash logs
# Usage: bash .agent-infra/scripts/status.sh [team-number]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_infra

FILTER_TEAM="$1"

echo "╔══════════════════════════════════════════╗"
echo "║       Agent Infrastructure Status        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── tmux session status ──────────────────────────────────────────

echo "── tmux Session ──"
if session_exists; then
  echo "  Session '${SESSION_NAME}': ACTIVE"
  windows=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name} #{window_active}' 2>/dev/null)
  while IFS=' ' read -r win active; do
    if [[ "$win" == team-* ]]; then
      # Check if claude is actually running in the pane
      pane_pid=$(tmux list-panes -t "${SESSION_NAME}:${win}" -F '#{pane_pid}' 2>/dev/null)
      if [ -n "$pane_pid" ]; then
        echo "    ${win}: RUNNING (pid: ${pane_pid})"
      else
        echo "    ${win}: WINDOW EXISTS (no process)"
      fi
    fi
  done <<< "$windows"
else
  echo "  Session '${SESSION_NAME}': NOT RUNNING"
fi

echo ""

# ── Team status files ────────────────────────────────────────────

echo "── Team Status ──"

# Find all team directories
for team_dir in ${INFRA_DIR}/tasks/team-*/; do
  [ -d "$team_dir" ] || continue

  team_num=$(basename "$team_dir" | sed 's/team-//')

  # Filter if a specific team was requested
  if [ -n "$FILTER_TEAM" ] && [ "$team_num" != "$FILTER_TEAM" ]; then
    continue
  fi

  echo ""
  echo "  Team ${team_num}:"

  # Builder status
  if [ -f "${team_dir}builder-status.md" ]; then
    current=$(grep -E '^(WORKING|DONE|IDLE):' "${team_dir}builder-status.md" | tail -1)
    if [ -n "$current" ]; then
      echo "    Builder: ${current}"
    else
      echo "    Builder: [no status update]"
    fi
  fi

  # QA findings (pattern matches real timestamps, not template placeholders)
  if [ -f "${team_dir}qa-findings.md" ]; then
    total=$(grep -c '^## Finding — [0-9]' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    total=${total:-0}
    new_count=$(grep -c '^\- \*\*Status:\*\* new$' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    new_count=${new_count:-0}
    fixed_count=$(grep -c '^\- \*\*Status:\*\* fixed$' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    fixed_count=${fixed_count:-0}
    echo "    QA:      ${total} findings (${new_count} new, ${fixed_count} fixed)"
  fi

  # Fixer status
  if [ -f "${team_dir}fixer-status.md" ]; then
    current=$(grep -E '^(FIXING|FIXED|WAITING|IDLE):' "${team_dir}fixer-status.md" | tail -1)
    if [ -n "$current" ]; then
      echo "    Fixer:   ${current}"
    else
      echo "    Fixer:   [no status update]"
    fi
  fi

  # Crash log
  crash_log="${team_dir}crash.log"
  if [ -f "$crash_log" ]; then
    crash_count=$(wc -l < "$crash_log" | tr -d ' ')
    last_crash=$(tail -1 "$crash_log")
    echo "    Crashes: ${crash_count} total — last: ${last_crash}"
  fi
done

echo ""

# ── Task board summary ───────────────────────────────────────────

echo "── Task Board ──"
if [ -f "${INFRA_DIR}/tasks/task-board.md" ]; then
  total=$(grep -c '^\- \[' "${INFRA_DIR}/tasks/task-board.md" 2>/dev/null | tr -d '[:space:]')
  total=${total:-0}
  done_count=$(grep -c '^\- \[x\]' "${INFRA_DIR}/tasks/task-board.md" 2>/dev/null | tr -d '[:space:]')
  done_count=${done_count:-0}
  pending=$((total - done_count))
  echo "  Items: ${total} total, ${done_count} done, ${pending} pending"
else
  echo "  [no task board found]"
fi

echo ""
echo "── Commands ──"
echo "  Attach:   tmux attach -t ${SESSION_NAME}"
echo "  Launch:   bash ${INFRA_DIR}/scripts/launch-team.sh <N>"
echo "  Stop:     bash ${INFRA_DIR}/scripts/stop-team.sh <N>"
echo "  Message:  bash ${INFRA_DIR}/scripts/send-message.sh <N> <role> \"msg\""
ENDOFFILE

cat > .agent-infra/scripts/add-team.sh << 'ENDOFFILE'
#!/bin/bash
# Create a team folder with status file templates
# Usage: bash .agent-infra/scripts/add-team.sh <team-number>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

TEAM="$1"

validate_team "$TEAM" || exit 1

TEAM_DIR="${INFRA_DIR}/tasks/team-${TEAM}"

if [ -d "$TEAM_DIR" ]; then
  echo "Team ${TEAM} folder already exists at ${TEAM_DIR}/"
  exit 0
fi

mkdir -p "$TEAM_DIR"

cat > "${TEAM_DIR}/builder-status.md" << 'TMPL'
# Builder Status — Team TEAM_NUM

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent A (Builder) — Team TEAM_NUM

## Current
[No active work]

## Completed This Task
[None yet]
TMPL
sed -i '' "s/TEAM_NUM/${TEAM}/g" "${TEAM_DIR}/builder-status.md"

cat > "${TEAM_DIR}/qa-findings.md" << 'TMPL'
# QA Findings — Team TEAM_NUM

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent B (QA) — Team TEAM_NUM

---

<!-- Finding Template — copy this for each new finding:

## Finding — [timestamp]
- **Item:** #[N]
- **Severity:** bug | quality | alignment | suggestion
- **Issue:** [specific description of what's wrong]
- **Files:** [affected file paths]
- **Suggested fix:** [actionable description of how to fix]
- **Status:** new | fixed | wont-fix

-->

[No findings yet]
TMPL
sed -i '' "s/TEAM_NUM/${TEAM}/g" "${TEAM_DIR}/qa-findings.md"

cat > "${TEAM_DIR}/fixer-status.md" << 'TMPL'
# Fixer Status — Team TEAM_NUM

**Current Task:** [none]
**Updated:** [timestamp]
**Owner:** Agent C (Fixer) — Team TEAM_NUM

## Current
[No active work]

## Completed This Task
[None yet]

## Waiting
[Nothing blocked]
TMPL
sed -i '' "s/TEAM_NUM/${TEAM}/g" "${TEAM_DIR}/fixer-status.md"

echo "Created team ${TEAM} folder with status templates at ${TEAM_DIR}/"
echo "  - builder-status.md"
echo "  - qa-findings.md"
echo "  - fixer-status.md"
ENDOFFILE

cat > .agent-infra/scripts/send-message.sh << 'ENDOFFILE'
#!/bin/bash
# Send a message to a specific agent via tmux send-keys
# Usage: bash .agent-infra/scripts/send-message.sh <team-number> <role> "message"
#
# Examples:
#   bash .agent-infra/scripts/send-message.sh 1 builder "Re-read the task board and continue"
#   bash .agent-infra/scripts/send-message.sh 1 qa "Check the latest commits"
#   bash .agent-infra/scripts/send-message.sh 1 fixer "Prioritize bug severity findings"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

TEAM="$1"
ROLE="$2"
MESSAGE="$3"

if [ -z "$TEAM" ] || [ -z "$ROLE" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: bash $0 <team-number> <role> \"message\""
  echo ""
  echo "Roles: builder, qa, fixer"
  echo ""
  echo "Examples:"
  echo "  bash $0 1 builder \"Re-read task board and continue\""
  echo "  bash $0 1 qa \"Check the latest commits\""
  exit 1
fi

check_tmux
validate_team "$TEAM" || exit 1
validate_role "$ROLE" || exit 1

if ! session_exists; then
  echo "Error: No agent-infra tmux session running."
  exit 1
fi

win=$(window_name "$TEAM" "$ROLE")

if ! window_exists "$win"; then
  echo "Error: Window '${win}' not found. Is the agent running?"
  echo "Launch with: bash ${INFRA_DIR}/scripts/launch-team.sh ${TEAM}"
  exit 1
fi

# Send the message via tmux send-keys
tmux send-keys -t "${SESSION_NAME}:${win}" "$MESSAGE" Enter

echo "Message sent to ${win}: ${MESSAGE}"
ENDOFFILE

cat > .agent-infra/scripts/curate-lessons.sh << 'ENDOFFILE'
#!/bin/bash
# Lesson health check — shows entry counts vs limits for all lesson files
# Usage: bash .agent-infra/scripts/curate-lessons.sh
#
# Run this during curation cycles to quickly see which files need pruning.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_infra

echo "── Lesson Health ──"
echo ""

LESSONS_DIR="${INFRA_DIR}/lessons"
over_limit=false

check_file() {
  local file="$1"
  local label="$2"
  local max="$3"

  if [ ! -f "$file" ]; then
    echo "  ${label}: [file not found]"
    return
  fi

  local count
  # Count real lesson entries, excluding template examples (contain [Short Title])
  count=$(grep '^### ' "$file" 2>/dev/null | grep -cv '\[Short Title\]' | tr -d '[:space:]')
  count=${count:-0}

  local status="OK"
  local bar=""

  if [ "$count" -gt "$max" ]; then
    status="OVER LIMIT (prune $((count - max)))"
    over_limit=true
  elif [ "$count" -ge $((max - 3)) ]; then
    status="near limit"
  fi

  # Simple bar: filled/total
  local filled=$((count * 20 / max))
  [ "$filled" -gt 20 ] && filled=20
  local empty=$((20 - filled))
  bar=$(printf '%0.s█' $(seq 1 $filled 2>/dev/null))$(printf '%0.s░' $(seq 1 $empty 2>/dev/null))

  printf "  %-14s %s %2d/%-2d  %s\n" "${label}:" "$bar" "$count" "$max" "$status"
}

check_file "${LESSONS_DIR}/universal.md"   "universal"   20
check_file "${LESSONS_DIR}/planning.md"    "planning"    30
check_file "${LESSONS_DIR}/building.md"    "building"    30
check_file "${LESSONS_DIR}/qa-testing.md"  "qa-testing"  30
check_file "${LESSONS_DIR}/fixing.md"      "fixing"      30

echo ""

if [ "$over_limit" = true ]; then
  echo "  Action needed: Some files are over their entry limit."
  echo "  During curation, remove the least valuable entries or promote cross-cutting ones to universal.md."
else
  echo "  All lesson files within limits."
fi

echo ""
echo "── Curation Checklist ──"
echo "  1. Read all 5 lesson files"
echo "  2. Promote cross-cutting lessons → universal.md (remove from source)"
echo "  3. Prune outdated, vague, or duplicate entries"
echo "  4. Consolidate similar lessons across agents"
echo "  5. Re-run this script to verify counts"
ENDOFFILE

# ── Root files ──────────────────────────────────────────────────────

cat > CLAUDE.md << 'ENDOFFILE'
# Multi-Agent Team Infrastructure

This project uses a multi-agent coordination system. All agent configuration, plans, tasks, and lessons are in `.agent-infra/`.

## Quick Start — Automated Mode (recommended)

1. Open one Claude Code tab for the Orchestrator:
   `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.`
2. The Orchestrator auto-launches agent teams via tmux:
   ```bash
   bash .agent-infra/scripts/add-team.sh 1      # create team folder
   bash .agent-infra/scripts/launch-team.sh 1    # launch 3 agents (max 2 teams enforced)
   bash .agent-infra/scripts/status.sh           # monitor progress
   bash .agent-infra/scripts/send-message.sh 1 builder "Re-read task board"  # message an agent
   bash .agent-infra/scripts/curate-lessons.sh   # check lesson file health
   bash .agent-infra/scripts/stop-team.sh 1      # stop when done
   ```
3. View agents: `tmux attach -t agent-infra`

Agents auto-restart on crash with `--continue` (exponential backoff, max 5 retries). Launch blocks if plan dependencies aren't met or 2 teams already running. Requires tmux (`brew install tmux`).

## Quick Start — Manual Mode: Single Team (4 tabs)

1. `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.`
2. `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 1.`
3. `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 1.`
4. `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 1.`

## Quick Start — Manual Mode: Two Teams (7 tabs)

1. `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.`
2. `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 1.`
3. `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 1.`
4. `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 1.`
5. `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 2.`
6. `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 2.`
7. `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 2.`

Before starting Team 2, create the folder: `mkdir -p .agent-infra/tasks/team-2` and copy status templates from `team-1/`.

## Agent Overview

| Agent | Role | Writes Code? |
|-------|------|-------------|
| Orchestrator | Plans, decomposes, assigns to teams, reviews, curates lessons | No |
| Agent A (Builder) | Implements features sequentially through checklist | Yes |
| Agent B (QA) | Monitors, tests, validates plan alignment | No |
| Agent C (Fixer) | Fixes bugs + refactors completed items behind Agent A | Yes |

## Planning Hierarchy

- **Small project:** Orchestrator writes `current-plan.md` directly
- **Large project:** Orchestrator writes `master-plan.md` with multiple plans, then activates them one at a time (or in parallel across teams)

## Assembly Line Model

Each team runs its own assembly line on non-overlapping files:
- Agent A moves forward through items, committing after each
- Agent C works behind Agent A on completed items only
- Agent B monitors everything and writes findings
- Orchestrator coordinates all teams via the task board

## Key Directories

- `.agent-infra/roles/` — Role definitions (read-only after setup)
- `.agent-infra/plans/` — Master plan + current plan (Orchestrator-owned)
- `.agent-infra/tasks/` — Task board + per-team status folders
- `.agent-infra/lessons/` — Accumulated lessons (per-role + universal)
- `.agent-infra/reviews/` — Code review log (Orchestrator-owned)

## File Ownership

Every file has exactly ONE write-owner. See each role file for details. Agents must NEVER write to files they don't own.

## Shared Conventions

- Commit messages include team: `feat(team-1): Item #3 — description`
- Fix commits reference findings: `fix(team-1): Finding #2 — Item #1 — description`
- Status files use append-only format with timestamps
- Lessons follow the standard format with Context, Lesson, and Apply-when fields
- All lesson files have entry caps (30 per role, 20 for universal) — enforce strictly
- Parallel teams MUST have non-overlapping file scopes — no exceptions
ENDOFFILE

cat > TEAM-GUIDE.md << 'ENDOFFILE'
# Multi-Agent Team Guide

## What This Is

An assembly-line system where teams of AI agents build, monitor, and fix code simultaneously — coordinated by a single Orchestrator. Scales from one team (4 tabs) to multiple teams running in parallel (7-10 tabs).

## Setup — Automated Mode (recommended)

1. Copy `.agent-infra/` and `CLAUDE.md` into your project root (or run `setup.sh`)
2. Install tmux if needed: `brew install tmux`
3. Open **one** Claude Code tab for the Orchestrator:

```
Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.
```

4. The Orchestrator launches agent teams automatically:

```bash
bash .agent-infra/scripts/add-team.sh 1      # create team folder
bash .agent-infra/scripts/launch-team.sh 1    # launch builder, qa, fixer in tmux
bash .agent-infra/scripts/status.sh           # monitor all agents
bash .agent-infra/scripts/send-message.sh 1 builder "Re-read task board"  # message agent
bash .agent-infra/scripts/curate-lessons.sh   # check lesson file health
bash .agent-infra/scripts/stop-team.sh 1      # stop team when done
```

5. View running agents: `tmux attach -t agent-infra`

Each agent runs in a persistent interactive session with auto-restart on crash (`--continue` preserves context, exponential backoff, max 5 retries). Agents use `--permission-mode acceptEdits`.

**Safety guardrails:**
- Max 2 concurrent teams (override: `--max-teams 3`)
- Launch blocks if plan dependencies aren't met (reads master-plan.md)
- Crash logs auto-rotate at 50 entries

For a second team, just run `add-team.sh 2` then `launch-team.sh 2` — the script checks master-plan.md dependencies before launching.

## Setup — Manual Mode (4-7 tabs)

1. Copy `.agent-infra/` and `CLAUDE.md` into your project root
2. Open Claude Code tabs and paste one line per tab:

### Single Team (4 tabs)

| Tab | Paste This | What It Does |
|-----|-----------|--------------|
| 1 | `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.` | Coordinates everything |
| 2 | `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 1.` | Builds features |
| 3 | `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 1.` | Monitors + tests |
| 4 | `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 1.` | Fixes + refactors |

### Two Teams in Parallel (7 tabs)

Add 3 more tabs for Team 2. Before starting Team 2, run:
```bash
mkdir -p .agent-infra/tasks/team-2
cp .agent-infra/tasks/team-1/* .agent-infra/tasks/team-2/
```

| Tab | Paste This |
|-----|-----------|
| 5 | `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 2.` |
| 6 | `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 2.` |
| 7 | `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 2.` |

## How It Works

Give the Orchestrator your project. It creates a plan (or master plan for big projects) and a checklist. Then the assembly line runs:

```
Checklist items:   [1] [2] [3] [4] [5]
                    ✅   🔧  🔨   ⬜   ⬜
                    ↑    ↑    ↑
                   done  C    A
                        fixes builds

          B (QA) monitors everything continuously
```

For multi-team, each team runs its own assembly line on different parts of the codebase:

```
Team 1: Auth system     [1]✅ [2]🔧 [3]🔨 [4]⬜
Team 2: Dashboard       [1]✅ [2]🔨 [3]⬜ [4]⬜   ← parallel, different files
```

## Planning Hierarchy

- **Small project** (fix a bug, add one feature): Orchestrator writes one plan, one team runs it
- **Large project** (build a system): Orchestrator writes a master plan with multiple plans, assigns them to teams

```
Master Plan
├── Plan 1: "Auth" → Team 1        ← can run in parallel (different files)
├── Plan 2: "Dashboard" → Team 2   ← can run in parallel (different files)
└── Plan 3: "Notifications" → waits for Plan 1 (shared files)
```

The Orchestrator ensures parallel teams never touch the same files.

## The Only Rules You Need to Know

1. **Start with the Orchestrator** — give it the project, let it plan before telling other agents to go
2. **One tab per agent** — don't mix roles in a single tab
3. **Tell each agent their team number** — it's in the startup line you paste
4. **Let them coordinate via files** — agents read each other's status files, don't relay messages between tabs
5. **Don't edit `.agent-infra/` files yourself** — each file has one agent owner

## Where Things Live

```
.agent-infra/
├── roles/              # What each agent does (don't edit after setup)
├── plans/
│   ├── master-plan.md   # Big picture — multi-plan projects (Orchestrator)
│   └── current-plan.md  # Active plan details (Orchestrator)
├── tasks/
│   ├── task-board.md    # All teams' checklists (Orchestrator)
│   ├── team-1/          # Team 1's status files
│   │   ├── builder-status.md
│   │   ├── qa-findings.md
│   │   └── fixer-status.md
│   └── team-2/          # Team 2's status files (create when needed)
├── scripts/             # Auto-launch scripts
│   ├── _common.sh        # Shared functions
│   ├── launch-team.sh    # Start agents in tmux (enforces team limit + deps)
│   ├── stop-team.sh      # Graceful shutdown
│   ├── status.sh         # Dashboard
│   ├── add-team.sh       # Create team folder
│   ├── send-message.sh   # Message an agent
│   └── curate-lessons.sh # Lesson entry counts vs limits
├── lessons/             # Accumulated knowledge (persists across tasks)
└── reviews/             # Code review log (Orchestrator)
```

## Tips

- **Start small.** Use one team first. Add a second team only when the Orchestrator identifies plans with non-overlapping file scopes.
- **Max 3 teams.** Beyond that, coordination overhead outweighs throughput gains.
- **Something wrong?** Tell the Orchestrator — it updates the task board, other agents adapt.
- **Lessons carry over.** The `lessons/` folder accumulates knowledge across tasks. Keep it when starting new work.
- **Starting a new project?** Copy a fresh template. Optionally bring `lessons/` from a similar project.
- **Agent stuck?** Remind it to re-read its role file and the task board.
ENDOFFILE

# ── Make scripts executable ─────────────────────────────────────────

chmod +x .agent-infra/scripts/*.sh

echo ""
echo "Done! Added to your project:"
echo "  .agent-infra/    — agent roles, plans, tasks, lessons, scripts"
echo "  CLAUDE.md        — project root config"
echo "  TEAM-GUIDE.md    — team reference guide"
echo ""
echo "=== Automated Mode (recommended) ==="
echo "  1. Open one Claude Code tab for the Orchestrator:"
echo "     Read .agent-infra/roles/orchestrator.md — you are the Orchestrator."
echo "  2. The Orchestrator can auto-launch agent teams with:"
echo "     bash .agent-infra/scripts/add-team.sh 1"
echo "     bash .agent-infra/scripts/launch-team.sh 1"
echo "  3. Monitor: bash .agent-infra/scripts/status.sh"
echo "  4. Stop:    bash .agent-infra/scripts/stop-team.sh 1"
echo ""
echo "  Requires: tmux (brew install tmux)"
echo ""
echo "=== Manual Mode (4 tabs) ==="
echo "  Tab 1: Read .agent-infra/roles/orchestrator.md — you are the Orchestrator."
echo "  Tab 2: Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 1."
echo "  Tab 3: Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 1."
echo "  Tab 4: Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 1."
echo ""
echo "=== Adding Team 2 (3 more tabs) ==="
echo "  First: mkdir -p .agent-infra/tasks/team-2 && cp .agent-infra/tasks/team-1/* .agent-infra/tasks/team-2/"
echo "  Tab 5: Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 2."
echo "  Tab 6: Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 2."
echo "  Tab 7: Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 2."
