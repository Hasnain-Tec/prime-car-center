# Prime Car Center — Full-Stack Workshop System

This package converts the supplied Flutter prototype into a shared web-and-Android system based on the customer's Prime Car Center design.

## Included functions

- Flutter responsive web and Android frontend
- Django REST backend and PostgreSQL/SQLite support
- Secure login with JWT access and refresh tokens
- User registration with administrator approval
- Pending, active, suspended, rejected, and disabled account states
- Administrator-created users and password reset
- Custom roles and direct allow/deny permission overrides
- Per-job assignment with independent permissions for view, photo, amounts, print, edit, parts, status, completion, and deletion
- Sequential server-generated invoice numbers
- Vehicle photo capture/gallery upload using cross-platform bytes
- Multiple parts/materials, labour charges, totals, status, priority, due date, and internal instructions
- Searchable job records, editing, deletion, assignment, status updates, and PDF invoices
- Expense submission, approval/rejection, deletion, and filters
- Admin-only revenue, approved expenses, and profit/loss reporting
- Financial PDF report
- Workshop name, contact, license/VAT, currency, invoice prefix, and footer settings
- Audit/activity logs
- Backup and restore scripts
- Docker/VPS deployment configuration

## Project folders

- `frontend/` — Flutter application
- `backend/` — Django API, database models, security, and PDF generation
- `deploy/` — Docker Compose and Nginx configuration
- `scripts/` — local setup and backup/restore utilities
- `reference/` — customer HTML and the originally supplied Flutter `lib` ZIP

# Local setup on Windows

## Prerequisites

Install:

- Flutter stable and Android Studio/Android SDK
- Python 3.11 or 3.12
- VS Code with Flutter and Python extensions

## Automatic setup

Open PowerShell in the extracted project folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup_windows.ps1
```

The script installs backend dependencies, creates database migrations, migrates the database, generates missing Flutter Android/web wrappers, and downloads Flutter packages.

## Create the first Super Admin

```powershell
cd backend
.\.venv\Scripts\python.exe manage.py createsuperuser
```

Use this account for the first login. A superuser automatically has every permission.

## Start the backend

```powershell
cd backend
.\.venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

## Start Flutter Web

Open a second terminal:

```powershell
cd frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Start Android emulator

```powershell
cd frontend
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For a physical Android device, replace `10.0.2.2` with the computer's local network IP, for example:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

Also add that frontend origin/IP to `backend/.env` under `CORS_ALLOWED_ORIGINS` when required.

# First-use workflow

1. Sign in with the Super Admin account.
2. Open **Workshop Info** and enter business details.
3. Open **Roles** and confirm or customize role permissions.
4. A new person submits registration from the login page.
5. Open **Users → Pending**, assign a role, and approve the account.
6. Create a job and assign users with exact per-job permissions.
7. Profit/loss appears only for users with `finance.view_profit_loss`.

# Permission model

Final access combines:

- Role permissions
- Direct user `ALLOW` overrides
- Direct user `DENY` overrides
- Per-job assignment permissions

The backend checks permissions even when a frontend button is hidden, preventing API bypass.

# Build release versions

## Web

```powershell
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://your-domain.com/api
```

## Android APK

```powershell
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.com/api
```

## Android App Bundle

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-domain.com/api
```

Configure your Android signing keystore before publishing. Never commit the keystore or passwords.

# VPS deployment with Docker

1. Copy `deploy/.env.production.example` to `deploy/.env`.
2. Replace all placeholder values and add the real domain.
3. Generate migrations locally once and keep the generated migration file in `backend/workshop/migrations/`.
4. From the `deploy` folder run:

```bash
docker compose --env-file .env up -d --build
```

5. Create the production superuser:

```bash
docker compose --env-file .env exec backend python manage.py createsuperuser
```

6. Point the domain/subdomain DNS A record to the VPS IP.
7. Put HTTPS in front using Hostinger's proxy, Cloudflare, or Certbot/Nginx.

# Backup and restore

Linux/VPS backup:

```bash
./scripts/backup_linux.sh
```

Restore:

```bash
./scripts/restore_linux.sh ./backups/YYYYMMDD-HHMMSS
```

Also maintain automated PostgreSQL volume/database backups at the VPS provider level.

# Important security notes

- Replace `DJANGO_SECRET_KEY` before deployment.
- Use PostgreSQL in production, not SQLite.
- Keep `.env`, passwords, database dumps, signing keys, and SSH keys private.
- Use HTTPS in production.
- The included calculation follows the customer prototype: `Revenue = Materials + Labour`; `Profit/Loss = Revenue - Approved Expenses`.
- The customer HTML is stored only as a requirements/design reference; the deployed application uses Flutter and Django.

# Validation status

- Python files passed static compilation checks.
- Flutter relative imports and delimiter structure were checked.
- The execution environment used to prepare this package did not include the Flutter SDK or downloadable Python packages, so run `setup_windows.ps1` and then `flutter analyze` / Django tests on your development computer before production deployment.
