# Shared helpers for the LAN server scripts in this folder (dot-sourced by each of them).
# Fork-only tooling; see FORK.md. Written for Windows PowerShell 5.1 so the desktop
# shortcuts need nothing beyond what ships with Windows.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ServerPort = 8787

# Runs a native command and throws when it fails. Plain function on purpose: $args keeps
# flags such as --frozen-lockfile as text instead of binding them as parameters.
function Invoke-Checked {
  $exe = $args[0]
  $rest = @($args | Select-Object -Skip 1)
  & $exe @rest
  if ($LASTEXITCODE -ne 0) { throw "'$($args -join ' ')' failed with exit code $LASTEXITCODE." }
}

# Shortcut windows pause so errors stay readable; VS Code tasks pass -NoPause.
function Wait-BeforeClose([int]$Seconds = 0) {
  if ($NoPause) { return }
  if ($Seconds -gt 0) { Start-Sleep -Seconds $Seconds } else { Read-Host 'Press Enter to close' | Out-Null }
}

function Get-LanAddresses {
  Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
      $_.InterfaceAlias -notlike 'vEthernet*'
    } |
    Select-Object -ExpandProperty IPAddress
}

function Get-ServerProcess {
  $conn = Get-NetTCPConnection -LocalPort $ServerPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $conn) { return $null }
  return Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
}

function Test-DockerEngine {
  docker info *> $null
  return ($LASTEXITCODE -eq 0)
}

function Start-Database {
  if (-not (Test-DockerEngine)) {
    $desktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (-not (Test-Path $desktop)) { throw 'Docker is not running and Docker Desktop was not found.' }
    Write-Host 'Starting Docker Desktop...'
    Start-Process $desktop
    $ready = $false
    for ($i = 0; $i -lt 90 -and -not $ready; $i++) {
      Start-Sleep -Seconds 2
      $ready = Test-DockerEngine
    }
    if (-not $ready) { throw 'Docker Desktop did not become ready within 3 minutes.' }
  }
  Write-Host 'Starting Postgres...'
  Push-Location $RepoRoot
  try { Invoke-Checked docker compose up -d --wait postgres } finally { Pop-Location }
}

function Stop-Database {
  if (-not (Test-DockerEngine)) { return }
  Write-Host 'Stopping Postgres...'
  Push-Location $RepoRoot
  try { Invoke-Checked docker compose stop postgres } finally { Pop-Location }
}

# The server saves every character on SIGINT (server/main.ts shutdown). On Windows that
# means a real Ctrl+C in its console; closing the window or Stop-Process skips the save.
function Stop-GameServer {
  $proc = Get-ServerProcess
  if (-not $proc) { Write-Host 'The game server is not running.'; return }
  if ($proc.ProcessName -ne 'node') {
    throw "Port $ServerPort belongs to '$($proc.ProcessName)' (PID $($proc.Id)), not the Node game server. If you host with Docker, run 'docker compose stop game'."
  }
  Write-Host "Asking the game server (PID $($proc.Id)) to save and shut down..."
  $helper = Join-Path $PSScriptRoot 'send-ctrl-c.ps1'
  Start-Process powershell.exe -WindowStyle Hidden -Wait -ArgumentList @(
    '-NoProfile', '-File', "`"$helper`"", '-ProcessId', $proc.Id
  )
  if ($proc.WaitForExit(60000)) { Write-Host 'Game server stopped cleanly.'; return }
  Write-Warning 'The server did not exit within 60 seconds; forcing it. Progress since its last autosave may be lost.'
  Stop-Process -Id $proc.Id -Force
}
