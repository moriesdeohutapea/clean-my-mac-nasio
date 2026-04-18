import XCTest
@testable import CleanMacNasio

final class CleanMacNasioTests: XCTestCase {
    func testFolderMetricsCountsNestedFilesAndSize() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let fileA = root.appendingPathComponent("a.txt")
        let nestedDir = root.appendingPathComponent("nested", isDirectory: true)
        let fileB = nestedDir.appendingPathComponent("b.txt")

        try fileManager.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: fileA)
        try Data(repeating: 1, count: 20).write(to: fileB)

        let metrics = FileUtils.folderMetrics(at: root)
        XCTAssertEqual(metrics.fileCount, 2)
        XCTAssertEqual(metrics.totalSize, 30)
    }

    func testFormatBytesReturnsReadableText() {
        let formatted = FileUtils.formatBytes(1_048_576)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testScanRespectsExcludedPathsAndGeneratesPreview() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        let includeFile = caches.appendingPathComponent("keep.bin")
        let excludedFolder = caches.appendingPathComponent("excluded-dir", isDirectory: true)
        let excludedFile = excludedFolder.appendingPathComponent("nested.bin")

        try fileManager.createDirectory(at: caches, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: excludedFolder, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 100).write(to: includeFile)
        try Data(repeating: 1, count: 200).write(to: excludedFile)

        let entries = JunkCleanerService.scan(
            locations: [.caches],
            homeDirectory: home,
            excludedPaths: Set([excludedFolder.path])
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalSize, 100)
        XCTAssertEqual(entries[0].fileCount, 1)
        XCTAssertEqual(entries[0].excludedItemsCount, 1)
        XCTAssertEqual(
            normalizedPath(entries[0].previewItems.first?.path),
            normalizedPath(includeFile.path)
        )
    }

    func testCleanSkipsExcludedItems() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        let deletable = caches.appendingPathComponent("delete-me.bin")
        let excluded = caches.appendingPathComponent("exclude-me.bin")

        try fileManager.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 40).write(to: deletable)
        try Data(repeating: 1, count: 50).write(to: excluded)

        let entries = JunkCleanerService.scan(
            locations: [.caches],
            homeDirectory: home,
            excludedPaths: Set([excluded.path])
        )

        let summary = JunkCleanerService.clean(entries: entries, excludedPaths: Set([excluded.path]))
        XCTAssertEqual(summary.totalFreedSize, 40)
        XCTAssertFalse(fileManager.fileExists(atPath: deletable.path))
        XCTAssertTrue(fileManager.fileExists(atPath: excluded.path))
    }

    func testScanPreviewReturnsTopFiveLargestItemsInOrder() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        try fileManager.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        for size in [10, 60, 20, 50, 30, 40] {
            let file = caches.appendingPathComponent("\(size).bin")
            try Data(repeating: 1, count: size).write(to: file)
        }

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.caches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.previewItems.map(\.size), [60, 50, 40, 30, 20])
    }

    func testExclusionStoreDeduplicatesAndSortsPaths() {
        let suiteName = "CleanMacNasioTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = ExclusionStore(userDefaults: defaults)
        store.save(["/z", "/a", "/z"])

        XCTAssertEqual(store.load(), ["/a", "/z"])
    }

    func testGradleScanSplitsVersionDirectories() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let gradleCaches = home.appendingPathComponent(".gradle/caches", isDirectory: true)
        let version87 = gradleCaches.appendingPathComponent("8.7", isDirectory: true)
        let version89 = gradleCaches.appendingPathComponent("8.9", isDirectory: true)
        let sharedModules = gradleCaches.appendingPathComponent("modules-2", isDirectory: true)
        let wrapper = home.appendingPathComponent(".gradle/wrapper", isDirectory: true)

        try fileManager.createDirectory(at: version87, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: version89, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sharedModules, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: wrapper, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 10).write(to: version87.appendingPathComponent("a.bin"))
        try Data(repeating: 1, count: 20).write(to: version89.appendingPathComponent("b.bin"))
        try Data(repeating: 1, count: 30).write(to: sharedModules.appendingPathComponent("c.bin"))
        try Data(repeating: 1, count: 40).write(to: wrapper.appendingPathComponent("d.bin"))

        let entries = JunkCleanerService.scan(
            locations: [.gradleCaches],
            homeDirectory: home,
            excludedPaths: []
        )

        XCTAssertTrue(entries.contains { $0.displayTitle == "Gradle Cache 8.7" && $0.totalSize == 10 })
        XCTAssertTrue(entries.contains { $0.displayTitle == "Gradle Cache 8.9" && $0.totalSize == 20 })
        XCTAssertTrue(entries.contains { $0.displayTitle == "Gradle Shared Caches" && $0.totalSize == 30 })
        XCTAssertTrue(entries.contains { $0.displayTitle == "Gradle Wrapper" && $0.totalSize == 40 })
    }

    func testHomebrewScanFindsUserHomebrewCaches() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libCacheHomebrew = home.appendingPathComponent("Library/Caches/Homebrew", isDirectory: true)
        let dotCacheHomebrew = home.appendingPathComponent(".cache/Homebrew", isDirectory: true)

        try fileManager.createDirectory(at: libCacheHomebrew, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dotCacheHomebrew, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 15).write(to: libCacheHomebrew.appendingPathComponent("a.tar.gz"))
        try Data(repeating: 1, count: 25).write(to: dotCacheHomebrew.appendingPathComponent("b.tar.gz"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.homebrewCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .homebrewCaches)
        XCTAssertEqual(entry.totalSize, 40)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testAndroidStudioScanFindsGoogleAndJetBrainsDirectories() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let googleCache = home.appendingPathComponent("Library/Caches/Google/AndroidStudio2024.1", isDirectory: true)
        let jetbrainsCache = home.appendingPathComponent("Library/Caches/JetBrains/AndroidStudio2025.1", isDirectory: true)
        let jetbrainsSupport = home.appendingPathComponent("Library/Application Support/JetBrains/AndroidStudio2025.1/caches", isDirectory: true)

        try fileManager.createDirectory(at: googleCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: jetbrainsCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: jetbrainsSupport, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 10).write(to: googleCache.appendingPathComponent("gc.bin"))
        try Data(repeating: 1, count: 20).write(to: jetbrainsCache.appendingPathComponent("jb.bin"))
        try Data(repeating: 1, count: 30).write(to: jetbrainsSupport.appendingPathComponent("support.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.androidStudioCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .androidStudioCaches)
        XCTAssertEqual(entry.totalSize, 60)
        XCTAssertEqual(entry.fileCount, 3)
    }

    func testTrashScanAndClean() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try fileManager.createDirectory(at: trash, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        let deletable = trash.appendingPathComponent("old.bin")
        try Data(repeating: 1, count: 33).write(to: deletable)

        let entries = JunkCleanerService.scan(
            locations: [.trash],
            homeDirectory: home,
            excludedPaths: []
        )
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.location, .trash)
        XCTAssertEqual(entry.totalSize, 33)
        XCTAssertEqual(entry.fileCount, 1)

        let summary = JunkCleanerService.clean(entries: entries, excludedPaths: [])
        XCTAssertEqual(summary.totalFreedSize, 33)
        XCTAssertFalse(fileManager.fileExists(atPath: deletable.path))
    }

    func testLargeFilesScanAndClean() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let takeout = home.appendingPathComponent("Downloads/Takeout", isDirectory: true)
        try fileManager.createDirectory(at: takeout, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        let largeFile = takeout.appendingPathComponent("large.bin")
        let smallFile = takeout.appendingPathComponent("small.bin")

        try Data().write(to: largeFile)
        let largeHandle = try FileHandle(forWritingTo: largeFile)
        try largeHandle.truncate(atOffset: 600 * 1024 * 1024)
        try largeHandle.close()

        try Data(repeating: 1, count: 1024).write(to: smallFile)

        let entries = JunkCleanerService.scan(
            locations: [.largeFiles],
            homeDirectory: home,
            excludedPaths: []
        )
        let entry = try XCTUnwrap(entries.first)

        XCTAssertEqual(entry.location, .largeFiles)
        XCTAssertEqual(entry.fileCount, 1)
        XCTAssertEqual(
            normalizedPath(entry.directoryURLs.first?.path),
            normalizedPath(largeFile.path)
        )
        XCTAssertFalse(entry.previewItems.isEmpty)

        let summary = JunkCleanerService.clean(entries: entries, excludedPaths: [])
        XCTAssertEqual(summary.results.first?.deletedItems, 1)
        XCTAssertFalse(fileManager.fileExists(atPath: largeFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: smallFile.path))
    }

    func testLargeFilesScanSkipsProtectedExtensions() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let takeout = home.appendingPathComponent("Downloads/Takeout", isDirectory: true)
        try fileManager.createDirectory(at: takeout, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        let protectedFile = takeout.appendingPathComponent("release.jks")
        let regularFile = takeout.appendingPathComponent("movie.iso")

        try Data().write(to: protectedFile)
        let protectedHandle = try FileHandle(forWritingTo: protectedFile)
        try protectedHandle.truncate(atOffset: 600 * 1024 * 1024)
        try protectedHandle.close()

        try Data().write(to: regularFile)
        let regularHandle = try FileHandle(forWritingTo: regularFile)
        try regularHandle.truncate(atOffset: 600 * 1024 * 1024)
        try regularHandle.close()

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.largeFiles],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.fileCount, 1)
        XCTAssertEqual(
            normalizedPath(entry.directoryURLs.first?.path),
            normalizedPath(regularFile.path)
        )
        XCTAssertFalse(entry.directoryURLs.contains(where: {
            normalizedPath($0.path) == normalizedPath(protectedFile.path)
        }))
    }

    func testCleanSkipsProtectedSensitiveFiles() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        let protectedFile = caches.appendingPathComponent("private.pem")

        try fileManager.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 256).write(to: protectedFile)

        let entry = JunkScanEntry(
            location: .largeFiles,
            directoryURLs: [protectedFile],
            totalSize: 256,
            fileCount: 1,
            errorMessage: nil,
            previewItems: [],
            excludedItemsCount: 0
        )

        let summary = JunkCleanerService.clean(entries: [entry], excludedPaths: [])

        XCTAssertEqual(summary.results.first?.deletedItems, 0)
        XCTAssertEqual(summary.results.first?.freedSize, 0)
        XCTAssertTrue(fileManager.fileExists(atPath: protectedFile.path))
    }

    @MainActor
    func testViewModelUsesInjectedServiceForScan() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let service = FakeJunkCleaningService(
            scanEntries: [
                JunkScanEntry(
                    location: .caches,
                    directoryURLs: [home.appendingPathComponent("Library/Caches")],
                    totalSize: 128,
                    fileCount: 2,
                    errorMessage: nil,
                    previewItems: [],
                    excludedItemsCount: 0
                )
            ]
        )
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: ["/tmp/home/keep"]),
            homeDirectoryURL: home,
            excludedPaths: ["/tmp/home/keep"]
        )

        viewModel.scanJunk()

        XCTAssertEqual(viewModel.scanEntries.count, 1)
        XCTAssertEqual(viewModel.totalScanSize, 128)
        XCTAssertEqual(viewModel.totalFileCount, 2)
        XCTAssertEqual(service.lastExcludedPaths, Set(["/tmp/home/keep"]))
    }

    @MainActor
    func testViewModelRestoreLoadsSavedHomeAndExclusionsWithoutAutoScan() {
        let expectedHome = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let service = FakeJunkCleaningService(scanEntries: [
            makeScanEntry(location: .logs, home: expectedHome, totalSize: 512, fileCount: 3)
        ])
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: URL(fileURLWithPath: "/tmp/ignored-home")),
            exclusionStore: FakeExclusionStore(paths: ["/tmp/restored-home/keep"])
        )

        viewModel.restoreSavedState()

        XCTAssertEqual(viewModel.homeDirectoryURL, expectedHome)
        XCTAssertEqual(viewModel.excludedPaths, ["/tmp/restored-home/keep"])
        XCTAssertTrue(viewModel.scanEntries.isEmpty)
        XCTAssertEqual(service.scanCallCount, 0)
        XCTAssertNil(service.lastHomeDirectoryURL)
        XCTAssertTrue(viewModel.logMessage.contains("Tekan Scan"))
    }

    @MainActor
    func testViewModelSetHomeDirectoryReportsSaveFailure() {
        let viewModel = ContentViewModel(
            cleanerService: FakeJunkCleaningService(scanEntries: []),
            bookmarkStore: FakeBookmarkStore(url: nil, saveError: TestError.expected),
            exclusionStore: FakeExclusionStore(paths: [])
        )

        viewModel.setHomeDirectory(URL(fileURLWithPath: "/tmp/home"))

        XCTAssertNil(viewModel.homeDirectoryURL)
        XCTAssertTrue(viewModel.logMessage.contains("Gagal menyimpan akses"))
    }

    @MainActor
    func testViewModelAddAndRemoveExcludedPathPersistsAndRescans() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let service = FakeJunkCleaningService(scanEntries: [])
        let exclusionStore = FakeExclusionStore(paths: [])
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: exclusionStore,
            homeDirectoryURL: home
        )

        viewModel.addExcludedPath("/tmp/home/keep")
        viewModel.addExcludedPath("/tmp/home/keep")
        viewModel.removeExcludedPath("/tmp/home/keep")

        XCTAssertEqual(viewModel.excludedPaths, [])
        XCTAssertEqual(exclusionStore.savedPathsHistory, [["/tmp/home/keep"], []])
        XCTAssertEqual(service.scanCallCount, 2)
    }

    @MainActor
    func testViewModelCanCleanFollowsDetectedTotalSize() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let entry = makeScanEntry(location: .caches, home: home, totalSize: 100, fileCount: 1)
        let viewModel = ContentViewModel(
            cleanerService: FakeJunkCleaningService(scanEntries: []),
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [entry]
        )

        XCTAssertFalse(viewModel.canClean)
        XCTAssertEqual(viewModel.selectedTotalSize, 0)
        XCTAssertEqual(viewModel.selectedCategoryCount, 0)

        viewModel.toggleSelection(for: entry.id)
        XCTAssertTrue(viewModel.canClean)
        XCTAssertEqual(viewModel.selectedTotalSize, 100)
        XCTAssertEqual(viewModel.selectedCategoryCount, 1)

        viewModel.scanEntries = [makeScanEntry(location: .caches, home: home, totalSize: 0, fileCount: 0)]
        viewModel.clearSelection()
        XCTAssertFalse(viewModel.canClean)
    }

    @MainActor
    func testViewModelCleanUsesAllDetectedEntriesAndRescans() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let selectedEntry = makeScanEntry(location: .caches, home: home, totalSize: 90, fileCount: 1)
        let service = FakeJunkCleaningService(
            scanEntries: [makeScanEntry(location: .caches, home: home, totalSize: 0, fileCount: 0)],
            cleanSummary: JunkCleanSummary(results: [
                JunkCleanEntryResult(location: .caches, deletedItems: 1, freedSize: 90, errors: ["one-error"])
            ])
        )
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [selectedEntry]
        )
        viewModel.toggleSelection(for: selectedEntry.id)

        viewModel.cleanSelected()

        XCTAssertEqual(service.cleanCallCount, 1)
        XCTAssertEqual(service.lastCleanEntries.map(\.location), [.caches])
        XCTAssertEqual(service.scanCallCount, 1)
        XCTAssertEqual(viewModel.scanEntries.first?.totalSize, 0)
        XCTAssertTrue(viewModel.logMessage.contains("Scan selesai"))
    }

    @MainActor
    func testViewModelSelectAllAndClearSelection() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let first = makeScanEntry(location: .caches, home: home, totalSize: 100, fileCount: 1)
        let second = makeScanEntry(location: .logs, home: home, totalSize: 200, fileCount: 2)
        let zero = makeScanEntry(location: .trash, home: home, totalSize: 0, fileCount: 0)
        let viewModel = ContentViewModel(
            cleanerService: FakeJunkCleaningService(scanEntries: []),
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [first, second, zero]
        )

        viewModel.selectAllDetected()
        XCTAssertTrue(viewModel.isSelected(first.id))
        XCTAssertTrue(viewModel.isSelected(second.id))
        XCTAssertFalse(viewModel.isSelected(zero.id))
        XCTAssertEqual(viewModel.selectedTotalSize, 300)
        XCTAssertEqual(viewModel.selectedCategoryCount, 2)

        viewModel.clearSelection()
        XCTAssertFalse(viewModel.hasSelection)
        XCTAssertEqual(viewModel.selectedTotalSize, 0)
    }
}

