---
name: multi-agent-team
description: Set up and run a multi-agent team infrastructure for Claude Code. An assembly-line system where teams of AI agents (builder, QA, fixer) build, monitor, and fix code simultaneously, coordinated by an orchestrator. Use when asked about multi-agent, team of agents, parallel agents, assembly line, agent infrastructure, or coordinating multiple Claude instances.
compatibility: Requires Claude Code CLI, tmux, and bash. Designed for macOS and Linux.
metadata:
  author: dmeursing
  version: "1.0"
---

# Multi-Agent Team Infrastructure

An assembly-line system where teams of AI agents build, monitor, and fix code simultaneously — coordinated by a single Orchestrator. Scales from one team (4 agents) to multiple teams running in parallel.

## Setup

Run the scaffolder to create the full `.agent-infra/` structure in the current project:

```bash
bash scripts/setup.sh
```

This creates all directories, role definitions, templates, and launch scripts. No git clone needed.

After setup, open one Claude Code tab for the Orchestrator:

```
Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.
```

The Orchestrator handles everything from there — planning, launching teams, and coordinating work.

## How It Works

Four agent roles form an assembly line per team:

| Agent | Role | Writes Code? |
|-------|------|-------------|
| Orchestrator | Plans, decomposes, assigns to teams, reviews, curates lessons | No |
| Agent A (Builder) | Implements features sequentially through checklist | Yes |
| Agent B (QA) | Monitors, tests, validates plan alignment | No |
| Agent C (Fixer) | Fixes bugs + refactors completed items behind Agent A | Yes |

```
Checklist items:   [1] [2] [3] [4] [5]
                    done fix build
                    ↑    ↑    ↑
                   done  C    A
                        fixes builds

          B (QA) monitors everything continuously
```

For multi-team, each team runs its own assembly line on different parts of the codebase:

```
Team 1: Auth system     [1]done [2]fix [3]build [4]pending
Team 2: Dashboard       [1]done [2]build [3]pending          ← parallel, different files
```

## Automated Mode (Recommended)

The Orchestrator launches and manages agent teams via tmux:

```bash
bash .agent-infra/scripts/add-team.sh 1      # create team folder
bash .agent-infra/scripts/launch-team.sh 1    # launch 3 agents in tmux
bash .agent-infra/scripts/status.sh           # monitor progress
bash .agent-infra/scripts/send-message.sh 1 builder "Re-read task board"
bash .agent-infra/scripts/curate-lessons.sh   # check lesson file health
bash .agent-infra/scripts/stop-team.sh 1      # stop when done
```

View running agents: `tmux attach -t agent-infra`

Agents auto-restart on crash with `--continue` (exponential backoff, max 5 retries). Max 2 concurrent teams enforced by default.

## Manual Mode (4-7 Tabs)

Open Claude Code tabs and paste one line per tab:

| Tab | Paste This |
|-----|-----------|
| 1 | `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.` |
| 2 | `Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team 1.` |
| 3 | `Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team 1.` |
| 4 | `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team 1.` |

For a second team, add 3 more tabs for Team 2 (create folder first: `bash .agent-infra/scripts/add-team.sh 2`).

## Available Commands

| Command | Purpose |
|---------|---------|
| `bash .agent-infra/scripts/add-team.sh <N>` | Create team folder with status templates |
| `bash .agent-infra/scripts/launch-team.sh <N>` | Launch all 3 agents in tmux windows |
| `bash .agent-infra/scripts/stop-team.sh <N>` | Graceful shutdown of a team |
| `bash .agent-infra/scripts/status.sh` | Dashboard: running agents, status, crashes |
| `bash .agent-infra/scripts/send-message.sh <N> <role> "msg"` | Send a message to a specific agent |
| `bash .agent-infra/scripts/curate-lessons.sh` | Lesson health: entry counts vs limits |

## Planning Hierarchy

- **Small project:** Orchestrator writes `current-plan.md` directly, one team runs it
- **Large project:** Orchestrator writes `master-plan.md` with multiple plans, assigns to teams

```
Master Plan
├── Plan 1: "Auth" → Team 1        ← can run in parallel (different files)
├── Plan 2: "Dashboard" → Team 2   ← can run in parallel (different files)
└── Plan 3: "Notifications" → waits for Plan 1 (shared files)
```

The Orchestrator ensures parallel teams never touch the same files.

## Architecture

```
.agent-infra/
├── roles/              # What each agent does (read-only after setup)
├── plans/
│   ├── master-plan.md   # Big picture — multi-plan projects (Orchestrator)
│   └── current-plan.md  # Active plan details (Orchestrator)
├── tasks/
│   ├── task-board.md    # All teams' checklists (Orchestrator)
│   └── team-N/          # Per-team status files
├── scripts/             # Auto-launch and management scripts
├── lessons/             # Accumulated knowledge (persists across tasks)
└── reviews/             # Code review log (Orchestrator)
```

## File Ownership

Every file has exactly ONE write-owner. Agents must NEVER write to files they don't own.

- **Orchestrator:** master-plan.md, current-plan.md, task-board.md, review-log.md, universal.md, planning.md
- **Builder (per team):** builder-status.md, building.md, source code within scope
- **QA (per team):** qa-findings.md, qa-testing.md
- **Fixer (per team):** fixer-status.md, fixing.md, source code for fixes within scope

## Role Details

For full role definitions, see:

- [Orchestrator Role](references/orchestrator-role.md) — planning, coordination, review, curation
- [Builder Role](references/builder-role.md) — sequential implementation through checklist
- [QA Role](references/qa-role.md) — monitoring, testing, validation
- [Fixer Role](references/fixer-role.md) — bug fixes and refactoring behind the builder
- [Team Guide](references/team-guide.md) — condensed reference for the full system

## Key Rules

1. **Start with the Orchestrator** — give it the project, let it plan before other agents go
2. **One tab per agent** — don't mix roles in a single tab
3. **Tell each agent their team number** — it's in the startup line
4. **Let them coordinate via files** — agents read each other's status files
5. **Don't edit `.agent-infra/` files yourself** — each file has one agent owner
6. **Parallel teams must have non-overlapping file scopes** — no exceptions
