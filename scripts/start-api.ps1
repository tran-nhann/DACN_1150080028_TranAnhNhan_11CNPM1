param([switch]$Restart)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectPython = Join-Path $projectRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $projectPython)) { throw 'Chạy scripts/setup-backend.ps1 trước.' }
$listener = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($listener -and $Restart) {
    foreach ($servicePid in @($listener.OwningProcess | Select-Object -Unique)) {
        $serviceProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$servicePid"
        $parentProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($serviceProcess.ParentProcessId)"
        $ownedByProject = $serviceProcess.ExecutablePath -eq $projectPython -or $parentProcess.ExecutablePath -eq $projectPython
        if (-not $ownedByProject -or $serviceProcess.CommandLine -notmatch 'backend[\\/]manage.py.*runserver.*127.0.0.1:8000') {
            throw 'Cổng 8000 đang được ứng dụng khác dùng; không dừng ứng dụng đó.'
        }
        Stop-Process -Id $servicePid
    }
    $listener = $null
}
$logDirectory = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
if (-not $listener) {
    Start-Process -FilePath $projectPython -ArgumentList @('-X', 'utf8', 'backend/manage.py', 'runserver', '127.0.0.1:8000', '--noreload') -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory 'backend.stdout.log') -RedirectStandardError (Join-Path $logDirectory 'backend.stderr.log') | Out-Null
}
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $health = Invoke-RestMethod 'http://127.0.0.1:8000/api/v1/health/' -TimeoutSec 2
        if ($health.status -eq 'ok') { Write-Host 'API sẵn sàng: http://127.0.0.1:8000'; exit 0 }
    } catch { }
    Start-Sleep -Milliseconds 500
}
throw 'API chưa khởi động được. Xem .artifacts/backend.stderr.log.'
