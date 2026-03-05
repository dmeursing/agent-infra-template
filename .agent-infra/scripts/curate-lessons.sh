#!/bin/bash
# Lesson health check — shows entry counts vs limits for all lesson files
# Usage: bash .agent-infra/scripts/curate-lessons.sh
#
# Run this during curation cycles to quickly see which files need pruning.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

check_infra

echo "── Lesson Health ──"
echo ""

LESSONS_DIR="${INFRA_DIR}/lessons"
over_limit=false

check_file() {
  local file="$1"
  local label="$2"
  local max="$3"

  if [ ! -f "$file" ]; then
    echo "  ${label}: [file not found]"
    return
  fi

  local count
  # Count real lesson entries, excluding template examples (contain [Short Title])
  count=$(grep '^### ' "$file" 2>/dev/null | grep -cv '\[Short Title\]' | tr -d '[:space:]')
  count=${count:-0}

  local status="OK"
  local bar=""

  if [ "$count" -gt "$max" ]; then
    status="OVER LIMIT (prune $((count - max)))"
    over_limit=true
  elif [ "$count" -ge $((max - 3)) ]; then
    status="near limit"
  fi

  # Simple bar: filled/total
  local filled=$((count * 20 / max))
  [ "$filled" -gt 20 ] && filled=20
  local empty=$((20 - filled))
  bar=$(printf '%0.s█' $(seq 1 $filled 2>/dev/null))$(printf '%0.s░' $(seq 1 $empty 2>/dev/null))

  printf "  %-14s %s %2d/%-2d  %s\n" "${label}:" "$bar" "$count" "$max" "$status"
}

check_file "${LESSONS_DIR}/universal.md"   "universal"   20
check_file "${LESSONS_DIR}/planning.md"    "planning"    30
check_file "${LESSONS_DIR}/building.md"    "building"    30
check_file "${LESSONS_DIR}/qa-testing.md"  "qa-testing"  30
check_file "${LESSONS_DIR}/fixing.md"      "fixing"      30

echo ""

if [ "$over_limit" = true ]; then
  echo "  Action needed: Some files are over their entry limit."
  echo "  During curation, remove the least valuable entries or promote cross-cutting ones to universal.md."
else
  echo "  All lesson files within limits."
fi

echo ""
echo "── Curation Checklist ──"
echo "  1. Read all 5 lesson files"
echo "  2. Promote cross-cutting lessons → universal.md (remove from source)"
echo "  3. Prune outdated, vague, or duplicate entries"
echo "  4. Consolidate similar lessons across agents"
echo "  5. Re-run this script to verify counts"
