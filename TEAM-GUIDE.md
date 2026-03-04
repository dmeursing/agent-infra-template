# Multi-Agent Team Guide

## What This Is

A four-agent assembly line that runs in four Claude Code tabs simultaneously. One builds, one monitors, one fixes, and one coordinates — all working on the same task but never stepping on each other.

## Setup (2 minutes)

1. Copy `.agent-infra/` and `CLAUDE.md` into your project root
2. Open four Claude Code tabs in your project
3. Paste one line per tab:

| Tab | Paste This | What It Does |
|-----|-----------|--------------|
| 1 | `Read .agent-infra/roles/orchestrator.md — you are the Orchestrator.` | Coordinates everything |
| 2 | `Read .agent-infra/roles/builder.md — you are Agent A (Builder).` | Builds features |
| 3 | `Read .agent-infra/roles/qa.md — you are Agent B (QA).` | Monitors + tests |
| 4 | `Read .agent-infra/roles/fixer.md — you are Agent C (Fixer).` | Fixes + refactors |

## How It Works

Give the Orchestrator your task. It creates a plan and checklist. Then the assembly line runs:

```
Checklist items:   [1] [2] [3] [4] [5]
                    ✅   🔧  🔨   ⬜   ⬜
                    ↑    ↑    ↑
                   done  C    A
                        fixes builds

          B (QA) monitors everything continuously
```

- **Agent A** builds items left to right, commits after each one
- **Agent B** reviews completed items, writes findings to `qa-findings.md`
- **Agent C** fixes issues behind Agent A — never on the same item
- **Orchestrator** updates the task board, reviews code, curates lessons

## The Only Rules You Need to Know

1. **Start with the Orchestrator** — give it the task, let it create the plan before telling other agents to go
2. **One tab per agent** — don't mix roles in a single tab
3. **Let them coordinate via files** — agents read each other's status files, don't manually relay messages between tabs
4. **Don't edit `.agent-infra/` files yourself** — each file has one agent owner, let them manage it

## Where Things Live

```
.agent-infra/
├── roles/          # What each agent does (don't edit after setup)
├── plans/          # The current plan (Orchestrator writes)
├── tasks/          # Task board + each agent's status file
├── lessons/        # Accumulated knowledge (persists across tasks)
└── reviews/        # Code review log (Orchestrator writes)
```

## Tips

- **Multiple tasks?** Give them to the Orchestrator one at a time. It sequences them.
- **Something wrong?** Tell the Orchestrator — it updates the task board, other agents adapt.
- **Lessons carry over.** The `lessons/` folder accumulates knowledge across tasks. Keep it when starting new work in the same project.
- **Starting a new project?** Copy a fresh template. Optionally bring `lessons/` from a similar project.
- **Agent stuck?** Remind it to re-read its role file and the task board.
