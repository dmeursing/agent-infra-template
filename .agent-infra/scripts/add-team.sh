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
