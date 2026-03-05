# Multi-Agent Team Guide

## What This Is

An assembly-line system where teams of AI agents build, monitor, and fix code simultaneously — coordinated by a single Orchestrator. Scales from one team (4 agents) to multiple teams running in parallel.

## Setup

1. Run `bash scripts/setup.sh` from any project root (or use `npx skills add dmeursing/agent-infra-template`)
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
bash .agent-infra/scripts/send-message.sh 1 builder "Re-read task board"
bash .agent-infra/scripts/curate-lessons.sh   # check lesson file health
bash .agent-infra/scripts/stop-team.sh 1      # stop team when done
```

5. View running agents: `tmux attach -t agent-infra`

## How It Works

Give the Orchestrator your project. It creates a plan (or master plan for big projects) and a checklist. Then the assembly line runs:

```
Checklist items:   [1] [2] [3] [4] [5]
                    done fix build
                    ↑    ↑    ↑
                   done  C    A
                        fixes builds

          B (QA) monitors everything continuously
```

For multi-team, each team runs its own assembly line on different parts of the codebase.

## Planning Hierarchy

- **Small project** (fix a bug, add one feature): Orchestrator writes one plan, one team runs it
- **Large project** (build a system): Orchestrator writes a master plan with multiple plans, assigns them to teams

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
│   └── team-N/          # Per-team status files
├── scripts/             # Auto-launch and management scripts
├── lessons/             # Accumulated knowledge (persists across tasks)
└── reviews/             # Code review log (Orchestrator)
```

## Tips

- **Start small.** Use one team first. Add a second team only when the Orchestrator identifies plans with non-overlapping file scopes.
- **Max 3 teams.** Beyond that, coordination overhead outweighs throughput gains.
- **Something wrong?** Tell the Orchestrator — it updates the task board, other agents adapt.
- **Lessons carry over.** The `lessons/` folder accumulates knowledge across tasks. Keep it when starting new work.
- **Agent stuck?** Remind it to re-read its role file and the task board.