private final class FakeJunkCleaningService: @unchecked Sendable, JunkCleaningServicing {
    private let scanEntries: [JunkScanEntry]
    private let cleanSummary: JunkCleanSummary
    private(set) var lastExcludedPaths: Set<String> = []
    private(set) var lastHomeDirectoryURL: URL?
    private(set) var lastCleanEntries: [JunkScanEntry] = []
    private(set) var scanCallCount = 0
    private(set) var cleanCallCount = 0

    init(scanEntries: [JunkScanEntry], cleanSummary: JunkCleanSummary = JunkCleanSummary(results: [])) {
        self.scanEntries = scanEntries
        self.cleanSummary = cleanSummary
    }

    func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry] {
        scanCallCount += 1
        lastHomeDirectoryURL = homeDirectory
        lastExcludedPaths = excludedPaths
        return scanEntries
    }

    func clean(entries: [JunkScanEntry], excludedPaths: Set<String>) -> JunkCleanSummary {
        cleanCallCount += 1
        lastCleanEntries = entries
        lastExcludedPaths = excludedPaths
        return cleanSummary
    }
}

private struct FakeBookmarkStore: SecurityScopedBookmarkStoring {
    let url: URL?
    var saveError: Error?

    func save(url: URL) throws {
        if let saveError {
            throw saveError
        }
    }

    func loadURL() -> URL? {
        url
    }
}

private final class FakeExclusionStore: ExclusionStoring {
    let paths: [String]
    private(set) var savedPathsHistory: [[String]] = []

    init(paths: [String]) {
        self.paths = paths
    }

    func load() -> [String] {
        paths
    }

    func save(_ paths: [String]) {
        savedPathsHistory.append(paths)
    }
}

private enum TestError: Error {
    case expected
}

private func makeScanEntry(location: JunkLocation, home: URL, totalSize: UInt64, fileCount: Int) -> JunkScanEntry {
    JunkScanEntry(
        location: location,
        directoryURLs: [home.appendingPathComponent(location.title)],
        totalSize: totalSize,
        fileCount: fileCount,
        errorMessage: nil,
        previewItems: [],
        excludedItemsCount: 0
    )
}

private func normalizedPath(_ value: String?) -> String? {
    guard let value else { return nil }
    return URL(fileURLWithPath: value)
        .standardizedFileURL
        .resolvingSymlinksInPath()
        .path
}
