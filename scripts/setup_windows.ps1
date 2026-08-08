$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "== Prime Car Center: backend setup ==" -ForegroundColor Cyan
Set-Location "$Root\backend"
if (-not (Test-Path ".venv")) { py -m venv .venv }
& ".\.venv\Scripts\python.exe" -m pip install --upgrade pip
& ".\.venv\Scripts\pip.exe" install -r requirements.txt
if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env" }
& ".\.venv\Scripts\python.exe" manage.py makemigrations workshop
& ".\.venv\Scripts\python.exe" manage.py migrate

Write-Host "== Prime Car Center: Flutter setup ==" -ForegroundColor Cyan
Set-Location "$Root\frontend"
if (-not (Test-Path "android")) {
  flutter create . --platforms=android,web --project-name prime_car_center
}
flutter pub get

Write-Host "" 
Write-Host "Setup finished." -ForegroundColor Green
Write-Host "Create the first administrator:" -ForegroundColor Yellow
Write-Host "  cd backend"
Write-Host "  .\.venv\Scripts\python.exe manage.py createsuperuser"
Write-Host "Then start backend and frontend using README.md."
