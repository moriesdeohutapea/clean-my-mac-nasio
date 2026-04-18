# CleanMacNasio

CleanMacNasio is a macOS SwiftUI utility to scan common developer junk locations and clean selected items safely.

## Main Features

- One-click scan for common macOS developer junk paths.
- Per-step scan progress (multi-path visibility).
- Selective cleanup after scan (not auto-delete).
- Per-step delete progress.
- Stop scan while process is running.
- Excluded paths protection.

## Supported Clean Targets

- `~/Library/Caches`
- Android Studio caches (Google and JetBrains paths)
- Gradle caches and wrapper
- Flutter caches
- Homebrew caches
- `~/.Trash`
- Large files in Takeout paths

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

## Safety Notes

- The app does **not** clean automatically on launch.
- You must scan first, then choose what to clean.
- Excluded paths are preserved.
