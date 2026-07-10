#!/usr/bin/env bash
# Show cron registration and recent backup status.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

PARAM_SRC="${PARAM_SRC:-/home/had/sryuta/analyzer/JPARC2025E72/param}"
PARAM_BACKUP_DEST="${PARAM_BACKUP_DEST:-/group/had/sks/Users/sryuta/backup/param}"
GITHUB_REMOTE="${GITHUB_REMOTE:-git@github.com:rjsaito0519/param_backup.git}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
PARAM_SRC_BRANCH="${PARAM_SRC_BRANCH:-e72}"
STATE_DIR="${STATE_DIR:-$HOME/.config/e72-param-backup}"
LOG_FILE="${LOG_FILE:-$STATE_DIR/backup.log}"
LOCK_FILE="${LOCK_FILE:-$STATE_DIR/backup.lock}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$PARAM_SRC/.param_backup/backup_param.sh}"
PUSH_SCRIPT="${PUSH_SCRIPT:-$PARAM_SRC/.param_backup/push_backup.sh}"
DISCORD_WEBHOOK_FILE="${DISCORD_WEBHOOK_FILE:-$PARAM_SRC/.param_backup/.discord_webhook}"
MARKER="# e72-param-backup"

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BOLD=''
  NC=''
fi

color_line() {
  local color="$1"
  shift
  printf '%b%s%b\n' "$color" "$*" "$NC"
}

is_backup_running() {
  if pgrep -f '[/]backup_param\.sh' >/dev/null 2>&1; then
    return 0
  fi
  if [[ -f "$LOCK_FILE" ]] && ! flock -n "$LOCK_FILE" true 2>/dev/null; then
    return 0
  fi
  return 1
}

last_log_event() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "none"
    return
  fi
  tac "$LOG_FILE" | grep -E 'DONE with errors|ERROR:|SKIP:|DONE$|START:' | head -n 1 || echo "none"
}

echo "=== e72 param backup monitor ==="
echo "host: $(hostname)"
echo

cron_registered=false
if crontab -l 2>/dev/null | grep -F "$MARKER" >/dev/null; then
  cron_registered=true
fi

echo "[cron]"
if [[ "$cron_registered" == true ]]; then
  crontab -l 2>/dev/null | grep -F "$MARKER"
  echo "status: registered on $(hostname)"
else
  echo "status: NOT registered on $(hostname)"
fi
echo

echo "[config]"
echo "BACKUP_SCRIPT=$BACKUP_SCRIPT"
echo "PUSH_SCRIPT=$PUSH_SCRIPT"
echo "PARAM_SRC=$PARAM_SRC"
echo "PARAM_BACKUP_DEST=$PARAM_BACKUP_DEST"
echo "GITHUB_REMOTE=$GITHUB_REMOTE"
echo "GITHUB_BRANCH=$GITHUB_BRANCH"
echo "PARAM_SRC_BRANCH=$PARAM_SRC_BRANCH"
echo "STATE_DIR=$STATE_DIR"
echo

echo "[source branch]"
if [[ -d "$PARAM_SRC/.git" || -f "$PARAM_SRC/.git" ]]; then
  current_branch="$(git -C "$PARAM_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  echo "current: $current_branch (expected: $PARAM_SRC_BRANCH)"
else
  echo "current: unknown (not a git checkout)"
fi
echo

echo "[discord webhook]"
if grep -v '^[[:space:]]*#' "$DISCORD_WEBHOOK_FILE" 2>/dev/null | grep -qv '^[[:space:]]*$'; then
  echo "status: configured ($DISCORD_WEBHOOK_FILE)"
else
  echo "status: NOT configured ($DISCORD_WEBHOOK_FILE)"
fi
echo

echo "[lock]"
lock_held=false
if [[ ! -f "$LOCK_FILE" ]]; then
  echo "status: idle (no lock file)"
elif flock -n "$LOCK_FILE" true 2>/dev/null; then
  echo "status: idle (lock not held)"
else
  lock_held=true
  echo "status: LOCKED (backup running on some host)"
  echo "hint: check other login nodes with: pgrep -af backup_param"
fi
echo

ahead=0
echo "[backup destination git]"
if [[ -d "$PARAM_BACKUP_DEST/.git" ]]; then
  echo "branch: $(git -C "$PARAM_BACKUP_DEST" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if git -C "$PARAM_BACKUP_DEST" rev-parse --short HEAD >/dev/null 2>&1; then
    echo "latest commit: $(git -C "$PARAM_BACKUP_DEST" log -1 --oneline)"
    if git -C "$PARAM_BACKUP_DEST" rev-parse "origin/$GITHUB_BRANCH" >/dev/null 2>&1; then
      ahead="$(git -C "$PARAM_BACKUP_DEST" rev-list --count "origin/$GITHUB_BRANCH..$GITHUB_BRANCH" 2>/dev/null || echo 0)"
      if [[ "$ahead" -gt 0 ]]; then
        echo "push status: $ahead commit(s) ahead (run push_backup.sh)"
      else
        echo "push status: up to date with origin/$GITHUB_BRANCH"
      fi
    else
      echo "push status: origin/$GITHUB_BRANCH not fetched yet"
    fi
  else
    echo "latest commit: none"
  fi
else
  echo "status: git repo not initialized yet"
fi
echo

echo "[recent log: $LOG_FILE]"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 15 "$LOG_FILE"
else
  echo "(no log yet)"
fi

echo
echo "=================================================="

backup_running=false
if is_backup_running; then
  backup_running=true
fi

last_event="$(last_log_event)"
summary_detail=""

if [[ "$backup_running" == true ]]; then
  if pgrep -af '[/]backup_param\.sh' >/dev/null 2>&1; then
    summary_detail="backup_param.sh is running on $(hostname)"
  else
    summary_detail="lock is held (likely running on another host)"
  fi
  color_line "${YELLOW}${BOLD}" ">>> BACKUP: RUNNING <<<  $summary_detail"
elif [[ "$last_event" == *"DONE with errors"* ]] || [[ "$last_event" == ERROR:* ]]; then
  summary_detail="last run failed — check log"
  color_line "${RED}${BOLD}" ">>> BACKUP: IDLE (last run FAILED) <<<  $summary_detail"
elif [[ "$last_event" == *"SKIP:"* ]]; then
  summary_detail="last cron run was skipped (lock conflict)"
  color_line "${YELLOW}${BOLD}" ">>> BACKUP: IDLE (last run SKIPPED) <<<  $summary_detail"
elif [[ "$cron_registered" == false ]]; then
  summary_detail="cron not registered on this host"
  color_line "${YELLOW}${BOLD}" ">>> BACKUP: IDLE (cron OFF on this host) <<<  $summary_detail"
else
  summary_detail="not running now"
  if [[ "$ahead" -gt 0 ]]; then
    summary_detail="$summary_detail — $ahead commit(s) waiting for push_backup.sh"
  elif [[ "$last_event" == *"DONE"* ]]; then
    summary_detail="$summary_detail — last run OK"
  fi
  color_line "${GREEN}${BOLD}" ">>> BACKUP: IDLE <<<  $summary_detail"
fi

if [[ "$lock_held" == true && "$backup_running" == false ]]; then
  color_line "${RED}${BOLD}" ">>> WARNING: stale lock? <<<  lock held but no process on $(hostname)"
fi

echo "=================================================="
