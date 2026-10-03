# Builds the desktop app against the hosted project and wraps it in a setup.exe.
#
#   .\scripts\build_windows.ps1                 # uses .env.production
#   .\scripts\build_windows.ps1 -EnvFile .env.staging
#
# Output: apps\ops_desktop\build\installer\InmoreOperations-Setup-<version>.exe
# Needs Inno Setup 6:  winget install JRSoftware.InnoSetup

param([string]$EnvFile)

. "$PSScriptRoot\common.ps1"

$envFile = Get-BuildEnvFile $EnvFile
$app     = Join-Path $RepoRoot 'apps\ops_desktop'
$version = Get-AppVersion $app
$release = Join-Path $app 'build\windows\x64\runner\Release'

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found. Install it with: winget install JRSoftware.InnoSetup' }

Push-Location $app
try {
    Invoke-Checked flutter @('build', 'windows', '--release', "--dart-define-from-file=$envFile")
} finally {
    Pop-Location
}

# A Flutter exe needs the MSVC runtime.  Office PCs often don't have it, and
# the failure is a bare "VCRUNTIME140_1.dll was not found" - ship the three
# DLLs next to the exe instead of asking anyone to install a redistributable.
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    $source = Join-Path "$env:WINDIR\System32" $dll
    if (-not (Test-Path $source)) { throw "$source missing; install the Visual C++ 2015-2022 x64 redistributable on this build machine." }
    Copy-Item $source $release -Force
}

Invoke-Checked $iscc @("/DAppVersion=$version", (Join-Path $app 'installer\inmore_ops.iss'))

$setup = Join-Path $app "build\installer\InmoreOperations-Setup-$version.exe"
Write-Host ''
Write-Host "Installer: $setup" -ForegroundColor Green
