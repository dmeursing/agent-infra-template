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
