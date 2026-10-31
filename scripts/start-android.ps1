param([switch]$Build, [switch]$RestartApi)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$aliasRoot = Join-Path $env:LOCALAPPDATA 'AsterHotel\workspace'
$toolchain = Get-Content -LiteralPath (Join-Path $projectRoot '.tools\android-toolchain.json') -Raw | ConvertFrom-Json
$env:JAVA_HOME = Join-Path $aliasRoot $toolchain.jdk_relative
$env:ANDROID_HOME = Join-Path $aliasRoot $toolchain.sdk_relative
$env:ANDROID_AVD_HOME = Join-Path $aliasRoot '.tools\avd'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
$apk = Join-Path $aliasRoot 'mobile\build\app\outputs\flutter-apk\app-debug.apk'
$apiArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'start-api.ps1'))
if ($RestartApi) { $apiArguments += '-Restart' }
& powershell.exe @apiArguments
if ($LASTEXITCODE -ne 0) { throw 'Không khởi động được API.' }
if ($Build -or -not (Test-Path -LiteralPath $apk)) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'build-android.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Build APK thất bại.' }
}
$device = (& $adb devices | Select-String '^emulator-\d+\s+device$' | Select-Object -First 1)
if (-not $device) {
    $projectDrive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($projectRoot))
    if ($projectDrive.AvailableFreeSpace -lt 5GB) {
        $freeGb = [Math]::Round($projectDrive.AvailableFreeSpace / 1GB, 1)
        throw "Ổ đĩa còn $freeGb GB. Cần tối thiểu 5 GB trống để khởi động giả lập; hãy dọn thêm dung lượng rồi chạy lại script."
    }
    $emulator = Join-Path $env:ANDROID_HOME 'emulator\emulator.exe'
    $logDirectory = Join-Path $projectRoot '.artifacts'
    # Visible window is intentional: the user is trying the app on this emulator.
    Start-Process -FilePath $emulator -ArgumentList @('-avd', 'Aster_API34', '-no-snapshot', '-no-boot-anim', '-no-audio', '-memory', '1536', '-cores', '2', '-gpu', 'host', '-feature', '-Vulkan', '-scale', '0.7') -WindowStyle Normal -RedirectStandardOutput (Join-Path $logDirectory 'emulator.stdout.log') -RedirectStandardError (Join-Path $logDirectory 'emulator.stderr.log') | Out-Null
}
Write-Host 'Đang chờ giả lập Android khởi động...'
for ($attempt = 0; $attempt -lt 180; $attempt++) {
    $device = (& $adb devices | Select-String '^emulator-\d+\s+device$' | Select-Object -First 1)
    if ($device) {
        $deviceId = ($device.Line -split '\s+')[0]
        if ((& $adb -s $deviceId shell -n getprop sys.boot_completed).Trim() -eq '1') { break }
    }
    Start-Sleep -Seconds 1
}
if (-not $device -or (& $adb -s $deviceId shell -n getprop sys.boot_completed).Trim() -ne '1') { throw 'Giả lập chưa khởi động. Xem log emulator trong .artifacts.' }
& $adb -s $deviceId install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Cài APK thất bại.' }
& $adb -s $deviceId reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) { throw 'Không tạo được kết nối API qua ADB.' }
& $adb -s $deviceId shell am start -n vn.asterhotel.aster_hotel/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'Mở app thất bại.' }
Write-Host 'Aster Hotel đã mở trên giả lập Android.'
