# Fork notes: hosting on a Windows PC for LAN play

This fork runs the game server on one Windows PC and plays it from phones and PCs on the
same Wi-Fi. Upstream's own guides still apply: `README.md` (host and develop),
`docs/mobile-store-release.md` (Android), `docs/desktop-release.md` (desktop). This file
records what this fork adds and the exact steps that worked here.

Every step has a VS Code task (Ctrl+Shift+P, then "Tasks: Run Task"); task names are in
**bold**. The tasks live in `.vscode/tasks.json`.

## Machine prerequisites (once per PC)

| Tool | Notes |
|---|---|
| Node 26 | CI and the Dockerfile use 26 (`node -v`). |
| pnpm 10.34.5 | `npm install -g pnpm@10.34.5`, the version pinned in `package.json` `packageManager`. |
| Docker Desktop | Runs Postgres. Turn on "Start Docker Desktop when you sign in". |
| Android Studio | Supplies the SDK (`%LOCALAPPDATA%\Android\Sdk`), adb, and JDK 21 (`C:\Program Files\Android\Android Studio\jbr`). The Java 17 on PATH is too old for Capacitor 8. |

adb is not on PATH; the tasks call `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
directly. Add that folder to PATH if you want `adb` in a terminal.

The `lan\*.ps1` scripts need PowerShell to allow local scripts for your user (already true
on this PC; check with `Get-ExecutionPolicy -List`):
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. The shortcuts do not bypass it.

## One-time repo setup

1. **Setup: install dependencies** (`pnpm install --frozen-lockfile`).
2. Secrets (both files are git-ignored; this fork is public, never commit them):
   - `.env.local` holds the generated Postgres password.
   - `.env` is a copy of `.env.example` with `POSTGRES_PASSWORD` and the password inside
     `DATABASE_URL` set to that same value. Docker compose reads only `.env`; the server
     reads both.
   - The password is baked into the Docker volume `world-of-claudecraft_eastbrook_pgdata`
     on first start. Deleting that volume deletes every account and character.
3. Windows Firewall (once): **Setup: allow LAN through Windows Firewall (admin)**, or
   `lan\allow-firewall.ps1`, which shows a UAC prompt and adds this rule (same as running
   it in an admin PowerShell):
   ```powershell
   New-NetFirewallRule -DisplayName "World of ClaudeCraft LAN" -Direction Inbound -Protocol TCP -LocalPort 8787,5173 -Profile Private -Action Allow
   ```
   Node's own allow rules on this PC cover only the Public profile, and the Wi-Fi network
   is Private, so without this rule other devices time out. Start Server checks for the
   rule (or a node.exe rule covering port 8787 on the current network profile) and offers
   to add it; the server window also prints a warning while it is missing. The rule only
   applies on Private networks: if Windows marked the Wi-Fi as Public, switch it to Private
   in Settings rather than opening the port on Public networks.

## Desktop shortcuts

**Setup: create desktop shortcuts** (or `lan\install-shortcuts.ps1`) fills
`Desktop\World of ClaudeCraft` with:

| Shortcut | Does |
|---|---|
| Start Server | Starts Docker Desktop if needed, Postgres, bundles the server (and builds the client if `dist/` is missing), then runs the server in its own window titled "World of ClaudeCraft Server". Warns, and offers to fix it, if the firewall blocks other devices. |
| Stop Server | Sends Ctrl+C to the server so it saves every character, then stops Postgres. Forces the stop only if the server has not exited after 60 seconds. |
| Rebuild and Restart Server | After pulling or committing changes: stops the server, `pnpm install`, rebuilds the client, starts again. Browser players get the new version on their next page load. |
| Play World of ClaudeCraft | Chrome (or Edge) in app mode at `http://localhost:8787`. |
| How it works (FORK.md) | This file. |

The scripts live in `lan/`; rerun the setup task if the repo moves. Close the server window
with the Stop Server shortcut or Ctrl+C in it, never the X: the server saves characters only
on Ctrl+C (SIGINT), and Windows gives a closed console no chance to run that.

## Run the world

- **Host: LAN world (built client on :8787)** (also Ctrl+Shift+B): starts Postgres, builds
  the client into `dist/`, starts the server. Join at `http://<this PC's IP>:8787`; on
  this PC use `http://localhost:8787`.
- **Server: run (:8787, all interfaces)**: server only, when `dist/` is already built.
- **Dev: online stack (LAN)**: Postgres, server, and the hot-reload client on `:5173`.
  Offline mode exists only in this dev client.
- Stop with **Server: stop (saves characters)** or Ctrl+C in the server's terminal. The
  trash-can "terminate task" button kills the process without the save. **DB: stop all
  compose services** stops Postgres.
- This PC's IP: `ipconfig`, Wi-Fi adapter, IPv4. It was `192.168.1.251` when this was
  written. A DHCP reservation in the router keeps it fixed; the tasks prompt for it with
  that default.

## Phone in a browser

Open `http://<this PC's IP>:8787` in Chrome. Touch controls appear automatically.

## Phone with the Android app

### Pair adb over Wi-Fi (once per phone)

Phone: Settings, Developer options, Wireless debugging, "Pair device with pairing code".
Run **Android: pair phone (Wi-Fi, one time)** with the pairing IP:port and the code.

### Connect (each session)

The connect port is NOT the pairing port. It is on the Wireless debugging screen under
"IP address & Port" and changes whenever wireless debugging restarts. Run **Android:
connect phone (Wi-Fi)**. `adb mdns services` finds nothing on this PC; if you cannot read
the port on the phone, this PowerShell scan finds it:

