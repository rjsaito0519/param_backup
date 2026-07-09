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
DISCORD_WEBHOOK_FILE="${DISCORD_WEBHOOK_FILE:-$PARAM_SRC/.param_backup/.discord_webhook}"
MARKER="# e72-param-backup"

echo "=== e72 param backup monitor ==="
echo "host: $(hostname)"
echo

echo "[cron]"
if crontab -l 2>/dev/null | grep -F "$MARKER"; then
  echo "status: registered on $(hostname)"
else
  echo "status: NOT registered on $(hostname)"
fi
echo

echo "[config]"
echo "BACKUP_SCRIPT=$BACKUP_SCRIPT"
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
if [[ ! -f "$LOCK_FILE" ]]; then
  echo "status: idle (no lock file)"
elif flock -n "$LOCK_FILE" true 2>/dev/null; then
  echo "status: idle (lock not held)"
else
  echo "status: LOCKED (backup running on some host)"
  echo "hint: check other login nodes with: pgrep -af backup_param"
fi
echo

echo "[backup destination git]"
if [[ -d "$PARAM_BACKUP_DEST/.git" ]]; then
  echo "branch: $(git -C "$PARAM_BACKUP_DEST" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  if git -C "$PARAM_BACKUP_DEST" rev-parse --short HEAD >/dev/null 2>&1; then
    echo "latest commit: $(git -C "$PARAM_BACKUP_DEST" log -1 --oneline)"
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
