param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectPython = Join-Path $projectRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $projectPython) -or -not (Test-Path -LiteralPath (Join-Path $projectRoot 'backend\.env'))) {
    throw 'Chạy scripts/setup-backend.ps1 trước.'
}
if ($Rebuild -or -not (Test-Path -LiteralPath (Join-Path $projectRoot 'mobile\build\web\main.dart.js'))) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'flutter.ps1') build web --no-wasm-dry-run
    if ($LASTEXITCODE -ne 0) { throw 'Build Flutter thất bại.' }
}
$logDirectory = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
foreach ($service in @(
    @{ Port = 8000; Name = 'backend'; Arguments = @('-X', 'utf8', 'backend/manage.py', 'runserver', '127.0.0.1:8000', '--noreload') },
    @{ Port = 4173; Name = 'preview'; Arguments = @('-X', 'utf8', '-m', 'http.server', '4173', '--bind', '127.0.0.1', '--directory', 'mobile/build/web') }
)) {
    $listener = Get-NetTCPConnection -LocalPort $service.Port -State Listen -ErrorAction SilentlyContinue
    if (-not $listener) {
        Start-Process -FilePath $projectPython -ArgumentList $service.Arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory ($service.Name + '.stdout.log')) -RedirectStandardError (Join-Path $logDirectory ($service.Name + '.stderr.log')) | Out-Null
    }
}
$ready = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    try {
        $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8000/api/v1/health/' -TimeoutSec 2
        $preview = Invoke-WebRequest -Uri 'http://127.0.0.1:4173' -UseBasicParsing -TimeoutSec 2
        if ($health.status -eq 'ok' -and $preview.Content -match '<title>Aster Hotel</title>') { $ready = $true; break }
    } catch { }
    Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw 'Không khởi động được app hoặc cổng đang được ứng dụng khác dùng. Xem log trong .artifacts.' }
Write-Host 'App sẵn sàng: http://127.0.0.1:4173'
Write-Host 'Tài khoản: admin / letan / quanly. Mật khẩu nằm trong backend/.env (DEMO_PASSWORD).'
