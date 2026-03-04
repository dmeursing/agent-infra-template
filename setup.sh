#!/bin/bash
# Multi-Agent Team Infrastructure Setup
# Run from any project root to install the agent infra template.
# Usage: curl -fsSL https://raw.githubusercontent.com/dmeursing/agent-infra-template/main/setup.sh | bash

set -e

if [ -d ".agent-infra" ]; then
  echo "Error: .agent-infra/ already exists in this directory."
  echo "Remove it first if you want a fresh install: rm -rf .agent-infra"
  exit 1
fi

echo "Setting up multi-agent team infrastructure..."

TMPDIR=$(mktemp -d)
git clone --depth 1 https://github.com/dmeursing/agent-infra-template.git "$TMPDIR" 2>/dev/null

cp -r "$TMPDIR/.agent-infra" .
cp "$TMPDIR/CLAUDE.md" .
cp "$TMPDIR/TEAM-GUIDE.md" .

rm -rf "$TMPDIR"

echo ""
echo "Done! Added to your project:"
echo "  .agent-infra/    — agent roles, plans, tasks, lessons"
echo "  CLAUDE.md        — project root config"
echo "  TEAM-GUIDE.md    — team reference guide"
echo ""
echo "=== Single Team (4 tabs) ==="
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
