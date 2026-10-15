<#
.SYNOPSIS
    Builds the Nuzuln Flutter apps in release mode and collects them in dist/.

.DESCRIPTION
    mobile         -> Android APK            (apps/nuzuln: teacher, guardian and student in one app)
    admin_desktop  -> Windows folder + zip   (apps/admin_desktop)
    admin_android  -> Android APK            (apps/admin_desktop, the phone layout)

    Each app is built on its own: one failure does not stop the others, and the
    summary at the end says what was produced and what was not. The exit code is
    non-zero if any app that was attempted failed.

    The server address baked into the build (MOUSQE_API_BASE_URL) is only the
    default. The user can switch between nuzuln.com and a local server at any time
    by tapping the logo three times on the splash screen.

    Every export is a new version of the whole system, recorded in docs/VERSION.md:
    the script reads the last versions there, computes the next one, builds all
    apps with it, and only if every build succeeded adds the entry at the top of
    its section (Release or Beta). A failed export records nothing.

.PARAMETER Channel
    beta (default) or release.
      beta    : X.Y.Z-beta.N. Continues the open beta (beta.1 -> beta.2), or opens
                a new one on the next version (see -Bump) after a release.
      release : X.Y.Z. Takes the number of the open beta (1.1.0-beta.3 -> 1.1.0),
                or bumps the last release (see -Bump) when there is no beta.
    The build number is one counter for both channels and always goes up.
    A release refuses to run on uncommitted changes.

.PARAMETER Bump
    minor (default), major or patch: how the version moves when a new number is
    needed. A hotfix straight to release: -Channel release -Bump patch

.PARAMETER Notes
    Highlights of this version, one per item. When omitted, they are taken from
    the feat/fix/perf commit subjects since the previous version. From cmd or
    "pwsh -File", separate items with ';'.

.PARAMETER DryRun
    Print the next version, build number and notes, then stop: nothing is built
    and docs/VERSION.md is not touched.

.PARAMETER Only
    Build only these apps (mobile, admin_desktop, admin_android), e.g.
    -Only mobile,admin_desktop

.PARAMETER BaseUrl
    Default API address compiled into the apps. Default: https://nuzuln.com/api/v1

.PARAMETER OutDir
    Where the artifacts go. Default: <repo>/dist. Each version gets its own
    folder inside it, by channel: dist/beta/1.0.0-beta.5/, dist/release/1.0.0/.

.PARAMETER SkipPubGet
    Do not run "flutter pub get" at the workspace root, and pass --no-pub to the
    builds and tests. Use it when pub.dev is unreachable and packages are cached.

.PARAMETER Clean
    Run "flutter clean" in each app before building.

.PARAMETER SkipTests
    Do not run "flutter test" in each app before building.

.EXAMPLE
    .\scripts\export-apps.ps1 -DryRun

.EXAMPLE
    .\scripts\export-apps.ps1 -Notes 'first note','second note'

.EXAMPLE
    .\scripts\export-apps.ps1 -Channel release

.EXAMPLE
    .\scripts\export-apps.ps1 -Only mobile -BaseUrl http://192.168.1.10:8000/api/v1
