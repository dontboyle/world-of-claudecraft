# Creates the desktop shortcut folder: Start Server, Stop Server, Rebuild and Restart
# Server, Play (Chrome or Edge in app mode on this PC), and the FORK.md runbook.
# Safe to rerun; it overwrites only the shortcuts it creates.
param(
  [string]$Folder = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'World of ClaudeCraft'),
  [switch]$NoPause
)
. (Join-Path $PSScriptRoot '_common.ps1')

$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$gameIcon = "$(Join-Path $RepoRoot 'build\icon.ico'),0"
$browser = @(
  (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

New-Item -ItemType Directory -Force -Path $Folder | Out-Null
$shell = New-Object -ComObject WScript.Shell

function New-Shortcut([string]$Name, [string]$Target, [string]$Arguments, [string]$Description) {
  $link = $shell.CreateShortcut((Join-Path $Folder "$Name.lnk"))
  $link.TargetPath = $Target
  $link.Arguments = $Arguments
  $link.WorkingDirectory = $RepoRoot
  $link.IconLocation = $gameIcon
  $link.Description = $Description
  $link.Save()
  Write-Host "  $Name"
}

function New-ScriptShortcut([string]$Name, [string]$Script, [string]$Description) {
  $file = Join-Path $PSScriptRoot $Script
  New-Shortcut $Name $powershell "-NoProfile -File `"$file`"" $Description
}

Write-Host "Creating shortcuts in $Folder"
New-ScriptShortcut 'Start Server' 'start-server.ps1' 'Start Postgres and the game server'
New-ScriptShortcut 'Stop Server' 'stop-server.ps1' 'Save everyone, stop the game server and Postgres'
New-ScriptShortcut 'Rebuild and Restart Server' 'rebuild-server.ps1' 'Rebuild after code changes and restart'
if ($browser) {
  New-Shortcut 'Play World of ClaudeCraft' $browser "--app=http://localhost:$ServerPort/ --start-maximized" 'Play on this PC'
} else {
  Write-Warning 'Neither Chrome nor Edge was found; skipped the Play shortcut.'
}
New-Shortcut 'How it works (FORK.md)' (Join-Path $RepoRoot 'FORK.md') '' 'Setup and rebuild instructions'
Wait-BeforeClose 3
