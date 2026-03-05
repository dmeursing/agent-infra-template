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
