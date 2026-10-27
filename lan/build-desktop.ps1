# Builds the Windows installer pointed at this PC's LAN server and copies the x64 setup exe
# into out/. Upstream's electron-builder config also builds arm64, whose native-module
# rebuild needs Visual Studio's ARM64 C++ tools; without them that half fails AFTER the x64
# installer is finished, so a fresh, complete x64 installer counts as success here.
# Overwrites dist/: rebuild the browser client afterwards (the VS Code task does).
param([string]$LanHost, [switch]$NoPause)
. (Join-Path $PSScriptRoot '_common.ps1')

try {
  if (-not $LanHost) { $LanHost = @(Get-LanAddresses)[0] }
  if (-not $LanHost) { throw 'No LAN address found; pass -LanHost <this PC IP>.' }
  $env:VITE_DESKTOP_API_ORIGIN = "http://${LanHost}:$ServerPort"
  Write-Host "Building the desktop app for $env:VITE_DESKTOP_API_ORIGIN"
  $version = (Get-Content (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json).version
  $exe = Join-Path $RepoRoot "release\world-of-claudecraft-$version-win-x64.exe"
  $started = Get-Date

  Set-Location $RepoRoot
  & pnpm run electron:build
  $code = $LASTEXITCODE
  # electron-builder writes the blockmap only once the installer itself is complete.
  $fresh = (Test-Path $exe) -and (Test-Path "$exe.blockmap") -and
    ((Get-Item "$exe.blockmap").LastWriteTime -gt $started)
  if ($code -ne 0) {
    if (-not $fresh) { throw "electron:build failed (exit $code) before the x64 installer was finished." }
    Write-Warning 'electron:build failed after the x64 installer was finished (normally the arm64 variant, which needs the MSVC ARM64 build tools). The x64 installer is complete.'
  }
  & (Join-Path $PSScriptRoot 'copy-to-out.ps1') -Kind desktop
  if ($LASTEXITCODE -ne 0) { throw 'Copying the installer into out/ failed.' }
  Wait-BeforeClose 3
} catch {
  Write-Host $_ -ForegroundColor Red
  Wait-BeforeClose
  exit 1
}
