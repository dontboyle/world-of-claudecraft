# Adds the inbound Windows Firewall rule that lets phones and other PCs on Private networks
# reach the server (TCP 8787 for the game, 5173 for the hot-reload dev client). Relaunches
# itself with admin rights, so Windows shows a UAC prompt.
param([switch]$NoPause)
. (Join-Path $PSScriptRoot '_common.ps1')

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  try {
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
      '-NoProfile', '-File', "`"$PSCommandPath`"", '-NoPause'
    )
  } catch {
    Write-Host 'Windows did not grant admin rights, so nothing changed.' -ForegroundColor Yellow
    Wait-BeforeClose
    exit 1
  }
  if (Test-LanFirewall) {
    Write-Host 'Firewall rule is in place.' -ForegroundColor Green
    Wait-BeforeClose 3
    exit 0
  }
  Write-FirewallHelp
  Wait-BeforeClose
  exit 1
}

if (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue) {
  Write-Host "'$FirewallRuleName' already exists."
} else {
  # Keep in step with $FirewallRuleCommand in _common.ps1 (the text shown to the user).
  New-NetFirewallRule -DisplayName $FirewallRuleName -Direction Inbound -Protocol TCP `
    -LocalPort 8787, 5173 -Profile Private -Action Allow | Out-Null
  Write-Host "Added '$FirewallRuleName'." -ForegroundColor Green
}
Wait-BeforeClose 3
