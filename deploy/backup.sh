#!/usr/bin/env bash
# Dumps the main database to ../backups (compressed, custom format) and keeps 14 days.
# Restore: docker compose exec -T db pg_restore -U nepse_trade_journal -d nepse_trade_journal_production --clean --if-exists < FILE
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p ../backups
file="../backups/nepse_$(date +%Y%m%d_%H%M).dump"
docker compose exec -T db pg_dump -U nepse_trade_journal -Fc nepse_trade_journal_production > "$file"
find ../backups -name 'nepse_*.dump' -mtime +14 -delete
echo "$(date '+%F %T') backup ok: $file ($(du -h "$file" | cut -f1))"
