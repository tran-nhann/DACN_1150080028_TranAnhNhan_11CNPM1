$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectRoot '.artifacts'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
@{ status = 'running'; started_at = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDirectory 'android-build-result.json')
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'flutter.ps1') build apk --debug --target-platform android-x64 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/
$buildExit = $LASTEXITCODE
@{ status = 'finished'; exit_code = $buildExit; finished_at = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDirectory 'android-build-result.json')
exit $buildExit
