//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    nonisolated private static let activeScanLocations: [JunkLocation] = [
        .logs,
        .robloxCaches,
        .whatsAppCaches
    ]

    @Published var homeDirectoryURL: URL?
    @Published var scanEntries: [JunkScanEntry]
    @Published var selectedEntryIDs: Set<String>
    @Published var excludedPaths: [String]
    @Published var customTargetPaths: [String]
    @Published var logMessage: String
    @Published var scanProgressMessage: String
    @Published var scanProgressDetail: String
    @Published var scanProgressFraction: Double
    @Published var cleanProgressMessage: String
    @Published var cleanProgressDetail: String
    @Published var cleanProgressFraction: Double
    @Published var detectedAppCacheRecommendations: [JunkCleanerService.AppCacheRecommendation]
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var showArchiveCleanConfirmation = false
    @Published var showCustomTargetCleanConfirmation = false

    private let cleanerService: JunkCleaningServicing
    private let bookmarkStore: SecurityScopedBookmarkStoring
    private let exclusionStore: ExclusionStoring
    private let customTargetStore: CustomTargetStoring
    private let performAsyncScan: Bool
    private let performAsyncClean: Bool
    private let scanQueue = DispatchQueue(label: "CleanMacNasio.scan.queue", qos: .userInitiated)
    private let cleanQueue = DispatchQueue(label: "CleanMacNasio.clean.queue", qos: .userInitiated)
    private let scanControlQueue = DispatchQueue(label: "CleanMacNasio.scan.control.queue")
    nonisolated(unsafe) private var scanCancellationRequested = false

    init(
        cleanerService: JunkCleaningServicing = JunkCleanerService(),
        bookmarkStore: SecurityScopedBookmarkStoring = SecurityScopedBookmarkStore(),
        exclusionStore: ExclusionStoring = ExclusionStore(),
        customTargetStore: CustomTargetStoring = CustomTargetStore(),
        homeDirectoryURL: URL? = nil,
        scanEntries: [JunkScanEntry] = [],
        selectedEntryIDs: Set<String> = [],
        excludedPaths: [String] = [],
        customTargetPaths: [String] = [],
        logMessage: String = "",
        scanProgressMessage: String = "",
        scanProgressDetail: String = "",
        scanProgressFraction: Double = 0,
        cleanProgressMessage: String = "",
        cleanProgressDetail: String = "",
        cleanProgressFraction: Double = 0,
        performAsyncScan: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil,
        performAsyncClean: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil
    ) {
        self.cleanerService = cleanerService
        self.bookmarkStore = bookmarkStore
        self.exclusionStore = exclusionStore
        self.customTargetStore = customTargetStore
        self.homeDirectoryURL = homeDirectoryURL
        self.scanEntries = scanEntries
        self.selectedEntryIDs = selectedEntryIDs
        self.excludedPaths = excludedPaths
        self.detectedAppCacheRecommendations = []
        self.customTargetPaths = customTargetPaths
        self.logMessage = logMessage
        self.scanProgressMessage = scanProgressMessage
        self.scanProgressDetail = scanProgressDetail
        self.scanProgressFraction = scanProgressFraction
        self.cleanProgressMessage = cleanProgressMessage
        self.cleanProgressDetail = cleanProgressDetail
        self.cleanProgressFraction = cleanProgressFraction
        self.performAsyncScan = performAsyncScan
        self.performAsyncClean = performAsyncClean
    }

    var selectedEntries: [JunkScanEntry] {
        scanEntries.filter { selectedEntryIDs.contains($0.id) }
    }

    var selectedTotalSize: UInt64 {
        selectedEntries.reduce(0) { $0 + $1.totalSize }
    }

    var selectedCategoryCount: Int {
        selectedEntries.filter { $0.totalSize > 0 }.count
    }

    var totalScanSize: UInt64 {
        scanEntries.reduce(0) { $0 + $1.totalSize }
    }

    var totalFileCount: Int {
        scanEntries.reduce(0) { $0 + $1.fileCount }
    }

    var isBusy: Bool {
        isScanning || isCleaning
    }

    var statusText: String {
        if isScanning { return "Scanning" }
        if isCleaning { return "Cleaning" }
        return "Ready"
    }

    var workingText: String {
        isScanning ? "Scanning..." : "Cleaning..."
    }

    var canScan: Bool {
        !isBusy
    }

    var canClean: Bool {
        !selectedEntries.isEmpty && selectedTotalSize > 0 && !isBusy
    }

    var hasSelection: Bool {
        !selectedEntries.isEmpty
    }

    func restoreSavedState() {
        excludedPaths = exclusionStore.load()
        customTargetPaths = customTargetStore.load()
        if homeDirectoryURL == nil {
            homeDirectoryURL = Self.defaultHomeDirectoryURL()
        }
        if scanEntries.isEmpty && logMessage.isEmpty {
            logMessage = "Tekan Scan untuk mulai pengecekan."
        }
    }

    func setHomeDirectory(_ url: URL) {
        do {
            try bookmarkStore.save(url: url)
            homeDirectoryURL = url
            logMessage = "Akses folder disimpan."
            scanJunk()
        } catch {
            logMessage = "Gagal menyimpan akses: \(error.localizedDescription)"
        }
    }

    func addExcludedPath(_ path: String) {
        guard !excludedPaths.contains(path) else { return }
        excludedPaths.append(path)
        exclusionStore.save(excludedPaths)
        logMessage = "Exclude path ditambahkan."
        scanJunk()
    }

    func removeExcludedPath(_ path: String) {
        excludedPaths.removeAll { $0 == path }
        exclusionStore.save(excludedPaths)
        logMessage = "Exclude path dihapus."
        scanJunk()
    }

    func addCustomTarget(_ url: URL) {
        let targetHomeDirectory = homeDirectoryURL ?? Self.defaultHomeDirectoryURL()
        let normalizedHomePath = JunkCleanerService.normalizePath(targetHomeDirectory.path)
        let normalizedTargetPath = JunkCleanerService.normalizePath(url.path)

        guard normalizedTargetPath != normalizedHomePath,
              normalizedTargetPath.hasPrefix(normalizedHomePath + "/") else {
            logMessage = "Custom target harus berupa subfolder di Home directory."
            return
        }

        guard !customTargetPaths.contains(normalizedTargetPath) else { return }

        customTargetPaths.append(normalizedTargetPath)
        customTargetStore.save(customTargetPaths)
        logMessage = "Custom target ditambahkan. Target ini tidak dipilih otomatis."
        scanJunk()
    }

    func addRecommendedCacheDirectories(_ directories: [URL]) {
        guard !directories.isEmpty else { return }

        let targetHomeDirectory = homeDirectoryURL ?? Self.defaultHomeDirectoryURL()
        let normalizedHomePath = JunkCleanerService.normalizePath(targetHomeDirectory.path)
        var updatedPaths = customTargetPaths
        var addedPathsCount = 0

        for directory in directories {
            let normalizedTargetPath = JunkCleanerService.normalizePath(directory.path)

            guard normalizedTargetPath != normalizedHomePath,
                  normalizedTargetPath.hasPrefix(normalizedHomePath + "/") else {
                continue
            }
            guard !updatedPaths.contains(normalizedTargetPath) else { continue }

            updatedPaths.append(normalizedTargetPath)
            addedPathsCount += 1
        }

        guard addedPathsCount > 0 else {
            logMessage = "Semua path rekomendasi sudah ada di Custom Target."
            return
        }

        updatedPaths.sort()
        customTargetPaths = updatedPaths
        customTargetStore.save(updatedPaths)
        logMessage = "\(addedPathsCount) path rekomendasi ditambahkan. Target ini tidak dipilih otomatis."
        scanJunk()
    }

    func removeCustomTarget(_ path: String) {
        customTargetPaths.removeAll { $0 == path }
        customTargetStore.save(customTargetPaths)
        logMessage = "Custom target dihapus."
        scanJunk()
    }

    func requestStopScan() {
        guard isScanning else { return }
        setScanCancellationRequested(true)
        scanProgressMessage = "Stopping scan..."
    }

    func scanJunk() {
        guard !isScanning else { return }

        let targetHomeDirectory = homeDirectoryURL ?? Self.defaultHomeDirectoryURL()
        homeDirectoryURL = targetHomeDirectory
        let currentExcludedPaths = Set(excludedPaths)
        let currentCustomTargetDirectories = Self.customTargetDirectories(paths: customTargetPaths)
        let recommendationEntries = JunkCleanerService.detectInstalledAppCacheRecommendations(homeDirectory: targetHomeDirectory)
        setScanCancellationRequested(false)

        isScanning = true
        scanProgressMessage = "Preparing scan..."
        scanProgressDetail = ""
        scanProgressFraction = 0
        detectedAppCacheRecommendations = []

        if performAsyncScan {
            let service = cleanerService
            scanQueue.async { [weak self] in
                let didStart = targetHomeDirectory.startAccessingSecurityScopedResource()
                let locations = Self.activeScanLocations
                let totalSteps = locations.count + currentCustomTargetDirectories.count
                var scannedEntries: [JunkScanEntry] = []
                var cancelled = false

                for (index, location) in locations.enumerated() {
                    if self?.shouldCancelScan() == true {
                        cancelled = true
                        break
                    }

                    let stepNumber = index + 1
                    let locationDirectories = location.resolveDirectories(homeDirectory: targetHomeDirectory)
                    let pathSummary = Self.pathSummary(
                        directories: locationDirectories,
                        homeDirectory: targetHomeDirectory
                    )
                    Task { @MainActor [weak self] in
                        self?.scanProgressMessage = "Step \(stepNumber)/\(totalSteps): \(location.title)"
                        self?.scanProgressDetail = pathSummary
                        self?.scanProgressFraction = Double(index) / Double(totalSteps)
                    }

                    let stepEntries = service.scan(
                        locations: [location],
                        homeDirectory: targetHomeDirectory,
                        excludedPaths: currentExcludedPaths,
                        shouldCancel: { [weak self] in
                            self?.shouldCancelScan() ?? false
                        }
                    )
                    scannedEntries.append(contentsOf: stepEntries)

                    Task { @MainActor [weak self] in
                        self?.scanProgressFraction = Double(stepNumber) / Double(totalSteps)
                    }
                }

                if !cancelled {
                    for (index, directory) in currentCustomTargetDirectories.enumerated() {
                        if self?.shouldCancelScan() == true {
                            cancelled = true
                            break
                        }

                        let stepNumber = locations.count + index + 1
                        let pathSummary = Self.pathSummary(
                            directories: [directory],
                            homeDirectory: targetHomeDirectory
                        )
                        Task { @MainActor [weak self] in
                            self?.scanProgressMessage = "Step \(stepNumber)/\(totalSteps): Custom Target"
                            self?.scanProgressDetail = pathSummary
                            self?.scanProgressFraction = Double(stepNumber - 1) / Double(totalSteps)
                        }

                        let stepEntries = service.scanCustomTargets(
                            directories: [directory],
                            homeDirectory: targetHomeDirectory,
                            excludedPaths: currentExcludedPaths,
                            shouldCancel: { [weak self] in
                                self?.shouldCancelScan() ?? false
                            }
                        )
                        scannedEntries.append(contentsOf: stepEntries)

                        Task { @MainActor [weak self] in
                            self?.scanProgressFraction = Double(stepNumber) / Double(totalSteps)
                        }
                    }
                }
                if didStart {
                    targetHomeDirectory.stopAccessingSecurityScopedResource()
                }

                Task { @MainActor [weak self] in
                    self?.completeScan(
                        scannedEntries,
                        recommendations: recommendationEntries,
                        cancelled: cancelled || self?.shouldCancelScan() == true
                    )
                }
            }
        } else {
            let scannedEntries = withSecurityScopedAccess(targetHomeDirectory) {
                let standardEntries = cleanerService.scan(
                    locations: Self.activeScanLocations,
                    homeDirectory: targetHomeDirectory,
                    excludedPaths: currentExcludedPaths
                )
                let customEntries = cleanerService.scanCustomTargets(
                    directories: currentCustomTargetDirectories,
                    homeDirectory: targetHomeDirectory,
                    excludedPaths: currentExcludedPaths,
                    shouldCancel: { false }
                )
                return standardEntries + customEntries
            }
            completeScan(
                scannedEntries,
                recommendations: recommendationEntries,
                cancelled: false
            )
        }
    }

    func cleanSelected() {
        guard !selectedEntries.isEmpty, let homeDirectoryURL else { return }

        let entriesToClean = selectedEntries
        if entriesToClean.contains(where: { $0.location == .customCleanupTarget }) {
            showCustomTargetCleanConfirmation = true
            return
        }

        if entriesToClean.contains(where: { $0.location == .xcodeArchives }) {
            showArchiveCleanConfirmation = true
            return
        }

        runClean(entriesToClean: entriesToClean, homeDirectoryURL: homeDirectoryURL)
    }

    func confirmCleanSelectedIncludingArchives() {
        guard !selectedEntries.isEmpty, let homeDirectoryURL else {
            showArchiveCleanConfirmation = false
            return
        }

        showArchiveCleanConfirmation = false
        runClean(entriesToClean: selectedEntries, homeDirectoryURL: homeDirectoryURL)
    }

    func cancelCleanSelectedIncludingArchives() {
        showArchiveCleanConfirmation = false
    }

    func confirmCleanSelectedIncludingCustomTargets() {
        guard !selectedEntries.isEmpty, let homeDirectoryURL else {
            showCustomTargetCleanConfirmation = false
            return
        }

        showCustomTargetCleanConfirmation = false
        runClean(entriesToClean: selectedEntries, homeDirectoryURL: homeDirectoryURL)
    }

    func cancelCleanSelectedIncludingCustomTargets() {
        showCustomTargetCleanConfirmation = false
    }

    private func runClean(entriesToClean: [JunkScanEntry], homeDirectoryURL: URL) {
        let currentExcludedPaths = Set(excludedPaths)

        isCleaning = true
        cleanProgressMessage = "Preparing delete..."
        cleanProgressDetail = ""
        cleanProgressFraction = 0

        if performAsyncClean {
            let service = cleanerService
            cleanQueue.async { [weak self] in
                let didStart = homeDirectoryURL.startAccessingSecurityScopedResource()
                let totalSteps = entriesToClean.count
                var results: [JunkCleanEntryResult] = []

                for (index, entry) in entriesToClean.enumerated() {
                    let stepNumber = index + 1
                    let progressDetail = Self.pathSummary(
                        directories: entry.directoryURLs,
                        homeDirectory: homeDirectoryURL
                    )
                    Task { @MainActor [weak self] in
                        self?.cleanProgressMessage = "Delete step \(stepNumber)/\(totalSteps): \(entry.displayTitle)"
                        self?.cleanProgressDetail = progressDetail
                        self?.cleanProgressFraction = Double(index) / Double(totalSteps)
                    }

                    let partial = service.clean(entries: [entry], excludedPaths: currentExcludedPaths)
                    results.append(contentsOf: partial.results)

                    Task { @MainActor [weak self] in
                        self?.cleanProgressFraction = Double(stepNumber) / Double(totalSteps)
                    }
                }

                if didStart {
                    homeDirectoryURL.stopAccessingSecurityScopedResource()
                }

                let summary = JunkCleanSummary(results: results)
                Task { @MainActor [weak self] in
                    self?.completeClean(summary)
                }
            }
        } else {
            let totalSteps = entriesToClean.count
            var results: [JunkCleanEntryResult] = []
            let summary = withSecurityScopedAccess(homeDirectoryURL) {
                for (index, entry) in entriesToClean.enumerated() {
                    let stepNumber = index + 1
                    cleanProgressMessage = "Delete step \(stepNumber)/\(totalSteps): \(entry.displayTitle)"
                    cleanProgressDetail = Self.pathSummary(
                        directories: entry.directoryURLs,
                        homeDirectory: homeDirectoryURL
                    )
                    cleanProgressFraction = Double(index) / Double(totalSteps)

                    let partial = cleanerService.clean(entries: [entry], excludedPaths: currentExcludedPaths)
                    results.append(contentsOf: partial.results)
                    cleanProgressFraction = Double(stepNumber) / Double(totalSteps)
                }
                return JunkCleanSummary(results: results)
            }
            completeClean(summary)
        }
    }

    func toggleSelection(for entryID: String) {
        if selectedEntryIDs.contains(entryID) {
            selectedEntryIDs.remove(entryID)
        } else {
            selectedEntryIDs.insert(entryID)
        }
    }

    func selectAllDetected() {
        selectedEntryIDs = Set(
            scanEntries
                .filter { $0.totalSize > 0 && $0.location != .customCleanupTarget }
                .map(\.id)
        )
    }

    func clearSelection() {
        selectedEntryIDs.removeAll()
    }

    func isSelected(_ entryID: String) -> Bool {
        selectedEntryIDs.contains(entryID)
    }

    private func withSecurityScopedAccess<T>(_ url: URL, operation: () -> T) -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return operation()
    }

    private func completeScan(
        _ scannedEntries: [JunkScanEntry],
        recommendations: [JunkCleanerService.AppCacheRecommendation],
        cancelled: Bool
    ) {
        scanEntries = scannedEntries
        detectedAppCacheRecommendations = recommendations
        selectedEntryIDs.removeAll()
        let total = scanEntries.reduce(0) { $0 + $1.totalSize }
        if cancelled {
            logMessage = "Scan dihentikan. Total sementara: \(FileUtils.formatBytes(total))."
        } else {
            logMessage = "Scan selesai. Total junk: \(FileUtils.formatBytes(total))."
        }
        scanProgressMessage = ""
        scanProgressDetail = ""
        scanProgressFraction = 0
        isScanning = false
        setScanCancellationRequested(false)
    }

    private func completeClean(_ summary: JunkCleanSummary) {
        let errorCount = summary.results.reduce(0) { $0 + $1.errors.count }
        logMessage = "Clean selesai. Freed \(FileUtils.formatBytes(summary.totalFreedSize)). Error: \(errorCount)."
        cleanProgressMessage = ""
        cleanProgressDetail = ""
        cleanProgressFraction = 0
        isCleaning = false
        scanJunk()
    }

    nonisolated private static func pathSummary(directories: [URL], homeDirectory: URL) -> String {
        guard !directories.isEmpty else {
            return "No specific path found, using default resolver."
        }

        let relativePaths = directories.map { directory in
            let standardized = directory.standardizedFileURL.path
            let homePath = homeDirectory.standardizedFileURL.path
            if standardized == homePath {
                return "~"
            }
            if standardized.hasPrefix(homePath + "/") {
                return "~/" + standardized.dropFirst(homePath.count + 1)
            }
            return standardized
        }

        return "Paths: " + relativePaths.joined(separator: " | ")
    }

    nonisolated private static func customTargetDirectories(paths: [String]) -> [URL] {
        paths.map { path in
            URL(fileURLWithPath: path, isDirectory: true)
                .standardizedFileURL
                .resolvingSymlinksInPath()
        }
    }

    nonisolated private static func defaultHomeDirectoryURL() -> URL {
        let candidate = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        if candidate.path != "/" {
            return candidate
        }

        if let resolved = NSHomeDirectoryForUser(NSUserName()) {
            return URL(fileURLWithPath: resolved, isDirectory: true).standardizedFileURL
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    }

    private func setScanCancellationRequested(_ value: Bool) {
        scanControlQueue.sync {
            scanCancellationRequested = value
        }
    }

    nonisolated private func shouldCancelScan() -> Bool {
        scanControlQueue.sync { scanCancellationRequested }
    }
}
