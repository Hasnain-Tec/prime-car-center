#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$ROOT/backups/$STAMP"
mkdir -p "$DEST"
cd "$ROOT/backend"
PYTHON="${PYTHON:-.venv/bin/python}"
$PYTHON manage.py dumpdata workshop --indent 2 > "$DEST/database.json"
if [ -d media ]; then tar -czf "$DEST/media.tar.gz" media; fi
printf 'Backup created at %s\n' "$DEST"
