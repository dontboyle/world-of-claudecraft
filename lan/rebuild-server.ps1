# Rebuild and Restart shortcut, for after you pull or commit changes: saves and stops the
# server, reinstalls dependencies, rebuilds the client, and starts the server again.
# Browser players get the new client on their next page load.
param([switch]$NoPause)
. (Join-Path $PSScriptRoot '_common.ps1')

try {
  Stop-GameServer
  Set-Location $RepoRoot
  Invoke-Checked pnpm install --frozen-lockfile
  Invoke-Checked pnpm run build
} catch {
  Write-Host $_ -ForegroundColor Red
  Wait-BeforeClose
  exit 1
}
& (Join-Path $PSScriptRoot 'start-server.ps1') -NoPause:$NoPause
exit $LASTEXITCODE
