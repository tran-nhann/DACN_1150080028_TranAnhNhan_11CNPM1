param()
# Preserve Flutter --debug instead of consuming the PowerShell common parameter.
$FlutterArguments = @($args)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Flutter 3.47 LSP currently fails on the Unicode workspace name on this machine.
# A junction offers an ASCII working path without moving or duplicating source.
$aliasParent = Join-Path $env:LOCALAPPDATA 'AsterHotel'
$aliasPath = Join-Path $aliasParent 'workspace'
New-Item -ItemType Directory -Path $aliasParent -Force | Out-Null
if (-not (Test-Path -LiteralPath $aliasPath)) {
    New-Item -ItemType Junction -Path $aliasPath -Target $projectRoot | Out-Null
}
$aliasTarget = @((Get-Item -LiteralPath $aliasPath).Target)
if ($aliasTarget.Count -ne 1 -or $aliasTarget[0].TrimEnd('\') -ne $projectRoot.TrimEnd('\')) {
    throw 'Đường dẫn alias đã trỏ tới dự án khác; không thay đổi thư mục đó.'
}
$flutterExecutable = Join-Path $aliasPath '.tools\flutter\bin\flutter.bat'
$toolchainPath = Join-Path $aliasPath '.tools\android-toolchain.json'
if (Test-Path -LiteralPath $toolchainPath) {
    $toolchain = Get-Content -LiteralPath $toolchainPath -Raw | ConvertFrom-Json
    $env:JAVA_HOME = Join-Path $aliasPath $toolchain.jdk_relative
    $env:ANDROID_HOME = Join-Path $aliasPath $toolchain.sdk_relative
    $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
    $env:ANDROID_AVD_HOME = Join-Path $aliasPath '.tools\avd'
    # Gradle canonicalizes junction paths; keep its Kotlin DSL cache on a
    # physical ASCII path as well as using the ASCII workspace junction.
    $env:GRADLE_USER_HOME = Join-Path $aliasParent 'gradle'
}
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Thiếu Flutter SDK trong .tools/flutter. Xem README.md.'
}
Push-Location -LiteralPath (Join-Path $aliasPath 'mobile')
try { & $flutterExecutable @FlutterArguments; $toolResult = $LASTEXITCODE }
finally { Pop-Location }
exit $toolResult
