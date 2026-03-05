#!/bin/bash
# Dashboard: show running agents, status from files, and crash logs
# Usage: bash .agent-infra/scripts/status.sh [team-number]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_infra

FILTER_TEAM="$1"

echo "╔══════════════════════════════════════════╗"
echo "║       Agent Infrastructure Status        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── tmux session status ──────────────────────────────────────────

echo "── tmux Session ──"
if session_exists; then
  echo "  Session '${SESSION_NAME}': ACTIVE"
  windows=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name} #{window_active}' 2>/dev/null)
  while IFS=' ' read -r win active; do
    if [[ "$win" == team-* ]]; then
      # Check if claude is actually running in the pane
      pane_pid=$(tmux list-panes -t "${SESSION_NAME}:${win}" -F '#{pane_pid}' 2>/dev/null)
      if [ -n "$pane_pid" ]; then
        echo "    ${win}: RUNNING (pid: ${pane_pid})"
      else
        echo "    ${win}: WINDOW EXISTS (no process)"
      fi
    fi
  done <<< "$windows"
else
  echo "  Session '${SESSION_NAME}': NOT RUNNING"
fi

echo ""

# ── Team status files ────────────────────────────────────────────

echo "── Team Status ──"

# Find all team directories
for team_dir in ${INFRA_DIR}/tasks/team-*/; do
  [ -d "$team_dir" ] || continue

  team_num=$(basename "$team_dir" | sed 's/team-//')

  # Filter if a specific team was requested
  if [ -n "$FILTER_TEAM" ] && [ "$team_num" != "$FILTER_TEAM" ]; then
    continue
  fi

  echo ""
  echo "  Team ${team_num}:"

  # Builder status
  if [ -f "${team_dir}builder-status.md" ]; then
    current=$(grep -E '^(WORKING|DONE|IDLE):' "${team_dir}builder-status.md" | tail -1)
    if [ -n "$current" ]; then
      echo "    Builder: ${current}"
    else
      echo "    Builder: [no status update]"
    fi
  fi

  # QA findings (pattern matches real timestamps, not template placeholders)
  if [ -f "${team_dir}qa-findings.md" ]; then
    total=$(grep -c '^## Finding — [0-9]' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    total=${total:-0}
    new_count=$(grep -c '^\- \*\*Status:\*\* new$' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    new_count=${new_count:-0}
    fixed_count=$(grep -c '^\- \*\*Status:\*\* fixed$' "${team_dir}qa-findings.md" 2>/dev/null | tr -d '[:space:]')
    fixed_count=${fixed_count:-0}
    echo "    QA:      ${total} findings (${new_count} new, ${fixed_count} fixed)"
  fi

  # Fixer status
  if [ -f "${team_dir}fixer-status.md" ]; then
    current=$(grep -E '^(FIXING|FIXED|WAITING|IDLE):' "${team_dir}fixer-status.md" | tail -1)
    if [ -n "$current" ]; then
      echo "    Fixer:   ${current}"
    else
      echo "    Fixer:   [no status update]"
    fi
  fi

  # Crash log
  crash_log="${team_dir}crash.log"
  if [ -f "$crash_log" ]; then
    crash_count=$(wc -l < "$crash_log" | tr -d ' ')
    last_crash=$(tail -1 "$crash_log")
    echo "    Crashes: ${crash_count} total — last: ${last_crash}"
  fi
done

echo ""

# ── Task board summary ───────────────────────────────────────────

echo "── Task Board ──"
if [ -f "${INFRA_DIR}/tasks/task-board.md" ]; then
  total=$(grep -c '^\- \[' "${INFRA_DIR}/tasks/task-board.md" 2>/dev/null | tr -d '[:space:]')
  total=${total:-0}
  done_count=$(grep -c '^\- \[x\]' "${INFRA_DIR}/tasks/task-board.md" 2>/dev/null | tr -d '[:space:]')
  done_count=${done_count:-0}
  pending=$((total - done_count))
  echo "  Items: ${total} total, ${done_count} done, ${pending} pending"
else
  echo "  [no task board found]"
fi

echo ""
echo "── Commands ──"
echo "  Attach:   tmux attach -t ${SESSION_NAME}"
echo "  Launch:   bash ${INFRA_DIR}/scripts/launch-team.sh <N>"
echo "  Stop:     bash ${INFRA_DIR}/scripts/stop-team.sh <N>"
echo "  Message:  bash ${INFRA_DIR}/scripts/send-message.sh <N> <role> \"msg\""
