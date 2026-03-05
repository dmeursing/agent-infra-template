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