```powershell
$ip='192.168.1.200'; $open=@(); for ($s=30000; $s -lt 50000; $s+=1000) { $p=@(); foreach ($n in $s..($s+999)) { $c=New-Object System.Net.Sockets.TcpClient; $p+=[pscustomobject]@{N=$n;C=$c;T=$c.ConnectAsync($ip,$n)} }; Start-Sleep -Milliseconds 600; foreach ($x in $p) { if ($x.T.IsCompleted -and -not $x.T.IsFaulted -and $x.C.Connected) { $open+=$x.N }; $x.C.Dispose() } }; $open
```

### Build and install

**Android: LAN APK (bundle, build, install)** runs these tasks in order:

1. **Android: web bundle for LAN server + cap sync**: builds `dist/` with
   `VITE_NATIVE_APP=1` and `VITE_API_ORIGIN=http://<this PC's IP>:8787`, prunes duplicate
   media, runs `cap sync android`, then `.vscode/disable_native_ota.mjs`.
2. **Android: build debug APK**: `.\gradlew.bat assemblePlayDebug` with `JAVA_HOME` set to
   Android Studio's JDK, then copies
   `android/app/build/outputs/apk/play/debug/app-play-debug.apk` (about 1.3 GB) to
   `out/world-of-claudecraft-<version>-android-lan-debug.apk`.
3. **Android: install debug APK on phone**: `adb install -r` (about 100 seconds over
   Wi-Fi).

4. **Build: web client (dist/)**: step 1 overwrites `dist/` with the native bundle, which
   the server would otherwise serve to browsers. Run it yourself if you ran step 1 alone.

The server address is baked into the APK, so rebuild it if this PC's IP changes. Game
data (accounts, characters) lives on the server, so uninstalling the app loses nothing.

The APK is signed with this PC's Android debug key (`%USERPROFILE%\.android\debug.keystore`).
Android only installs an update signed with the same key, so back that file up: an APK
built on another PC (or after losing the key) needs the old app uninstalled first.

### Why the tasks do not call `pnpm run native:sync`

That script uses POSIX `VAR=value command` syntax, which cmd.exe cannot run on Windows.
The tasks set the same variables through `options.env` and inline the steps.

### Why OTA updates are off in these builds

Upstream's `capacitor.config.ts` turns on `@capgo/capacitor-updater` against
`https://worldofclaudecraft.com/api/ota/updates`. A fork build left that way would download
upstream's next web bundle and start talking to the live server. The helper
`.vscode/disable_native_ota.mjs` sets `autoUpdate: false` in the generated, git-ignored
`android/app/src/main/assets/capacitor.config.json`, so upstream's file stays untouched.

## PC client

On this PC, the Play shortcut. On other PCs, a browser at `http://<this PC's IP>:8787`, or
the installer:

**Desktop: LAN installer to out/ (then restore web build)** runs `lan\build-desktop.ps1`:
`pnpm run electron:build` with `VITE_DESKTOP_API_ORIGIN=http://<this PC's IP>:8787`, then
copies the x64 installer to `out/world-of-claudecraft-<version>-windows-x64-setup.exe`.
After that the task rebuilds the browser client (the desktop build overwrites `dist/`).

Upstream's config also builds an arm64 installer. On this PC that half fails, because
recompiling the `bigint-buffer` native module for arm64 needs Visual Studio's MSVC ARM64
build tools, which are not installed. It fails after the x64 installer is finished, so the
script accepts the run when the x64 installer and its blockmap were both written during
it, and prints a warning. Install the ARM64 C++ tools in Visual Studio Installer if you
ever want the arm64 build. The installer is unsigned, so Windows SmartScreen warns on first
run ("More info", then "Run anyway").

The installed app keeps upstream's updater, which checks
`updates.worldofclaudecraft.com/desktop` on its "dev" track. Upstream published no dev feed
when this was written (`dev.yml` answered 404), and `electron/update_guard.cjs` refuses any
update stamped for a server address other than this build's, so it never swaps itself for
upstream's build. To update a PC, rerun the installer.

## Build outputs: `out/`

Finished APKs and installers land in `out/`, which ignores itself (`out/.gitignore` is
`*`), so builds never show up in git. `lan\copy-to-out.ps1 -Kind android|desktop` does the
copying. Do not use `dist/` for this: it is the browser build the server serves, it is
wiped on every build, and it gets copied into the APK.

## Gotchas found while setting this up

- Claude Code's shell sets `NoDefaultCurrentDirectoryInExePath=1`, so cmd.exe will not run
  a bare `gradlew.bat` from the current folder. The task uses `.\gradlew.bat`.
- `docker-compose.yml` publishes 8787 on `127.0.0.1` only, so `docker compose up` hosting
  is not reachable from the LAN as shipped.
- Plain http on a LAN IP is not a browser "secure context". The client already guards the
  affected APIs (`crypto.randomUUID`, `crypto.subtle`), so it works anyway.
- The phone has a second Android user (Secure Folder), so `pm list packages` needs
  `--user 0`.

## Pulling upstream changes

```powershell
git remote add upstream https://github.com/levy-street/world-of-claudecraft.git  # once
git fetch upstream
git merge upstream/main
```

Then **Setup: install dependencies** and rebuild (**Host: LAN world**, and the Android
APK if you use the app).
