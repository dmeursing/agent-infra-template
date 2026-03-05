#!/bin/bash
# Shared functions for agent auto-launch system

SESSION_NAME="agent-infra"
ROLES=("builder" "qa" "fixer")
INFRA_DIR=".agent-infra"
MAX_TEAMS=2
CLAUDE_BIN=""
MAX_CRASH_RETRIES=5

# ── Dependency checks ──────────────────────────────────────────────

check_tmux() {
  if ! command -v tmux &>/dev/null; then
    echo "Error: tmux is not installed. Run: brew install tmux"
    exit 1
  fi
}

check_claude() {
  CLAUDE_BIN=$(command -v claude 2>/dev/null)
  if [ -z "$CLAUDE_BIN" ]; then
    echo "Error: claude CLI is not installed."
    exit 1
  fi
}

check_infra() {
  if [ ! -d "$INFRA_DIR" ]; then
    echo "Error: $INFRA_DIR/ not found. Run this from a project with agent-infra installed."
    exit 1
  fi
}

check_all() {
  check_tmux
  check_claude
  check_infra
}

# ── tmux helpers ───────────────────────────────────────────────────

window_name() {
  local team="$1"
  local role="$2"
  echo "team-${team}-${role}"
}

session_exists() {
  tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

window_exists() {
  local win="$1"
  tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null | grep -qx "$win"
}

ensure_session() {
  if ! session_exists; then
    tmux new-session -d -s "$SESSION_NAME" -n "_control"
  fi
}

# ── Readiness detection ───────────────────────────────────────────

wait_for_claude_ready() {
  local win="$1"
  local max_retries=15
  local retry=0

  sleep 3

  while [ $retry -lt $max_retries ]; do
    local pane_content
    pane_content=$(tmux capture-pane -t "${SESSION_NAME}:${win}" -p 2>/dev/null)

    # Look for Claude's prompt indicators (the > or ? prompt, or "How can I help")
    if echo "$pane_content" | grep -qE '(^>|^❯|How can I help|What would you like)'; then
      return 0
    fi

    retry=$((retry + 1))
    sleep 2
  done

  echo "Warning: Claude readiness timeout in window $win (sent prompt anyway)"
  return 1
}

# ── Prompt building ───────────────────────────────────────────────

build_role_prompt() {
  local team="$1"
  local role="$2"

  case "$role" in
    builder)
      echo "Read .agent-infra/roles/builder.md — you are Agent A (Builder) on Team ${team}."
      ;;
    qa)
      echo "Read .agent-infra/roles/qa.md — you are Agent B (QA) on Team ${team}."
      ;;
    fixer)
      echo "Read .agent-infra/roles/fixer.md — you are Agent C (Fixer) on Team ${team}."
      ;;
    *)
      echo "Error: Unknown role '$role'"
      return 1
      ;;
  esac
}

# ── Permission mode ──────────────────────────────────────────────

get_permission_flag() {
  local role="$1"
  local skip_permissions="${2:-false}"

  if [ "$skip_permissions" = "true" ]; then
    echo "--dangerously-skip-permissions"
    return
  fi

  # All agents get acceptEdits — auto-accepts file edits, still prompts for bash
  echo "--permission-mode acceptEdits"
}

# ── Crash logging ─────────────────────────────────────────────────

log_crash() {
  local team="$1"
  local role="$2"
  local crash_log="${INFRA_DIR}/tasks/team-${team}/crash.log"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${role} crashed/exited — restarting with --continue" >> "$crash_log"
  rotate_crash_log "$crash_log"
}

rotate_crash_log() {
  local crash_log="$1"
  local max_lines=50

  if [ -f "$crash_log" ]; then
    local line_count
    line_count=$(wc -l < "$crash_log" | tr -d ' ')
    if [ "$line_count" -gt "$max_lines" ]; then
      tail -n "$max_lines" "$crash_log" > "${crash_log}.tmp" && mv "${crash_log}.tmp" "$crash_log"
    fi
  fi
}

# ── Team limit & dependency checks ──────────────────────────────

