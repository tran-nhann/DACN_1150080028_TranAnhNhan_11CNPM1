$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectRoot
& '.\.venv\Scripts\python.exe' backend/manage.py runserver 127.0.0.1:8000
