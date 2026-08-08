#!/usr/bin/env sh
set -e
# The first local setup generates migration files. This fallback makes a clean handoff deployable.
if ! ls workshop/migrations/0*.py >/dev/null 2>&1; then
  python manage.py makemigrations workshop --noinput
fi
python manage.py migrate --noinput
python manage.py collectstatic --noinput
exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 120
