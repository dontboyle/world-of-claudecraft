# Stop Server shortcut: save and stop the game server, then stop Postgres.
param([switch]$NoPause)
. (Join-Path $PSScriptRoot '_common.ps1')

try {
  Stop-GameServer
  Stop-Database
  Write-Host 'Stopped.' -ForegroundColor Green
  Wait-BeforeClose 3
} catch {
  Write-Host $_ -ForegroundColor Red
  Wait-BeforeClose
  exit 1
}
