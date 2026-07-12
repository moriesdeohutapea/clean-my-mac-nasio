//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import SwiftUI

extension ContentView {
    static var sampleHomeURL: URL {
        URL(fileURLWithPath: "/Users/yourname")
    }

    static var sampleEntries: [JunkScanEntry] {
        [
            JunkScanEntry(
                location: .caches,
                directoryURLs: [URL(fileURLWithPath: "/Users/yourname/Library/Caches")],
                totalSize: 3_456_789_012,
                fileCount: 1284,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/Xcode/DerivedData", size: 1_734_003_456),
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/Google/Chrome", size: 754_008_112)
                ],
                excludedItemsCount: 1
            ),
            JunkScanEntry(
                location: .androidStudioCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Caches/Google/AndroidStudio2025.1"),
                    URL(fileURLWithPath: "/Users/yourname/Library/Application Support/Google/AndroidStudio2025.1/caches")
                ],
                totalSize: 2_012_300_000,
                fileCount: 845,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/Google/AndroidStudio2025.1/index", size: 1_102_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .gradleCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/.gradle/caches"),
                    URL(fileURLWithPath: "/Users/yourname/.gradle/wrapper")
                ],
                totalSize: 945_230_000,
                fileCount: 390,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/.gradle/caches/modules-2", size: 690_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .xcodeDerivedData,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Developer/Xcode/DerivedData")
                ],
                totalSize: 1_430_120_000,
                fileCount: 210,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Developer/Xcode/DerivedData/App-abc123", size: 730_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .xcodeArchives,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Developer/Xcode/Archives")
                ],
                totalSize: 920_220_000,
                fileCount: 7,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Developer/Xcode/Archives/2026-04-10/App.xcarchive", size: 410_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .cocoaPodsCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Caches/CocoaPods")
                ],
                totalSize: 188_500_000,
                fileCount: 92,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/CocoaPods/Pods/Release.zip", size: 90_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .swiftPMCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Caches/org.swift.swiftpm")
                ],
                totalSize: 240_700_000,
                fileCount: 58,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/org.swift.swiftpm/repositories", size: 130_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .npmCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/.npm")
                ],
                totalSize: 180_400_000,
                fileCount: 120,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/.npm/_cacache/index-v5", size: 95_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .yarnCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Caches/Yarn"),
                    URL(fileURLWithPath: "/Users/yourname/.cache/yarn")
                ],
                totalSize: 152_250_000,
                fileCount: 88,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/Yarn/v6", size: 80_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .pnpmStore,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/pnpm/store"),
                    URL(fileURLWithPath: "/Users/yourname/.pnpm-store")
                ],
                totalSize: 201_500_000,
                fileCount: 96,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/pnpm/store/v3/files", size: 111_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .homebrewCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/Library/Caches/Homebrew"),
                    URL(fileURLWithPath: "/Users/yourname/.cache/Homebrew")
                ],
                totalSize: 430_120_000,
                fileCount: 52,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/Library/Caches/Homebrew/downloads/ruby-3.3.tar.gz", size: 220_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .nixCaches,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/.cache/nix"),
                    URL(fileURLWithPath: "/Users/yourname/.local/state/nix")
                ],
                totalSize: 210_600_000,
                fileCount: 37,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/.cache/nix/binary-cache-v6.sqlite", size: 120_000_000)
                ],
                excludedItemsCount: 0
            ),
            JunkScanEntry(
                location: .trash,
                directoryURLs: [
                    URL(fileURLWithPath: "/Users/yourname/.Trash")
                ],
                totalSize: 120_500_000,
                fileCount: 16,
                errorMessage: nil,
                previewItems: [
                    JunkPreviewItem(path: "/Users/yourname/.Trash/old-build.zip", size: 75_000_000)
                ],
                excludedItemsCount: 0
            )
        ]
    }

    static var sampleExcludedPaths: [String] {
        [
            "/Users/yourname/Library/Caches/Google/Chrome/Profile 1",
            "/Users/yourname/.gradle/caches/keep-this-folder"
        ]
    }

    static var previewContent: ContentView {
        ContentView(
            previewHomeDirectoryURL: sampleHomeURL,
            previewScanEntries: sampleEntries,
            previewExcludedPaths: sampleExcludedPaths,
            previewLogMessage: "Scan selesai. Total junk: 6.4 GB."
        )
    }

    static var previewEmptyState: ContentView {
        ContentView(
            previewHomeDirectoryURL: sampleHomeURL,
            previewScanEntries: [],
            previewExcludedPaths: [],
            previewLogMessage: "Tekan Scan untuk mulai pengecekan."
        )
    }

    static var previewSelectionState: ContentView {
        let entries = sampleEntries
        let selectedIDs = Set(entries.prefix(2).map(\.id))
        return ContentView(
            previewHomeDirectoryURL: sampleHomeURL,
            previewScanEntries: entries,
            previewExcludedPaths: sampleExcludedPaths,
            previewLogMessage: "2 kategori dipilih. Siap dibersihkan.",
            previewSelectedEntryIDs: selectedIDs
        )
    }

    static var previewScanningState: ContentView {
        ContentView(
            previewHomeDirectoryURL: sampleHomeURL,
            previewScanEntries: sampleEntries,
            previewExcludedPaths: sampleExcludedPaths,
            previewLogMessage: "Scanning lokasi junk...",
            previewIsScanning: true,
            previewScanProgressMessage: "Step 9/14: Android Studio Caches",
            previewScanProgressDetail: "~/.gradle/caches, ~/.gradle/wrapper",
            previewScanProgressFraction: 0.5
        )
    }

    static var previewCleaningState: ContentView {
        let entries = sampleEntries
        let selectedIDs = Set(entries.prefix(1).map(\.id))
        return ContentView(
            previewHomeDirectoryURL: sampleHomeURL,
            previewScanEntries: entries,
            previewExcludedPaths: sampleExcludedPaths,
            previewLogMessage: "Gagal hapus sebagian file: Operation not permitted.",
            previewSelectedEntryIDs: selectedIDs,
            previewIsCleaning: true,
            previewCleanProgressMessage: "Delete step 1/1: Caches",
            previewCleanProgressDetail: "~/Library/Caches",
            previewCleanProgressFraction: 0.8
        )
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView.previewContent
                .frame(width: 1200, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Layout Preview")

            ContentView.previewContent
                .frame(width: 480, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Compact Layout")

            ContentView.previewEmptyState
                .frame(width: 1200, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Empty State")

            ContentView.previewSelectionState
                .frame(width: 1200, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Selected State")

            ContentView.previewScanningState
                .frame(width: 1200, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Scanning State")

            ContentView.previewCleaningState
                .frame(width: 1200, height: 760)
                .preferredColorScheme(.light)
                .previewDisplayName("Cleaning/Error State")
        }
    }
}
#endif
