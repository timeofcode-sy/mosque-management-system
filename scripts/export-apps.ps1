<#
.SYNOPSIS
    Builds the Nuzuln Flutter apps in release mode and collects them in dist/.

.DESCRIPTION
    teacher        -> Android APK            (apps/teacher)
    admin_desktop  -> Windows folder + zip   (apps/admin_desktop)
    guardian       -> Android APK            (apps/guardian)  skipped until the app exists
    student        -> Android APK            (apps/student)   skipped until the app exists

    Each app is built on its own: one failure does not stop the others, and the
    summary at the end says what was produced and what was not. The exit code is
    non-zero if any app that was attempted failed.

    The server address baked into the build (MOUSQE_API_BASE_URL) is only the
    default. The user can switch between nuzuln.com and a local server at any time
    by tapping the logo three times on the splash screen.

.PARAMETER Only
    Build only these apps (teacher, admin_desktop, guardian, student), e.g.
    -Only teacher,admin_desktop

.PARAMETER BaseUrl
    Default API address compiled into the apps. Default: https://nuzuln.com/api/v1

.PARAMETER OutDir
    Where the artifacts go. Default: <repo>/dist

.PARAMETER SkipPubGet
    Do not run "flutter pub get" at the workspace root, and pass --no-pub to the
    builds and tests. Use it when pub.dev is unreachable and packages are cached.

.PARAMETER Clean
    Run "flutter clean" in each app before building.

.PARAMETER SkipTests
    Do not run "flutter test" in each app before building.

.EXAMPLE
    .\scripts\export-apps.ps1

.EXAMPLE
    .\scripts\export-apps.ps1 -Only teacher -BaseUrl http://192.168.1.10:8000/api/v1
#>
[CmdletBinding()]
param(
    [string[]]$Only,

    [string]$BaseUrl = 'https://nuzuln.com/api/v1',

    [string]$OutDir,

    [switch]$SkipPubGet,
    [switch]$Clean,
    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $root 'dist' }

$apps = @(
    @{ Name = 'teacher';       Dir = 'apps/teacher';       Kind = 'apk' },
    @{ Name = 'admin_desktop'; Dir = 'apps/admin_desktop'; Kind = 'windows' },
    @{ Name = 'guardian';      Dir = 'apps/guardian';      Kind = 'apk' },
    @{ Name = 'student';       Dir = 'apps/student';       Kind = 'apk' }
)
if ($Only) {
    # "pwsh -File x.ps1 -Only a,b" delivers one string "a,b" - split it ourselves.
    $wanted = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $unknown = @($wanted | Where-Object { $apps.Name -notcontains $_ })
    if ($unknown.Count -gt 0) {
        throw "Unknown app(s): $($unknown -join ', '). Choose from: $($apps.Name -join ', ')"
    }
    $apps = @($apps | Where-Object { $wanted -contains $_.Name })
}

function Write-Step([string]$text) { Write-Host "`n=== $text" -ForegroundColor Cyan }

# Runs a native command and fails loudly on a non-zero exit code.
function Invoke-Native([string]$what, [scriptblock]$command) {
    & $command
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" }
}

function Get-AppVersion([string]$appDir) {
    $line = Select-String -Path (Join-Path $appDir 'pubspec.yaml') -Pattern '^version:\s*(\S+)' |
        Select-Object -First 1
    if (-not $line) { return '0.0.0' }
    return ($line.Matches[0].Groups[1].Value -replace '\+', '-b')
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install Flutter or open a terminal where it works.'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Server baked in as default : $BaseUrl"
Write-Host "Output folder              : $OutDir"

if (-not $SkipPubGet) {
    Write-Step 'flutter pub get (workspace root)'
    Push-Location $root
    try { Invoke-Native 'flutter pub get' { flutter pub get } } finally { Pop-Location }
}

$results = @()

foreach ($app in $apps) {
    $name = $app.Name
    $dir = Join-Path $root $app.Dir

    if (-not (Test-Path (Join-Path $dir 'pubspec.yaml'))) {
        Write-Host "`n--- $name : skipped (no Flutter project in $($app.Dir) yet)" -ForegroundColor Yellow
        $results += [pscustomobject]@{ App = $name; Status = 'skipped'; Output = '(app not built yet)' }
        continue
    }

    Write-Step "$name ($($app.Kind))"

    try {
        $version = Get-AppVersion $dir
        $pub = @()
        if ($SkipPubGet) { $pub = @('--no-pub') }
        $buildArgs = @('--release', "--dart-define=MOUSQE_API_BASE_URL=$BaseUrl") + $pub

        Push-Location $dir
        try {
            if ($Clean) { Invoke-Native 'flutter clean' { flutter clean } }
            if (-not $SkipTests -and (Test-Path 'test')) {
                Invoke-Native "$name tests" { flutter test @pub }
            }

            if ($app.Kind -eq 'apk') {
                Invoke-Native "$name apk build" { flutter build apk @buildArgs }
                $built = Join-Path $dir 'build/app/outputs/flutter-apk/app-release.apk'
                $target = Join-Path $OutDir "nuzuln-$($name -replace '_', '-')-$version.apk"
                Copy-Item -Force $built $target
            }
            else {
                Invoke-Native "$name windows build" { flutter build windows @buildArgs }
                $built = Join-Path $dir 'build/windows/x64/runner/Release'
                $target = Join-Path $OutDir "nuzuln-$($name -replace '_', '-')-$version-windows.zip"
                if (Test-Path $target) { Remove-Item -Force $target }
                Compress-Archive -Path (Join-Path $built '*') -DestinationPath $target
            }
        }
        finally { Pop-Location }

        $size = '{0:N1} MB' -f ((Get-Item $target).Length / 1MB)
        $results += [pscustomobject]@{ App = $name; Status = 'ok'; Output = "$target ($size)" }
    }
    catch {
        Write-Host "$name FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $results += [pscustomobject]@{ App = $name; Status = 'FAILED'; Output = $_.Exception.Message }
    }
}

Write-Step 'Summary'
$results | Format-Table -AutoSize -Wrap | Out-String | Write-Host

if (@($results | Where-Object { $_.Status -eq 'FAILED' }).Count -gt 0) { exit 1 }
