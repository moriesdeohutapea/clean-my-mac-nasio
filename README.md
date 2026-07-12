# CleanMacNasio

CleanMacNasio is a macOS SwiftUI utility to scan safe-to-clean logs and app caches, then clean selected items manually.

## Main Features

- One-click scan (and optional cancel) for selected safe paths.
- Multi-step scan/deletion progress for each target.
- Selective cleanup only after explicit selection (no auto-delete).
- Custom folder targets with manual selection and delete confirmation.
- Auto-detected cache recommendations for installed apps, addable as custom targets.
- Responsive UI for smaller windows.

## Supported Clean Targets

- `~/Library/Logs`
- Roblox caches and logs
- WhatsApp Desktop caches and logs
- Auto-recommended app cache folders when detected:
  - Discord, Figma, Notion, Telegram, Obsidian, Google Chrome,
    Microsoft Edge, Microsoft Teams, Spotify, Slack, Visual Studio Code
- Unity cache profile is available in code paths and can be added via Custom Cleanup Target.

## Tech Stack

- Swift
- SwiftUI
- MVVM
- XCTest (unit tests)

## Run Locally

1. Open `CleanMacNasio.xcodeproj` in Xcode.
2. Select scheme `CleanMacNasio`.
3. Run on `My Mac`.

## Run Unit Tests

```bash
xcodebuild -scheme CleanMacNasio -project CleanMacNasio.xcodeproj -destination 'platform=macOS' test -only-testing:CleanMacNasioTests
```

### Test Notes

```bash
xcodebuild build -project CleanMacNasio.xcodeproj -scheme CleanMacNasio -destination 'platform=macOS'
```

## Safety Notes

- The app does **not** clean automatically on launch.
- You must scan first, then choose what to clean.
- Excluded paths are preserved.
- Expensive-to-rebuild developer caches, application archives, package installations, and Nix state are not scanned by default.
- Custom targets must be subfolders of Home and are never included by Select All.
