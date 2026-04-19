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
- Xcode DerivedData (`~/Library/Developer/Xcode/DerivedData`)
- Xcode Archives (`~/Library/Developer/Xcode/Archives`) - requires confirmation before delete
- CocoaPods caches (`~/Library/Caches/CocoaPods`)
- SwiftPM caches (`~/Library/Caches/org.swift.swiftpm`)
- npm caches (`~/.npm`)
- Yarn caches (`~/Library/Caches/Yarn`, `~/.cache/yarn`)
- pnpm store (`~/Library/pnpm/store`, `~/.pnpm-store`)
- Maven caches (`~/.m2/repository`)
- Ivy caches (`~/.ivy2/cache`)
- pip caches (`~/.cache/pip`, `~/Library/Caches/pip`)
- Cargo caches (`~/.cargo/registry`, `~/.cargo/git`)
- Docker caches (`~/.docker/buildx`, `~/Library/Caches/com.docker.docker`, `~/Library/Containers/com.docker.docker/Data/log`)
- Poetry/Pipenv caches (`~/.cache/pypoetry`, `~/.local/share/virtualenvs`, `~/.cache/pipenv`)
- Go caches (`~/Library/Caches/go-build`, `~/go/pkg/mod`)
- Ruby/Bundler caches (`~/.bundle/cache`, `~/.gem`)
- Kubernetes/Helm caches (`~/.kube/cache`, `~/.cache/helm`)
- Android Studio caches (Google and JetBrains paths)
- Gradle caches and wrapper
- Flutter caches
- Homebrew caches
- Nix caches (`~/.cache/nix`, `~/.local/state/nix`, `~/Library/Caches/nix`)
- `~/.Trash`

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
