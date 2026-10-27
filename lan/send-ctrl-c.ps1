# Sends Ctrl+C to the console that owns -ProcessId, the only way to raise SIGINT in a
# Windows Node process from outside. Runs in its own hidden PowerShell (see Stop-GameServer
# in _common.ps1) because it has to leave its own console to attach to the server's.
param([Parameter(Mandatory = $true)] [int]$ProcessId)

Add-Type -Namespace WocLan -Name Kernel32 -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool FreeConsole();
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool AttachConsole(uint processId);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleCtrlHandler(IntPtr handler, bool add);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GenerateConsoleCtrlEvent(uint ctrlEvent, uint processGroupId);
'@

[WocLan.Kernel32]::FreeConsole() | Out-Null
if (-not [WocLan.Kernel32]::AttachConsole([uint32]$ProcessId)) { exit 2 }
# Ignore the Ctrl+C ourselves, then raise it for every process on that console.
[WocLan.Kernel32]::SetConsoleCtrlHandler([IntPtr]::Zero, $true) | Out-Null
$sent = [WocLan.Kernel32]::GenerateConsoleCtrlEvent(0, 0)
Start-Sleep -Milliseconds 500
[WocLan.Kernel32]::FreeConsole() | Out-Null
if ($sent) { exit 0 } else { exit 3 }
