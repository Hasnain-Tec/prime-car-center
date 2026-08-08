#!/usr/bin/env bash
set -euo pipefail
if [ $# -ne 1 ]; then echo "Usage: $0 /path/to/backup-folder"; exit 1; fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP="$(cd "$1" && pwd)"
cd "$ROOT/backend"
PYTHON="${PYTHON:-.venv/bin/python}"
$PYTHON manage.py loaddata "$BACKUP/database.json"
if [ -f "$BACKUP/media.tar.gz" ]; then tar -xzf "$BACKUP/media.tar.gz"; fi
printf 'Restore completed from %s\n' "$BACKUP"
