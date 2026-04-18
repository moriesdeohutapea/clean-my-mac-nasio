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
            previewScanProgressMessage: "Step 3/6: Gradle Caches",
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

#Preview("Layout Preview") {
    ContentView.previewContent
        .frame(width: 1200, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Empty State") {
    ContentView.previewEmptyState
        .frame(width: 1200, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Selected State") {
    ContentView.previewSelectionState
        .frame(width: 1200, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Scanning State") {
    ContentView.previewScanningState
        .frame(width: 1200, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Cleaning/Error State") {
    ContentView.previewCleaningState
        .frame(width: 1200, height: 760)
        .preferredColorScheme(.light)
}
