# Sombr iOS

Personal remote-control app for triggering `somedl` on a Chromebook (Ubuntu) over SSH.
The phone never plays audio — it searches iTunes metadata and dispatches download commands
to the Chromebook via SSH.

---

## What the app does

1. **Settings tab** — stores SSH credentials (host, port, username, private key or
   password) in the iOS Keychain. "Test Connection" verifies somedl is reachable.
2. **Search tab** — queries the iTunes Search API for tracks. Each row shows artwork,
   title, artist, album, and duration. Tapping **Download** opens (or reuses) an SSH
   session and runs `somedl 'Artist - Title'` on the Chromebook. Live stdout/stderr
   stream into a log sheet.

---

## Prerequisites

### On the Chromebook

```bash
pip install SomeDL          # or pip3
somedl --version            # verify
```

`somedl` must be on the PATH for the SSH login shell. If you installed with pip into
`~/.local/bin`, make sure that directory is in `~/.bashrc` or `~/.profile`.

### On your Mac (development)

- Xcode 15.2 or later
- A free Apple ID (no paid developer account required for personal sideloading)
- The iPhone connected via USB at least once to trust the Mac

---

## Xcode project setup

### 1. Create the project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Set:
   - **Product Name**: `sombr_iOS`
   - **Team**: your personal Apple ID team
   - **Bundle Identifier**: `com.<yourname>.sombr` (must be unique on your device)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployments**: iOS 17.0
4. Save inside `sombr_iOS_/` (the repo root)

### 2. Replace the default source files

Delete `ContentView.swift` that Xcode generated, then drag all `.swift` files from the
`sombr_iOS/` folder into the Xcode project navigator:

```
sombr_iOS/
├── sombr_iOSApp.swift
├── ContentView.swift
├── Models/
│   ├── SSHConfig.swift
│   ├── SearchResult.swift
│   └── DownloadJob.swift
├── Services/
│   ├── KeychainService.swift
│   ├── SSHManager.swift
│   └── MetadataService.swift
├── ViewModels/
│   ├── SettingsViewModel.swift
│   └── SearchViewModel.swift
└── Views/
    ├── SettingsView.swift
    ├── SearchView.swift
    ├── SearchResultRow.swift
    └── LogView.swift
```

When dragging, check **Copy items if needed** and **Add to target: sombr_iOS**.

### 3. Add the Citadel SSH package

Citadel is a modern async/await SSH client for Swift, built on SwiftNIO.

1. In Xcode: **File → Add Package Dependencies…**
2. Paste the URL: `https://github.com/orlandos-nl/Citadel`
3. Set **Dependency Rule** to **Up to Next Major Version** from `0.7.0`
4. Click **Add Package** and tick the `Citadel` library product for the `sombr_iOS` target

> **Note on Citadel version**: The `SSHManager.swift` code uses:
> - `SSHClient.connect(host:port:authenticationMethod:hostKeyValidator:)`
> - `client.executeCommand(_:)` returning `ByteBuffer`
> - `client.executeCommandStream(_:)` returning a stream with `.stdout` / `.stderr`
> - `NIOSSHPrivateKey(openSSHPrivateKey:)` — provided by Citadel for OpenSSH PEM parsing
>
> If a newer Citadel release renames these, check their [CHANGELOG](https://github.com/orlandos-nl/Citadel).

### 4. Entitlements — no extras needed

The app uses only outbound TCP (no special entitlement) and the iOS Keychain (available
to all signed apps). You do not need a provisioning profile beyond the default personal
team certificate.

---

## Sideloading to your iPhone (free Apple ID)

1. Connect iPhone via USB, trust the Mac if prompted.
2. In Xcode, select your iPhone in the scheme toolbar (top-left dropdown).
3. **Product → Run** (⌘R). Xcode will sign and install the app.
4. On the iPhone: **Settings → General → VPN & Device Management** → your Apple ID →
   **Trust**. Then open Sombr.

With a free account the app re-signs every 7 days. Re-run from Xcode to refresh.

---

## Using the app

### Settings

| Field | Example |
|-------|---------|
| Host | `192.168.1.42` (Chromebook's LAN IP or a Tailscale address) |
| Port | `22` |
| Username | your Linux username on the Chromebook |
| Auth | **Private Key** (preferred) or password |

For a private key: paste the full contents of `~/.ssh/id_ed25519` (or whichever key
you have configured for SSH login). Ed25519 and ECDSA P-256 keys work; RSA may require
a newer Citadel release.

Tap **Test Connection** — it runs `which somedl` over SSH and reports success or an
error message.

### Search & Download

1. Type any search term (artist, song, album) in the search bar and hit Return.
2. The list shows up to 15 tracks from the iTunes catalogue with artwork.
3. Tap **Download** on a row. The app runs:
   ```
   somedl 'Artist - Title'
   ```
   The argument is single-quoted and embedded single-quotes are escaped, so there is no
   shell injection risk.
4. The row status cycles: **Connecting → Running → Done ✓** (or **Error**).
5. Tap the terminal icon (⬛) on any row to open the live log sheet and watch yt-dlp
   progress in real time.

---

## Architecture

```
App
 └─ ContentView (TabView)
     ├─ SearchView      ← SearchViewModel → MetadataService (iTunes API)
     │                                   → SSHManager (Citadel)
     └─ SettingsView    ← SettingsViewModel → KeychainService
```

MVVM throughout. `SSHManager` is an `actor` so all connection state is thread-safe.
Downloads are driven by `AsyncThrowingStream` — SwiftUI observes `@Published` log and
status properties on each `DownloadJob`.

---

## Assumptions

- `somedl` is already installed on the Chromebook and on `$PATH` for the SSH user.
- `somedl_config.toml` is already configured (output folder, format, etc.).
- The iPhone and Chromebook are on the same LAN, or connected via a VPN (e.g.
  Tailscale) when on different networks.
- The SSH server on the Chromebook is running (`sudo systemctl start ssh`).
