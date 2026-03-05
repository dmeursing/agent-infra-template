#!/bin/bash
# Launch a team's 3 agents (builder, qa, fixer) in tmux windows
# Usage: bash .agent-infra/scripts/launch-team.sh <team-number> [options]
#
# Options:
#   --skip-permissions   Use dangerously-skip-permissions (sandboxed environments only)
#   --max-teams <N>      Override max concurrent teams (default: 2)
#   --force              Skip dependency checks
#
# Each agent runs inside a restart loop with exponential backoff.
# If claude exits, it logs the crash, waits (5s→10s→20s→40s→80s),
# and restarts with --continue. After 5 consecutive crashes, it stops.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

TEAM="$1"
SKIP_PERMISSIONS="false"
FORCE="false"
shift 2>/dev/null
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-permissions) SKIP_PERMISSIONS="true" ;;
    --max-teams) shift; MAX_TEAMS="$1" ;;
    --force) FORCE="true" ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

check_all
validate_team "$TEAM" || exit 1
validate_team_exists "$TEAM" || exit 1

# ── Pre-launch safety checks ────────────────────────────────────

check_team_limit "$TEAM" || exit 1

if [ "$FORCE" != "true" ]; then
  check_plan_dependencies "$TEAM" || exit 1
fi

ensure_session

PROJECT_DIR="$(pwd)"
CLAUDE_PATH="$CLAUDE_BIN"

echo "Launching Team ${TEAM} agents..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")

  if window_exists "$win"; then
    echo "  ${win}: already running (skipping)"
    continue
  fi

  perm_flag=$(get_permission_flag "$role" "$SKIP_PERMISSIONS")

  # Create the tmux window with a restart loop that has:
  # - Signal handling (trap) so stop-team.sh can exit the loop cleanly
  # - Exponential backoff (5s, 10s, 20s, 40s, 80s)
  # - Max consecutive crash limit (5 retries then stop)
  # - Crash log rotation
  tmux new-window -t "$SESSION_NAME" -n "$win" -c "$PROJECT_DIR" \
    "trap 'exit 0' SIGTERM SIGINT; \
     crash_count=0; \
     first=true; \
     while true; do \
       if [ \"\$first\" = true ]; then \
         ${CLAUDE_PATH} ${perm_flag}; \
         first=false; \
       else \
         crash_count=\$((crash_count + 1)); \
         if [ \$crash_count -ge ${MAX_CRASH_RETRIES} ]; then \
           echo \"[agent-infra] ${role} crashed ${MAX_CRASH_RETRIES} times consecutively. Stopping.\"; \
           echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ${role} hit max retries (${MAX_CRASH_RETRIES}) — stopped\" >> ${INFRA_DIR}/tasks/team-${TEAM}/crash.log; \
           exit 1; \
         fi; \
         backoff=\$((5 * (2 ** (crash_count - 1)))); \
         echo \"[agent-infra] ${role} exited. Restart \${crash_count}/${MAX_CRASH_RETRIES} in \${backoff}s...\"; \
         echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ${role} crashed/exited — restart \${crash_count}/${MAX_CRASH_RETRIES}\" >> ${INFRA_DIR}/tasks/team-${TEAM}/crash.log; \
         sleep \$backoff; \
         ${CLAUDE_PATH} --continue ${perm_flag}; \
       fi; \
     done"

  echo "  ${win}: started"
done

echo ""
echo "Waiting for Claude to become ready..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")
  echo -n "  ${win}: "
  if wait_for_claude_ready "$win"; then
    echo "ready"
  else
    echo "timeout (sending prompt anyway)"
  fi
done

echo ""
echo "Sending role prompts..."

for role in "${ROLES[@]}"; do
  win=$(window_name "$TEAM" "$role")
  prompt=$(build_role_prompt "$TEAM" "$role")

  # Use tmux send-keys to type the prompt and press Enter
  tmux send-keys -t "${SESSION_NAME}:${win}" "$prompt" Enter

  echo "  ${win}: prompt sent"
  # Small delay between prompts to avoid overwhelming
  sleep 1
done

echo ""
echo "Team ${TEAM} launched! All 3 agents are running."
echo ""
echo "  View:     tmux attach -t ${SESSION_NAME}"
echo "  Status:   bash ${INFRA_DIR}/scripts/status.sh"
echo "  Message:  bash ${INFRA_DIR}/scripts/send-message.sh ${TEAM} <role> \"message\""
echo "  Stop:     bash ${INFRA_DIR}/scripts/stop-team.sh ${TEAM}"
