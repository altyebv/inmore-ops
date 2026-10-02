# Shared by the build scripts.  Dot-source it: . "$PSScriptRoot\common.ps1"

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path

# Reads .env.production (or the file given) and refuses to build against the
# local stack: an installer that points at 127.0.0.1 installs fine and then
# fails to sign anyone in, on every machine it went to.
function Get-BuildEnvFile([string]$Path) {
    if (-not $Path) { $Path = Join-Path $RepoRoot '.env.production' }
    if (-not (Test-Path $Path)) {
        throw "No $Path. Copy .env.example to .env.production and fill in the hosted project's URL and publishable key."
    }
    $values = @{}
    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*([A-Z_]+)\s*=\s*(.+?)\s*$') { $values[$Matches[1]] = $Matches[2] }
    }
    $url = $values['SUPABASE_URL']
    $key = $values['SUPABASE_PUBLISHABLE_KEY']
    if (-not $url -or $url -notmatch '^https://' -or $url -match 'your-project-ref') {
        throw "SUPABASE_URL in $Path must be the hosted https:// project URL (got '$url')."
    }
    if (-not $key -or $key -notmatch '^sb_publishable_' -or $key -match 'x{10}') {
        throw "SUPABASE_PUBLISHABLE_KEY in $Path must be the project's sb_publishable_ key."
    }
    Write-Host "Building against $url"
    return (Resolve-Path $Path).Path
}

# pubspec `version: 1.2.3+4` -> '1.2.3'
function Get-AppVersion([string]$AppDir) {
    $line = Select-String -Path (Join-Path $AppDir 'pubspec.yaml') -Pattern '^version:\s*([0-9.]+)'
    return $line.Matches[0].Groups[1].Value
}

function Invoke-Checked([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}
