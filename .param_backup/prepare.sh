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

echo "[1/2] stop cron and clear lock on this host"
"$SCRIPT_DIR/cron_stop.sh"
echo

echo "[2/2] confirm backup is not running"
if pgrep -af '[/]backup_param\.sh' >/dev/null 2>&1; then
  echo "WARN: backup_param is still running:"
  pgrep -af '[/]backup_param\.sh'
  exit 1
fi
echo "no running backup_param on $(hostname)"
echo

echo "=== next steps (run manually) ==="
echo "1. On other login nodes (cw08 etc.), also run:"
echo "     $SCRIPT_DIR/cron_stop.sh"
echo
echo "2. Test backup once:"
echo "     $BACKUP_SCRIPT"
echo
echo "3. Push to GitHub when ready:"
echo "     $PUSH_SCRIPT"
echo "     $PUSH_SCRIPT --dry-run"
echo
echo "4. Enable hourly cron on ONE host only:"
echo "     $SCRIPT_DIR/cron_start.sh"
echo
echo "5. Monitor:"
echo "     $SCRIPT_DIR/cron_monitor.sh"
