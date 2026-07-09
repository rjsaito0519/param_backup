#!/usr/bin/env bash
# Remove hourly cron job for param backup.

set -euo pipefail

MARKER="# e72-param-backup"

if crontab -l 2>/dev/null | grep -Fq "$MARKER"; then
  crontab -l | grep -Fv "$MARKER" | crontab -
  echo "cron removed on $(hostname)"
else
  echo "cron entry not found on $(hostname)"
fi
