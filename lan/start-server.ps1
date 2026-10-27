# Start Server shortcut: Docker and Postgres, a fresh server bundle (plus the client build
# if dist/ is missing), then the server in its own window.
param([switch]$NoPause)
. (Join-Path $PSScriptRoot '_common.ps1')

try {
  if (Get-ServerProcess) {
    Write-Host "The game server is already running on port $ServerPort."
    Wait-BeforeClose 3
    exit 0
  }
  Start-Database
  Set-Location $RepoRoot
  if (-not (Test-Path (Join-Path $RepoRoot 'dist\index.html'))) {
    Write-Host 'No client build found; building it (a few minutes)...'
    Invoke-Checked pnpm run build
  }
  Write-Host 'Bundling the server...'
  Invoke-Checked node scripts/build_server.mjs
  Start-Process powershell.exe -WorkingDirectory $RepoRoot -ArgumentList @(
    '-NoProfile', '-File', "`"$(Join-Path $PSScriptRoot 'run-server.ps1')`""
  )
  Write-Host 'The server is starting in its own window.' -ForegroundColor Green
  Wait-BeforeClose 3
} catch {
  Write-Host $_ -ForegroundColor Red
  Wait-BeforeClose
  exit 1
}
