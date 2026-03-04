# Multi-Agent Team Infrastructure

This project uses a multi-agent coordination system. All agent configuration, plans, tasks, and lessons are in `.agent-infra/`.

## Quick Start

Open four Claude Code tabs and paste one line per tab:

1. `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.`
2. `Read .agent-infra/roles/builder.md — you are Agent A (Builder).`
3. `Read .agent-infra/roles/qa.md — you are Agent B (QA).`
4. `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer).`

## Agent Overview

| Tab | Agent | Role | Writes Code? |
|-----|-------|------|-------------|
| 1 | Orchestrator | Plans, decomposes, reviews, curates lessons | No |
| 2 | Agent A (Builder) | Implements features sequentially through checklist | Yes |
| 3 | Agent B (QA) | Monitors, tests, validates plan alignment | No |
| 4 | Agent C (Fixer) | Fixes bugs + refactors completed items behind Agent A | Yes |

## Assembly Line Model

Agents work simultaneously on the same task but on different checklist items:
- Agent A moves forward through items, committing after each
- Agent C works behind Agent A on completed items only
- Agent B monitors everything and writes findings
- Orchestrator coordinates via the task board

## Key Directories

- `.agent-infra/roles/` — Role definitions (read-only after setup)
- `.agent-infra/plans/` — Current plan (Orchestrator-owned)
- `.agent-infra/tasks/` — Task board + agent status files
- `.agent-infra/lessons/` — Accumulated lessons (per-agent + universal)
- `.agent-infra/reviews/` — Code review log (Orchestrator-owned)

## File Ownership

Every file has exactly ONE write-owner. See each role file for details. Agents must NEVER write to files they don't own.

## Shared Conventions

- Commit messages reference checklist item numbers: `feat: Item #3 — description`
- Fix commits reference QA findings: `fix: Finding #2 — Item #1 — description`
- Status files use append-only format with timestamps
- Lessons follow the standard format with Context, Lesson, and Apply-when fields
- All lesson files have entry caps (30 per agent, 20 for universal) — enforce strictly
