#!/usr/bin/env bash
# Register hourly cron job for param backup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

STATE_DIR="${STATE_DIR:-$HOME/.config/e72-param-backup}"
LOCK_FILE="${LOCK_FILE:-$STATE_DIR/backup.lock}"
BACKUP_SCRIPT="$SCRIPT_DIR/backup_param.sh"
MARKER="# e72-param-backup"
CRON_LINE="0 * * * * flock -n $LOCK_FILE $BACKUP_SCRIPT $MARKER"

mkdir -p "$STATE_DIR"

if ! crontab -l 2>/dev/null | grep -Fq "$MARKER"; then
  (
    crontab -l 2>/dev/null || true
    echo "$CRON_LINE"
  ) | crontab -
  echo "cron registered: $CRON_LINE"
else
  echo "cron already registered"
fi

crontab -l | grep -F "$MARKER" || true
