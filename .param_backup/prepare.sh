#!/usr/bin/env bash
# Stop cron, clear stale lock, and show next steps (does not run backup).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.env}"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

STATE_DIR="${STATE_DIR:-$HOME/.config/e72-param-backup}"
LOCK_FILE="${LOCK_FILE:-$STATE_DIR/backup.lock}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$SCRIPT_DIR/backup_param.sh}"

echo "=== e72 param backup prepare ==="
echo "host: $(hostname)"
echo

echo "[1/3] stop cron on this host"
"$SCRIPT_DIR/cron_stop.sh"
echo

echo "[2/3] clear lock file"
if [[ -f "$LOCK_FILE" ]]; then
  if flock -n "$LOCK_FILE" true 2>/dev/null; then
    rm -f "$LOCK_FILE"
    echo "removed stale lock: $LOCK_FILE"
  else
    echo "WARN: lock is held; find process on some host:"
    echo "  pgrep -af backup_param"
    echo "  fuser -v $LOCK_FILE"
    exit 1
  fi
else
  echo "no lock file"
fi
echo

echo "[3/3] check for running backup"
if pgrep -af backup_param >/dev/null 2>&1; then
  echo "WARN: backup_param is still running:"
  pgrep -af backup_param
  exit 1
fi
echo "no running backup_param on $(hostname)"
echo

echo "=== next steps (run manually) ==="
echo "1. On other login nodes (cw08 etc.), also run:"
echo "     $SCRIPT_DIR/cron_stop.sh"
echo "     rm -f $LOCK_FILE   # only if pgrep shows nothing"
echo
echo "2. Test backup once:"
echo "     $BACKUP_SCRIPT"
echo
echo "3. Enable hourly cron on ONE host only:"
echo "     $SCRIPT_DIR/cron_start.sh"
echo
echo "4. Monitor:"
echo "     $SCRIPT_DIR/cron_monitor.sh"
