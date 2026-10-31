$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
if (-not (Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
    python -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Không tạo được Python venv.' }
}
$projectPython = Join-Path $projectRoot '.venv\Scripts\python.exe'
& $projectPython -m pip install -r backend/requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Không cài được dependencies.' }
& $projectPython scripts/setup_local.py
if ($LASTEXITCODE -ne 0) { throw 'Không kết nối được SQL Server. Kiểm tra backend/.env.' }
& $projectPython backend/manage.py migrate --noinput
if ($LASTEXITCODE -ne 0) { throw 'Migrations thất bại.' }
& $projectPython backend/manage.py seed_demo
if ($LASTEXITCODE -ne 0) { throw 'Seed thất bại.' }
Write-Host 'Tài khoản: admin / letan / quanly. Mật khẩu: DEMO_PASSWORD trong backend/.env.'