#>
[CmdletBinding()]
param(
    [string[]]$Only,

    [ValidateSet('beta', 'release')]
    [string]$Channel = 'beta',

    [ValidateSet('major', 'minor', 'patch')]
    [string]$Bump = 'minor',

    [string[]]$Notes,

    [switch]$DryRun,

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
# Each app builds from its own folder, so a relative -OutDir is pinned to where the script was run.
$OutDir = [IO.Path]::GetFullPath($OutDir, (Get-Location).Path)
$versionFile = Join-Path $root 'docs/VERSION.md'

$apps = @(
    @{ Name = 'mobile';        Dir = 'apps/nuzuln';        Kind = 'apk' },
    @{ Name = 'admin_desktop'; Dir = 'apps/admin_desktop'; Kind = 'windows' },
    @{ Name = 'admin_android'; Dir = 'apps/admin_desktop'; Kind = 'apk' }
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

# --- VERSION.md -------------------------------------------------------------
# Read and written as UTF-8 explicitly: Windows PowerShell 5.1 would otherwise
# read the Arabic text as ANSI. This script stays ASCII-only for the same reason.

$entryPattern = '(?m)^### (\d+)\.(\d+)\.(\d+)(?:-beta\.(\d+))? - build (\d+) - \S+\s*\r?\n\s*\r?\nCommit `([0-9a-f]+)`'

function Read-Versions([string]$text) {
    foreach ($m in [regex]::Matches($text, $entryPattern)) {
        $g = $m.Groups
        [pscustomobject]@{
            Base   = [version]"$($g[1].Value).$($g[2].Value).$($g[3].Value)"
            Beta   = if ($g[4].Success) { [int]$g[4].Value } else { $null }
            Build  = [int]$g[5].Value
            Commit = $g[6].Value
        }
    }
}

function Step-Version([version]$v, [string]$how) {
    switch ($how) {
        'major' { return [version]"$($v.Major + 1).0.0" }
        'minor' { return [version]"$($v.Major).$($v.Minor + 1).0" }
        default { return [version]"$($v.Major).$($v.Minor).$($v.Build + 1)" }
    }
}

# The next version of the system, from what VERSION.md says shipped already.
function Get-NextVersion($entries, [string]$channel, [string]$bump) {
    $releases = @($entries | Where-Object { $null -eq $_.Beta } | Sort-Object Base)
    $betas = @($entries | Where-Object { $null -ne $_.Beta } | Sort-Object Base, Beta)

    $lastRelease = if ($releases.Count) { $releases[-1].Base } else { [version]'0.0.0' }
    $lastBeta = if ($betas.Count) { $betas[-1] } else { $null }
    # A beta is open while no release has taken its number yet.
    $openBeta = $lastBeta -and $lastBeta.Base -gt $lastRelease

    if ($channel -eq 'release') {
        $base = if ($openBeta) { $lastBeta.Base } else { Step-Version $lastRelease $bump }
        $label = "$base"
    }
    else {
        if ($openBeta) { $base = $lastBeta.Base; $n = $lastBeta.Beta + 1 }
        else { $base = Step-Version $lastRelease $bump; $n = 1 }
        $label = "$base-beta.$n"
    }

    $build = 1
    if (@($entries).Count) { $build = (@($entries) | Measure-Object -Property Build -Maximum).Maximum + 1 }

    [pscustomobject]@{ Base = "$base"; Label = $label; Build = [int]$build }
}

# Highlights: the -Notes given, or the feat/fix/perf subjects since the last version.
function Get-ReleaseNotes($given, $entries) {
    $items = @($given | ForEach-Object { $_ -split ';' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($items.Count) { return $items }

    $last = @($entries | Sort-Object Build)
    $range = 'HEAD'
    if ($last.Count) { $range = "$($last[-1].Commit)..HEAD" }

    $subjects = @(git -C $root log --no-merges --format=%s $range 2>$null)
    $prefix = '^(feat|fix|perf)(\([^)]*\))?!?: '
    $items = @($subjects | Where-Object { $_ -match $prefix } | ForEach-Object { $_ -replace $prefix, '' })
    if ($items.Count) { return $items }
    return @('(no highlights recorded)')
}

function Add-VersionEntry([string]$path, [string]$channel, [string[]]$lines) {
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $all = New-Object System.Collections.Generic.List[string]
    $all.AddRange([string[]]($text -split '\r?\n'))

    $marker = "<!-- $channel-entries -->"
    $at = $all.IndexOf($marker)
    if ($at -lt 0) { throw "VERSION.md has no '$marker' line." }

    # The "nothing yet" line of this section goes once it has an entry.
    for ($i = $at + 1; $i -lt $all.Count -and -not $all[$i].StartsWith('## '); $i++) {
        if ($all[$i].EndsWith('<!-- placeholder -->')) { $all.RemoveAt($i); break }
    }

    $all.InsertRange($at + 1, [string[]](@('') + $lines))
    [IO.File]::WriteAllText($path, ($all -join $nl), (New-Object Text.UTF8Encoding($false)))
}

if (-not (Test-Path $versionFile)) { throw "VERSION.md not found at $versionFile" }

$entries = @(Read-Versions ([IO.File]::ReadAllText($versionFile, [Text.Encoding]::UTF8)))
$next = Get-NextVersion $entries $Channel $Bump
$notes = @(Get-ReleaseNotes $Notes $entries)

# One folder per version, by channel, so dist/ never piles up loose files.
$OutDir = Join-Path (Join-Path $OutDir $Channel) $next.Label

# A version names a commit: a release must be exactly one, a beta may say it is not.
$commit = (git -C $root rev-parse --short HEAD).Trim()
$dirty = @(git -C $root status --porcelain -- . ':(exclude)docs/VERSION.md')
$commitLine = "Commit ``$commit``"
if ($dirty.Count) {
    if ($Channel -eq 'release' -and -not $DryRun) {
        throw 'A release is built from a commit: commit or stash the changes first (git status).'
    }
    Write-Host 'WARNING: uncommitted changes - this version is not exactly any commit.' -ForegroundColor Yellow
    $commitLine += ' (+ uncommitted changes)'
}

Write-Host "Version                    : $($next.Label) (build $($next.Build), $Channel)"
Write-Host "Server baked in as default : $BaseUrl"
Write-Host "Output folder              : $OutDir"
Write-Host 'Highlights                 :'
$notes | ForEach-Object { Write-Host "  - $_" }

if ($DryRun) { Write-Host "`nDry run: nothing built, docs/VERSION.md untouched."; exit 0 }

# An APK signed with any other key cannot update the installed app: no release key, no Android export.
# The key lives outside the repository (docs/APP-UPDATES.md, signing key).
if (@($apps | Where-Object { $_.Kind -eq 'apk' -and (Test-Path (Join-Path (Join-Path $root $_.Dir) 'pubspec.yaml')) }).Count) {
    $signing = $env:NUZULN_SIGNING_PROPERTIES
    if (-not $signing) { $signing = Join-Path $env:USERPROFILE '.nuzuln-signing\key.properties' }
    if (-not (Test-Path $signing)) {
        throw "No Android release key at $signing. Restore the backup of .nuzuln-signing (or set NUZULN_SIGNING_PROPERTIES) before exporting APKs."
    }
    Write-Host "Android signing          : $signing"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install Flutter or open a terminal where it works.'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not $SkipPubGet) {
    Write-Step 'flutter pub get (workspace root)'
    Push-Location $root
    try { Invoke-Native 'flutter pub get' { flutter pub get } } finally { Pop-Location }
}

$results = @()
# admin_desktop and admin_android share one project: its tests run once.
$tested = @{}

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
        $stem = "nuzuln-$($name -replace '_', '-')-$($next.Label)-b$($next.Build)"
        $pub = @()
        if ($SkipPubGet) { $pub = @('--no-pub') }
        # Windows version resources take numbers only, so the exe carries X.Y.Z;
        # Android's versionName is free text and carries the beta label.
        $buildName = if ($app.Kind -eq 'apk') { $next.Label } else { $next.Base }
        $buildArgs = @(
            '--release',
            "--dart-define=MOUSQE_API_BASE_URL=$BaseUrl",
            "--build-name=$buildName",
            "--build-number=$($next.Build)"
        ) + $pub

        Push-Location $dir
        try {
            if ($Clean) { Invoke-Native 'flutter clean' { flutter clean } }
            if (-not $SkipTests -and (Test-Path 'test') -and -not $tested[$app.Dir]) {
                Invoke-Native "$name tests" { flutter test @pub }
                $tested[$app.Dir] = $true
            }

            if ($app.Kind -eq 'apk') {
                # ARM only (64 and 32 bit): x86_64 serves emulators, and its libraries were a third
                # of the APK (docs/suggestions/SUGGESTIONS.md, 1.2 #2).
                Invoke-Native "$name apk build" { flutter build apk @buildArgs --target-platform android-arm,android-arm64 }
                $built = Join-Path $dir 'build/app/outputs/flutter-apk/app-release.apk'
                $target = Join-Path $OutDir "$stem.apk"
                Copy-Item -Force $built $target
            }
            else {
                $built = Join-Path $dir 'build/windows/x64/runner/Release'
                # A plugin dropped since the last build leaves its DLL behind: start from an empty folder.
                if (Test-Path $built) { Remove-Item -Recurse -Force $built }
                Invoke-Native "$name windows build" { flutter build windows @buildArgs }
                # The Visual C++ runtime travels with the app, so a PC without the redistributable
                # still starts it (Flutter's Windows deployment guidance).
                foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
                    $source = Join-Path $env:SystemRoot "System32\$dll"
                    if (Test-Path $source) { Copy-Item -Force $source $built }
                    else { Write-Host "WARNING: $dll not found - the zip needs the VC++ redistributable." -ForegroundColor Yellow }
                }
                $target = Join-Path $OutDir "$stem-windows.zip"
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

$failed = @($results | Where-Object { $_.Status -eq 'FAILED' })
$built = @($results | Where-Object { $_.Status -eq 'ok' })

if ($failed.Count -gt 0) {
    Write-Host "docs/VERSION.md not updated: $($next.Label) did not ship." -ForegroundColor Red
    exit 1
}

if ($built.Count -gt 0) {
    # What each program needs to run travels with the files.
    Copy-Item -Force (Join-Path $root 'docs/REQUIREMENTS.md') (Join-Path $OutDir 'REQUIREMENTS.md')

    $entry = @(
        "### $($next.Label) - build $($next.Build) - $(Get-Date -Format 'yyyy-MM-dd')",
        '',
        "$commitLine - apps: $(($built | ForEach-Object { $_.App }) -join ', ')",
        ''
    ) + @($notes | ForEach-Object { "- $_" })

    Add-VersionEntry $versionFile $Channel $entry
    Write-Host "docs/VERSION.md: $($next.Label) (build $($next.Build)) added under $Channel - commit it." -ForegroundColor Green
}
