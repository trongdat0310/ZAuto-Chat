param(
    [string]$BackendUrl = "https://api.zchatauto.io.vn",
    [switch]$UseExistingApk
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$oldLocation = Get-Location

function Run-Checked([string]$Exe, [string[]]$Args) {
    Write-Host ""
    Write-Host ("==> " + $Exe + " " + ($Args -join " ")) -ForegroundColor Cyan
    & $Exe @Args | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$Exe exited with status $LASTEXITCODE"
    }
}

try {
    Set-Location $projectRoot

    $backend = $null
    if (-not [System.Uri]::TryCreate(
        $BackendUrl, [System.UriKind]::Absolute, [ref]$backend
    ) -or $backend.Scheme -ne "https") {
        throw "Release BACKEND_URL must be an absolute HTTPS URL."
    }

    # Release Gradle configuration refuses to substitute a debug signing key.
    # Production approval requires a signed APK verified by apksigner.
    $keyConfig = Join-Path $projectRoot "android\key.properties"
    if (-not (Test-Path $keyConfig)) {
        throw "Missing android/key.properties. Run .\tool\setup_release_signing.ps1 first. Never commit the signing key."
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $changes = @(git status --porcelain --untracked-files=normal)
        if ($LASTEXITCODE -ne 0) { throw "Unable to inspect Git working tree." }
        if ($changes.Count -gt 0 -and -not (
            $changes.Count -eq 1 -and [string]::IsNullOrWhiteSpace($changes[0])
        )) {
            throw "Working tree has uncommitted changes. Commit/stash them before a reproducible release build."
        }
        $revision = (git rev-parse --short HEAD).Trim()
        Write-Host "Source revision: $revision"
    } else {
        Write-Warning "git not available; source revision cannot be verified."
    }

    $versionLine = Get-Content ".\pubspec.yaml" |
        Where-Object { $_ -match '^version:\s*' } |
        Select-Object -First 1
    Write-Host "App $versionLine"
    Write-Host "Backend origin: $BackendUrl"

    if (-not $UseExistingApk) {
        Run-Checked "flutter" @("pub", "get")
        Run-Checked "flutter" @("analyze")
        Run-Checked "flutter" @("test")
        Run-Checked "flutter" @(
            "build", "apk", "--release",
            "--dart-define=BACKEND_URL=$BackendUrl"
        )
    } else {
        Write-Warning "UseExistingApk: compilation, analyzer and tests are NOT run in this invocation."
    }

    $apk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apk)) {
        throw "Release APK not found at $apk"
    }
    $apkInfo = Get-Item $apk
    if ($apkInfo.Length -lt 1MB) {
        throw "APK is unexpectedly small; verify the release build."
    }

    # Fails closed if unsigned, untrusted or incorrectly packaged.
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "tool\release_smoke.ps1") -ApkPath $apk -SkipInstall
    if ($LASTEXITCODE -ne 0) {
        throw "Release smoke signature validation failed."
    }

    $hash = Get-FileHash -Path $apk -Algorithm SHA256
    Write-Host ""
    Write-Host "RELEASE SIGNATURE CHECK: PASS" -ForegroundColor Green
    Write-Host ("APK bytes: {0}" -f $apkInfo.Length)
    Write-Host ("APK SHA256: {0}" -f $hash.Hash)
    Write-Host "Next: install on a test phone and complete Phase 5 manual checks."
    Write-Host "Signed APK is not automatically published by this script."
} finally {
    Set-Location $oldLocation
}
