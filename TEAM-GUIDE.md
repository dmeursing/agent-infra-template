# Multi-Agent Team Guide

## What This Is

An assembly-line system where teams of AI agents build, monitor, and fix code simultaneously — coordinated by a single Orchestrator. Scales from one team (4 tabs) to multiple teams running in parallel (7-10 tabs).

## Setup (2 minutes)

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
