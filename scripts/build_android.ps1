# Builds the owner's Android app against the hosted project, release-signed.
#
#   .\scripts\build_android.ps1                 # uses .env.production
#   .\scripts\build_android.ps1 -EnvFile .env.staging
#
# Output: apps\owner_mobile\build\Inmore-<version>.apk
# Needs apps\owner_mobile\android\key.properties - see README, "Android app".

param([string]$EnvFile)

. "$PSScriptRoot\common.ps1"

$envFile = Get-BuildEnvFile $EnvFile
$app     = Join-Path $RepoRoot 'apps\owner_mobile'
$version = Get-AppVersion $app

# Gradle falls back to the debug key without this, so `flutter run --release`
# still works on a dev machine.  A build meant for the owner's phone must not:
# an APK signed with a different key won't install over the previous one.
$keyProps = Join-Path $app 'android\key.properties'
if (-not (Test-Path $keyProps)) {
    throw 'No android\key.properties - this APK would be signed with the debug key. See README, "Android app".'
}
if (Select-String -Path $keyProps -Pattern '^\s*\w*Password\s*=\s*CHANGE_ME\s*$' -Quiet) {
    throw "$keyProps still has CHANGE_ME - put the keystore password in it."
}
$storeFile = (Select-String -Path $keyProps -Pattern '^storeFile=(.+)$').Matches[0].Groups[1].Value.Trim()
if (-not (Test-Path $storeFile)) { throw "Keystore $storeFile not found (storeFile in $keyProps)." }

Push-Location $app
try {
    Invoke-Checked flutter @('build', 'apk', '--release', "--dart-define-from-file=$envFile")
} finally {
    Pop-Location
}

$apk = Join-Path $app "build\Inmore-$version.apk"
Copy-Item (Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk') $apk -Force
Write-Host ''
Write-Host "APK: $apk" -ForegroundColor Green
