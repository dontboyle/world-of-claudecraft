# Copies a finished build into out/ under a versioned name: the LAN Android APK or the
# Windows installer. out/ ignores itself (out/.gitignore is '*'), so nothing upstream changes.
param(
  [Parameter(Mandatory = $true)] [ValidateSet('android', 'desktop')] [string]$Kind
)
. (Join-Path $PSScriptRoot '_common.ps1')

$out = Join-Path $RepoRoot 'out'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ignore = Join-Path $out '.gitignore'
if (-not (Test-Path $ignore)) { Set-Content -Path $ignore -Value '*' -Encoding ASCII }
$version = (Get-Content (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json).version

if ($Kind -eq 'android') {
  $from = Join-Path $RepoRoot 'android\app\build\outputs\apk\play\debug\app-play-debug.apk'
  $to = Join-Path $out "world-of-claudecraft-$version-android-lan-debug.apk"
} else {
  # electron-builder names it ${name}-${version}-${os}-${arch}.${ext} (package.json build).
  $from = Join-Path $RepoRoot "release\world-of-claudecraft-$version-win-x64.exe"
  $to = Join-Path $out "world-of-claudecraft-$version-windows-x64-setup.exe"
}
if (-not (Test-Path $from)) {
  Write-Host "Build output not found: $from" -ForegroundColor Red
  exit 1
}
Copy-Item -Path $from -Destination $to -Force
Write-Host "Copied to $to"
exit 0
