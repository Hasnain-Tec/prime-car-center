#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

printf '\n== Prime Car Center: backend setup ==\n'
cd "$ROOT/backend"
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
[ -f .env ] || cp .env.example .env
.venv/bin/python manage.py makemigrations workshop
.venv/bin/python manage.py migrate

printf '\n== Prime Car Center: Flutter setup ==\n'
cd "$ROOT/frontend"
if [ ! -d android ]; then
  flutter create . --platforms=android,web --project-name prime_car_center
fi
flutter pub get

printf '\nSetup finished. Create the first administrator with:\n'
printf 'cd backend && .venv/bin/python manage.py createsuperuser\n'
