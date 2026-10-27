# Runs the game server in this window (opened by start-server.ps1). Stop it with the
# Stop Server shortcut or Ctrl+C here: both save every character first. Closing the
# window with X does not.
. (Join-Path $PSScriptRoot '_common.ps1')

$Host.UI.RawUI.WindowTitle = 'World of ClaudeCraft Server'
Set-Location $RepoRoot
Write-Host 'Players join at:' -ForegroundColor Cyan
Write-Host "  http://localhost:$ServerPort   (this PC)"
foreach ($ip in Get-LanAddresses) { Write-Host "  http://${ip}:$ServerPort" }
Write-Host 'Stop with the Stop Server shortcut or Ctrl+C (closing this window skips the final save).'
if (-not (Test-LanFirewall)) {
  Write-Host 'Other devices cannot connect yet: Windows Firewall blocks them. Run lan\allow-firewall.ps1.' -ForegroundColor Yellow
}
Write-Host ''

& node dist-server/server.cjs
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host "The game server exited with code $LASTEXITCODE." -ForegroundColor Red
  Read-Host 'Press Enter to close' | Out-Null
}
