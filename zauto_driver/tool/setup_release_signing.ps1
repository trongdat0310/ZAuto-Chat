param(
    [string]$Alias = "upload",
    [string]$KeystorePath = ""
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
        $_ -and (Test-Path (Join-Path $_ "bin\keytool.exe"))
    }

    return $candidates | Select-Object -First 1
}

function Read-RequiredSecureString([string]$Prompt) {
    while ($true) {
        $secure = Read-Host $Prompt -AsSecureString

        if ($secure.Length -gt 0) {
            return $secure
        }

        Write-Host "Value cannot be empty." -ForegroundColor Yellow
    }
}

function ConvertTo-PlainText([Security.SecureString]$Secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)

    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$projectRoot = (Get-Location).Path

if (-not $KeystorePath) {
    $KeystorePath = Join-Path $projectRoot "android\app\zautochat-upload.jks"
} elseif (-not [System.IO.Path]::IsPathRooted($KeystorePath)) {
    $KeystorePath = Join-Path $projectRoot $KeystorePath
}

$keyPropertiesPath = Join-Path $projectRoot "android\key.properties"

$javaHome = Find-JavaHome

if (-not $javaHome) {
    throw "JDK/keytool was not found. Install Android Studio or JDK 17+."
}

$keytool = Join-Path $javaHome "bin\keytool.exe"

Write-Step "Release signing setup"

Write-Host "JAVA_HOME: $javaHome"
Write-Host "Keystore: $KeystorePath"
Write-Host "Alias: $Alias"
Write-Host "key.properties: $keyPropertiesPath"

if (Test-Path $KeystorePath) {
    throw "Keystore already exists: $KeystorePath. Refusing to overwrite it."
}

if (Test-Path $keyPropertiesPath) {
    throw "android/key.properties already exists. Back it up or delete it before generating a new signing identity."
}

$parent = Split-Path $KeystorePath -Parent

if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$storeSecure = Read-RequiredSecureString "Enter keystore password"
$keySecure = Read-RequiredSecureString "Enter key password"

$storePassword = ConvertTo-PlainText $storeSecure
$keyPassword = ConvertTo-PlainText $keySecure

if ($storePassword.Length -lt 6) {
    throw "Keystore password must be at least 6 characters."
}

if ($keyPassword.Length -lt 6) {
    throw "Key password must be at least 6 characters."
}

Write-Step "Generating upload keystore"

$keytoolArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $KeystorePath,
    "-storepass", $storePassword,
    "-keypass", $keyPassword,
    "-alias", $Alias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-dname", "CN=ZAutoChat Pro, OU=Mobile, O=ZAutoChat, L=Unknown, ST=Unknown, C=VN"
)

& $keytool @keytoolArgs

if ($LASTEXITCODE -ne 0) {
    throw "keytool failed to generate the keystore."
}

$relativeStorePath = [System.IO.Path]::GetRelativePath(
    (Join-Path $projectRoot "android\app"),
    $KeystorePath
).Replace("\", "/")

$properties = @(
    "storePassword=$storePassword",
    "keyPassword=$keyPassword",
    "keyAlias=$Alias",
    "storeFile=$relativeStorePath"
) -join [Environment]::NewLine

Set-Content -Path $keyPropertiesPath -Value $properties -Encoding ASCII

$storePassword = $null
$keyPassword = $null

Write-Host ""
Write-Host "Release signing files created." -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "  Back up this keystore somewhere safe:"
Write-Host "  $KeystorePath"
Write-Host ""
Write-Host "  Never commit the keystore or android/key.properties."
Write-Host ""
Write-Host "Next commands:"
Write-Host "  flutter clean"
Write-Host "  flutter build apk --release"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\tool\release_smoke.ps1 -SkipInstall"