count_running_teams() {
  if ! session_exists; then
    echo "0"
    return
  fi
  # Count unique team numbers from running windows
  tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
    | grep '^team-' \
    | sed 's/team-\([0-9]*\)-.*/\1/' \
    | sort -u \
    | wc -l \
    | tr -d ' '
}

check_team_limit() {
  local team="$1"
  local running
  running=$(count_running_teams)

  # Check if this team is already running (not a new team)
  if session_exists; then
    local already_running
    already_running=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' 2>/dev/null \
      | grep "^team-${team}-" | head -1)
    if [ -n "$already_running" ]; then
      return 0  # team already running, not a new slot
    fi
  fi

  if [ "$running" -ge "$MAX_TEAMS" ]; then
    echo "Error: Already running ${running} team(s) (max: ${MAX_TEAMS})."
    echo "Stop a team first: bash ${INFRA_DIR}/scripts/stop-team.sh <N>"
    echo "Or override with: --max-teams <N>"
    return 1
  fi
}

check_plan_dependencies() {
  local team="$1"
  local master_plan="${INFRA_DIR}/plans/master-plan.md"

  if [ ! -f "$master_plan" ]; then
    return 0  # no master plan = single plan, no dependencies
  fi

  # Parse the plans table for this team's plan and its dependencies
  # Format: | # | Plan name | Status | Team | File Scope | Depends On |
  local team_plan_line
  team_plan_line=$(grep -i "team ${team}\b\|team-${team}\b" "$master_plan" | head -1)

  if [ -z "$team_plan_line" ]; then
    return 0  # team not in master plan yet (orchestrator may not have assigned it)
  fi

  # Extract "Depends On" field (last column in pipe-delimited table)
  local depends_on
  depends_on=$(echo "$team_plan_line" | awk -F'|' '{print $(NF-1)}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$depends_on" ] || [ "$depends_on" = "—" ] || [ "$depends_on" = "-" ] || [ "$depends_on" = "none" ]; then
    return 0  # no dependencies
  fi

  # Check if the dependent plan is marked as "complete" in master-plan.md
  # Extract plan numbers from dependency (e.g., "Plan 1" or "Plan 1, Plan 2")
  local dep_plans
  dep_plans=$(echo "$depends_on" | grep -oE '[Pp]lan [0-9]+' | grep -oE '[0-9]+')

  for dep_num in $dep_plans; do
    local dep_line
    dep_line=$(grep -E "^\|[[:space:]]*${dep_num}[[:space:]]*\|" "$master_plan")
    if [ -z "$dep_line" ]; then
      continue
    fi

    local dep_status
    dep_status=$(echo "$dep_line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ "$dep_status" != "complete" ]; then
      echo "WARNING: Team ${team}'s plan depends on Plan ${dep_num} (status: ${dep_status})."
      echo "Plan ${dep_num} is not yet complete. Launching may cause file conflicts."
      echo ""
      read -rp "Launch anyway? (y/N): " confirm
      if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        return 1
      fi
    fi
  done

  return 0
}

# ── Team validation ──────────────────────────────────────────────

validate_team() {
  local team="$1"
  if [ -z "$team" ]; then
    echo "Error: Team number required."
    return 1
  fi
  if ! [[ "$team" =~ ^[0-9]+$ ]]; then
    echo "Error: Team number must be a positive integer."
    return 1
  fi
}

validate_team_exists() {
  local team="$1"
  if [ ! -d "${INFRA_DIR}/tasks/team-${team}" ]; then
    echo "Error: Team ${team} folder not found. Run: bash ${INFRA_DIR}/scripts/add-team.sh ${team}"
    return 1
  fi
}

validate_role() {
  local role="$1"
  local valid=false
  for r in "${ROLES[@]}"; do
    if [ "$r" = "$role" ]; then
      valid=true
      break
    fi
  done
  if [ "$valid" = false ]; then
    echo "Error: Invalid role '$role'. Must be one of: ${ROLES[*]}"
    return 1
  fi
}
