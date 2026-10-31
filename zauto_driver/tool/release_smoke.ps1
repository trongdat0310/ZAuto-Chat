param(
    [string]$ApkPath = "build\app\outputs\flutter-apk\app-release.apk",
    [string]$PackageName = "com.example.zauto_driver",
    [switch]$SkipInstall,
    [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-CommandPath([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    return $null
}

function Find-AndroidSdk {
    $candidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object { $_ -and (Test-Path $_) }

    return $candidates | Select-Object -First 1
}

function Find-BuildTool([string]$SdkRoot, [string]$FileName) {
    if (-not $SdkRoot) {
        return $null
    }

    $root = Join-Path $SdkRoot "build-tools"
    if (-not (Test-Path $root)) {
        return $null
    }

    $versions = Get-ChildItem $root -Directory |
        Sort-Object {
            try {
                [version]$_.Name
            } catch {
                [version]"0.0"
            }
        } -Descending

    foreach ($version in $versions) {
        $candidate = Join-Path $version.FullName $FileName
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null

}

function Find-JavaHome {
    $javaFromPath = Resolve-CommandPath "java"

    if ($javaFromPath) {
        return Split-Path (Split-Path $javaFromPath -Parent) -Parent
    }

    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")

    $candidates = @(
        $env:JAVA_HOME,
        $env:STUDIO_JDK,
        (Join-Path $env:ProgramFiles "Android\Android Studio\jbr"),
        (Join-Path $env:ProgramFiles "Android\Android Studio\jre"),
        (Join-Path $programFilesX86 "Android\Android Studio\jbr"),
        (Join-Path $programFilesX86 "Android\Android Studio\jre"),
        (Join-Path $env:LOCALAPPDATA "Programs\Android Studio\jbr"),
        (Join-Path $env:LOCALAPPDATA "Programs\Android Studio\jre")
    ) | Where-Object {
        $_ -and (Test-Path (Join-Path $_ "bin\java.exe"))
    }

    return $candidates | Select-Object -First 1
}

function Ensure-JavaEnvironment {
    $javaHome = Find-JavaHome

    if (-not $javaHome) {
        throw "Java runtime was not found. Open Android Studio once or install JDK 17, then retry."
    }

    $javaExe = Join-Path $javaHome "bin\java.exe"

    if (-not (Test-Path $javaExe)) {
        throw "Java executable was not found under: $javaHome"
    }

    $env:JAVA_HOME = $javaHome

    $javaBin = Join-Path $javaHome "bin"

    if (-not (($env:PATH -split ";") -contains $javaBin)) {
        $env:PATH = "$javaBin;$env:PATH"
    }

    Write-Host "JAVA_HOME: $javaHome"

    return $javaExe
}

$projectRoot = (Get-Location).Path
$resolvedApk = if ([System.IO.Path]::IsPathRooted($ApkPath)) {
    $ApkPath
} else {
    Join-Path $projectRoot $ApkPath
}

Write-Step "Checking release APK"

if (-not (Test-Path $resolvedApk)) {
    throw "APK not found: $resolvedApk. Run: flutter build apk --release"
}

$apkInfo = Get-Item $resolvedApk
Write-Host ("APK: {0}" -f $apkInfo.FullName)
Write-Host ("Size: {0:N1} MB" -f ($apkInfo.Length / 1MB))

$sdkRoot = Find-AndroidSdk
if ($sdkRoot) {
    Write-Host "Android SDK: $sdkRoot"
}

Write-Step "Verifying APK signature"

$null = Ensure-JavaEnvironment

$apksigner = Resolve-CommandPath "apksigner"
if (-not $apksigner) {
    $apksigner = Find-BuildTool $sdkRoot "apksigner.bat"
}

if (-not $apksigner) {
    throw "apksigner was not found. Install Android SDK Build-Tools or add it to PATH."
}

& $apksigner verify --verbose --print-certs $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw "APK signature verification failed."
}

Write-Host "APK signature: OK" -ForegroundColor Green

if ($SkipInstall) {
    Write-Host ""
    Write-Host "Signature check completed. Install step skipped." -ForegroundColor Green
    exit 0
}

Write-Step "Checking ADB device"

$adb = Resolve-CommandPath "adb"
if (-not $adb -and $sdkRoot) {
    $candidate = Join-Path $sdkRoot "platform-tools\adb.exe"
    if (Test-Path $candidate) {
        $adb = $candidate
    }
}

if (-not $adb) {
    throw "adb was not found. Install Android SDK Platform-Tools or add adb to PATH."
}

$deviceLines = & $adb devices |
    Select-Object -Skip 1 |
    Where-Object { $_ -match "\sdevice$" }

if (-not $deviceLines) {
    throw "No authorized Android device found. Enable USB debugging and accept the computer authorization prompt."
}

Write-Host "Connected device:"
$deviceLines | ForEach-Object { Write-Host "  $_" }

Write-Step "Installing release APK"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    $installOutput = & $adb install -r $resolvedApk 2>&1
    $installExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

$installOutput | ForEach-Object {
    Write-Host $_
}

if ($installExitCode -ne 0) {
    $installText = ($installOutput | Out-String)

    $signatureMismatch =
        $installText -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE" -or
        $installText -match "signatures do not match"

    if ($signatureMismatch) {
        Write-Host ""
        Write-Host "Existing app uses a different signing key." -ForegroundColor Yellow

        if (-not $ReplaceExisting) {
            Write-Host ""
            Write-Host "The current app must be uninstalled before this release-signed build can be installed." -ForegroundColor Yellow
            Write-Host "WARNING: uninstalling removes this app's local data on the device." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Run again with:" -ForegroundColor Cyan
            Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\release_smoke.ps1 -ReplaceExisting"
            throw "APK install blocked by signing-key mismatch."
        }

        Write-Step "Removing differently signed existing app"

        & $adb uninstall $PackageName | Out-Host

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to uninstall existing package: $PackageName"
        }

        Write-Step "Installing release APK after uninstall"

        & $adb install $resolvedApk | Out-Host

        if ($LASTEXITCODE -ne 0) {
            throw "APK install failed after removing the old package."
        }
    } else {
        throw "adb install failed."
    }
}

Write-Host "Install: OK" -ForegroundColor Green

Write-Step "Launching $PackageName"

& $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host
Start-Sleep -Seconds 2

$pidOutput = (& $adb shell pidof $PackageName 2>$null).Trim()

if (-not $pidOutput) {
    throw "App did not stay running after launch. Check: adb logcat"
}

Write-Host "App process PID: $pidOutput"
Write-Host ""
Write-Host "Release APK smoke bootstrap: PASS" -ForegroundColor Green
Write-Host ""
Write-Host "Continue manual checks:"
Write-Host "  1. Login / logout"
Write-Host "  2. Zalo link / relink"
Write-Host "  3. Home realtime + reconnect"
Write-Host "  4. Foreground notification"
Write-Host "  5. Messages pin / unpin / delete / unread"
Write-Host "  6. Chat send / reply / recall / delete"
Write-Host "  7. Photo album / image / video / file"
Write-Host "  8. Background -> foreground"
Write-Host "  9. Network off -> on"
Write-Host " 10. App restart"
