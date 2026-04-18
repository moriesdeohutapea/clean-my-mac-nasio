//
//  JunkCleanerService.swift
//  CleanMacNasio
//
//  Created by Mories Hutapea on 19/07/25.
//

import Foundation

enum JunkLocation: String, CaseIterable, Identifiable {
    case caches
    case logs
    case temporaryDirectory
    case androidStudioCaches
    case gradleCaches
    case flutterCaches
    case homebrewCaches
    case trash
    case largeFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches:
            return "Caches"
        case .logs:
            return "Logs"
        case .temporaryDirectory:
            return "Temporary Directory"
        case .androidStudioCaches:
            return "Android Studio Caches"
        case .gradleCaches:
            return "Gradle Caches"
        case .flutterCaches:
            return "Flutter Caches"
        case .homebrewCaches:
            return "Homebrew Caches"
        case .trash:
            return "Trash"
        case .largeFiles:
            return "Large Files (>500 MB)"
        }
    }

    private var relativePath: String? {
        switch self {
        case .caches:
            return "Library/Caches"
        case .logs:
            return "Library/Logs"
        case .temporaryDirectory:
            return nil
        case .androidStudioCaches, .gradleCaches, .flutterCaches, .homebrewCaches, .trash, .largeFiles:
            return nil
        }
    }

    private func resolveURL(homeDirectory: URL) -> URL {
        if let relativePath {
            return homeDirectory.appendingPathComponent(relativePath)
        }
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }

    func resolveDirectories(homeDirectory: URL) -> [URL] {
        switch self {
        case .caches, .logs, .temporaryDirectory:
            return compactUniqueDirectories([resolveURL(homeDirectory: homeDirectory)])
        case .androidStudioCaches:
            return resolveAndroidStudioDirectories(homeDirectory: homeDirectory)
        case .gradleCaches:
            return compactUniqueDirectories([
                homeDirectory.appendingPathComponent(".gradle/caches"),
                homeDirectory.appendingPathComponent(".gradle/wrapper")
            ])
        case .flutterCaches:
            return compactUniqueDirectories([
                homeDirectory.appendingPathComponent(".pub-cache"),
                homeDirectory.appendingPathComponent(".dartServer"),
                homeDirectory.appendingPathComponent("Library/Caches/flutter"),
                homeDirectory.appendingPathComponent("Library/Caches/dart"),
                homeDirectory.appendingPathComponent("Library/Caches/pub")
            ])
        case .homebrewCaches:
            return compactUniqueDirectories([
                homeDirectory.appendingPathComponent("Library/Caches/Homebrew"),
                homeDirectory.appendingPathComponent(".cache/Homebrew"),
                URL(fileURLWithPath: "/Library/Caches/Homebrew", isDirectory: true)
            ])
        case .trash:
            return compactUniqueDirectories([
                homeDirectory.appendingPathComponent(".Trash")
            ])
        case .largeFiles:
            return compactUniqueDirectories([
                homeDirectory.appendingPathComponent("Downloads/Takeout"),
                homeDirectory.appendingPathComponent("Takeout")
            ])
        }
    }

    private func resolveAndroidStudioDirectories(homeDirectory: URL) -> [URL] {
        let fileManager = FileManager.default
        let cachesGoogle = homeDirectory.appendingPathComponent("Library/Caches/Google", isDirectory: true)
        let logsGoogle = homeDirectory.appendingPathComponent("Library/Logs/Google", isDirectory: true)
        let appSupportGoogle = homeDirectory.appendingPathComponent("Library/Application Support/Google", isDirectory: true)
        let cachesJetBrains = homeDirectory.appendingPathComponent("Library/Caches/JetBrains", isDirectory: true)
        let logsJetBrains = homeDirectory.appendingPathComponent("Library/Logs/JetBrains", isDirectory: true)
        let appSupportJetBrains = homeDirectory.appendingPathComponent("Library/Application Support/JetBrains", isDirectory: true)

        var directories: [URL] = []

        directories += findAndroidStudioVersionedDirectories(in: cachesGoogle, fileManager: fileManager)
        directories += findAndroidStudioVersionedDirectories(in: logsGoogle, fileManager: fileManager)
        directories += findAndroidStudioVersionedDirectories(in: cachesJetBrains, fileManager: fileManager)
        directories += findAndroidStudioVersionedDirectories(in: logsJetBrains, fileManager: fileManager)

        let appSupportDirs = findAndroidStudioVersionedDirectories(in: appSupportGoogle, fileManager: fileManager)
        let appSupportJetBrainsDirs = findAndroidStudioVersionedDirectories(in: appSupportJetBrains, fileManager: fileManager)
        directories += appSupportDirs.map { $0.appendingPathComponent("caches") }
        directories += appSupportDirs.map { $0.appendingPathComponent("plugins") }
        directories += appSupportJetBrainsDirs.map { $0.appendingPathComponent("caches") }
        directories += appSupportJetBrainsDirs.map { $0.appendingPathComponent("plugins") }

        return compactUniqueDirectories(directories)
    }

    private func findAndroidStudioVersionedDirectories(in parent: URL, fileManager: FileManager) -> [URL] {
        guard fileManager.fileExists(atPath: parent.path) else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.filter { child in
            guard let isDirectory = try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else {
                return false
            }
            return isDirectory == true && child.lastPathComponent.hasPrefix("AndroidStudio")
        }
    }

    private func compactUniqueDirectories(_ directories: [URL]) -> [URL] {
        var seen: Set<String> = []
        return directories.compactMap { directory in
            let path = directory.standardizedFileURL.path
            guard !seen.contains(path) else { return nil }
            seen.insert(path)
            return directory
        }
    }
}

struct JunkPreviewItem: Identifiable {
    let path: String
    let size: UInt64

    var id: String { path }
}

struct JunkScanEntry: Identifiable {
    let location: JunkLocation
    let directoryURLs: [URL]
    let totalSize: UInt64
    let fileCount: Int
    let errorMessage: String?
    let previewItems: [JunkPreviewItem]
    let excludedItemsCount: Int

    var id: String {
        if location == .largeFiles {
            return location.id
        }
        let directoryKey = directoryURLs.map(\.path).joined(separator: "|")
        return "\(location.id)|\(directoryKey)"
    }

    var displayTitle: String {
        guard location == .gradleCaches else {
            return location.title
        }
        guard directoryURLs.count == 1, let directory = directoryURLs.first else {
            return location.title
        }

        let path = directory.path
        if path.hasSuffix("/.gradle/wrapper") || path.contains("/.gradle/wrapper/") {
            return "Gradle Wrapper"
        }

        let name = directory.lastPathComponent
        if Self.looksLikeGradleVersion(name) {
            return "Gradle Cache \(name)"
        }
        return "Gradle Shared Caches"
    }

    var directoryPathText: String {
        if directoryURLs.isEmpty {
            return "No matching directory found"
        }
        return directoryURLs.map(\.path).joined(separator: "\n")
    }

    private static func looksLikeGradleVersion(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+(\.[0-9A-Za-z-]+)+$"#, options: .regularExpression) != nil
    }
}

struct JunkCleanEntryResult: Identifiable {
    let location: JunkLocation
    let deletedItems: Int
    let freedSize: UInt64
    let errors: [String]

    var id: String { location.id }
}

struct JunkCleanSummary {
    let results: [JunkCleanEntryResult]

    var totalFreedSize: UInt64 {
        results.reduce(0) { $0 + $1.freedSize }
    }
}

protocol JunkCleaningServicing: Sendable {
    func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry]
    func clean(entries: [JunkScanEntry], excludedPaths: Set<String>) -> JunkCleanSummary
}

struct JunkCleanerService {
    private static let fileManager = FileManager.default
    private static let largeFileThresholdBytes: UInt64 = 500 * 1024 * 1024
    private static let protectedFileExtensions: Set<String> = [
        "jks", "keystore",
        "p12", "cer", "pem", "key", "mobileprovision",
        "db", "sqlite", "sqlite3"
    ]

    static func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry] {
        let protectedRoots = protectedRootPaths(homeDirectory: homeDirectory)
        return locations.flatMap { location in
            switch location {
            case .gradleCaches:
                return buildGradleScanEntries(
                    homeDirectory: homeDirectory,
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRoots
                )
            case .largeFiles:
                return [
                    buildLargeFilesEntry(
                        directories: location.resolveDirectories(homeDirectory: homeDirectory),
                        excludedPaths: excludedPaths,
                        protectedRootPaths: protectedRoots
                    )
                ]
            default:
                let directories = location.resolveDirectories(homeDirectory: homeDirectory)
                return [
                    buildScanEntry(
                        location: location,
                        directories: directories,
                        excludedPaths: excludedPaths,
                        protectedRootPaths: protectedRoots
                    )
                ]
            }
        }
    }

    static func clean(entries: [JunkScanEntry], excludedPaths: Set<String>) -> JunkCleanSummary {
        let protectedRoots = protectedRootPaths(homeDirectory: currentUserHomeDirectory())
        let results = entries.map { entry in
            let deletionResult = entry.directoryURLs.reduce((deletedItems: 0, freedSize: UInt64(0), errors: [String]())) { partial, targetURL in
                let result = deleteTarget(
                    at: targetURL,
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRoots
                )
                return (
                    deletedItems: partial.deletedItems + result.deletedItems,
                    freedSize: partial.freedSize + result.freedSize,
                    errors: partial.errors + result.errors
                )
            }

            return JunkCleanEntryResult(
                location: entry.location,
                deletedItems: deletionResult.deletedItems,
                freedSize: deletionResult.freedSize,
                errors: deletionResult.errors
            )
        }
        return JunkCleanSummary(results: results)
    }

    private static func buildScanEntry(
        location: JunkLocation,
        directories: [URL],
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> JunkScanEntry {
        var totalSize: UInt64 = 0
        var totalFiles = 0
        var excludedItemsCount = 0
        var itemRows: [(url: URL, metrics: FileUtils.ItemMetrics)] = []
        var errors: [String] = []

        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            do {
                let children = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )

                for child in children {
                    if shouldSkip(child, excludedPaths: excludedPaths, protectedRootPaths: protectedRootPaths) {
                        excludedItemsCount += 1
                        continue
                    }
                    let metrics = FileUtils.itemMetrics(at: child)
                    totalSize += metrics.totalSize
                    totalFiles += metrics.fileCount
                    itemRows.append((url: child, metrics: metrics))
                }
            } catch {
                errors.append("\(directory.path): \(error.localizedDescription)")
            }
        }

        let preview = itemRows
            .sorted { $0.metrics.totalSize > $1.metrics.totalSize }
            .prefix(5)
            .map { row in
                JunkPreviewItem(path: row.url.path, size: row.metrics.totalSize)
            }

        return JunkScanEntry(
            location: location,
            directoryURLs: directories,
            totalSize: totalSize,
            fileCount: totalFiles,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n"),
            previewItems: Array(preview),
            excludedItemsCount: excludedItemsCount
        )
    }

    private static func buildGradleScanEntries(
        homeDirectory: URL,
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> [JunkScanEntry] {
        let cacheRoot = homeDirectory.appendingPathComponent(".gradle/caches")
        let wrapperRoot = homeDirectory.appendingPathComponent(".gradle/wrapper")

        var entries: [JunkScanEntry] = []

        let versionDirectories = gradleVersionDirectories(in: cacheRoot).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        for versionDirectory in versionDirectories {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [versionDirectory],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths
                )
            )
        }

        let sharedDirectories = gradleSharedDirectories(in: cacheRoot, excluding: Set(versionDirectories.map(\.path)))
        if !sharedDirectories.isEmpty {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: sharedDirectories,
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths
                )
            )
        }

        if fileManager.fileExists(atPath: wrapperRoot.path) {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [wrapperRoot],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths
                )
            )
        }

        if entries.isEmpty {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [cacheRoot, wrapperRoot],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths
                )
            )
        }

        return entries
    }

    private static func buildLargeFilesEntry(
        directories: [URL],
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> JunkScanEntry {
        let existingDirectories = directories.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingDirectories.isEmpty else {
            return JunkScanEntry(
                location: .largeFiles,
                directoryURLs: [],
                totalSize: 0,
                fileCount: 0,
                errorMessage: nil,
                previewItems: [],
                excludedItemsCount: 0
            )
        }

        var matchedFiles: [(url: URL, size: UInt64)] = []
        var totalSize: UInt64 = 0
        var excludedItemsCount = 0
        var errors: [String] = []

        for directory in existingDirectories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                errors.append("Failed to enumerate \(directory.path).")
                continue
            }

            for case let itemURL as URL in enumerator {
                if shouldSkip(itemURL, excludedPaths: excludedPaths, protectedRootPaths: protectedRootPaths) {
                    excludedItemsCount += 1
                    continue
                }

                guard let values = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true else {
                    continue
                }

                let fileSize = UInt64(values.fileSize ?? 0)
                if fileSize >= largeFileThresholdBytes {
                    matchedFiles.append((url: itemURL, size: fileSize))
                    totalSize += fileSize
                }
            }
        }

        let previewItems = matchedFiles
            .sorted { $0.size > $1.size }
            .prefix(5)
            .map { row in
                JunkPreviewItem(path: row.url.path, size: row.size)
            }

        return JunkScanEntry(
            location: .largeFiles,
            directoryURLs: matchedFiles.map(\.url),
            totalSize: totalSize,
            fileCount: matchedFiles.count,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n"),
            previewItems: Array(previewItems),
            excludedItemsCount: excludedItemsCount
        )
    }

    private static func gradleVersionDirectories(in cacheRoot: URL) -> [URL] {
        childDirectories(in: cacheRoot).filter { looksLikeGradleVersion($0.lastPathComponent) }
    }

    private static func gradleSharedDirectories(in cacheRoot: URL, excluding excludedPaths: Set<String>) -> [URL] {
        childDirectories(in: cacheRoot).filter { !excludedPaths.contains($0.path) }
    }

    private static func childDirectories(in parent: URL) -> [URL] {
        guard fileManager.fileExists(atPath: parent.path) else { return [] }
        guard let children = try? fileManager.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children.filter { child in
            guard let isDirectory = try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else {
                return false
            }
            return isDirectory == true
        }
    }

    private static func looksLikeGradleVersion(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+(\.[0-9A-Za-z-]+)+$"#, options: .regularExpression) != nil
    }

    private static func deleteContents(
        of directory: URL,
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> (deletedItems: Int, freedSize: UInt64, errors: [String]) {
        guard fileManager.fileExists(atPath: directory.path) else {
            return (0, 0, [])
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            var deletedItems = 0
            var freedSize: UInt64 = 0
            var errors: [String] = []

            for item in contents {
                if shouldSkip(item, excludedPaths: excludedPaths, protectedRootPaths: protectedRootPaths) {
                    continue
                }

                let itemSize = FileUtils.itemSize(at: item)
                do {
                    try fileManager.removeItem(at: item)
                    deletedItems += 1
                    freedSize += itemSize
                } catch {
                    errors.append("\(item.lastPathComponent): \(error.localizedDescription)")
                }
            }

            return (deletedItems, freedSize, errors)
        } catch {
            return (0, 0, [error.localizedDescription])
        }
    }

    private static func deleteTarget(
        at url: URL,
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> (deletedItems: Int, freedSize: UInt64, errors: [String]) {
        guard fileManager.fileExists(atPath: url.path) else {
            return (0, 0, [])
        }

        if shouldSkip(url, excludedPaths: excludedPaths, protectedRootPaths: protectedRootPaths) {
            return (0, 0, [])
        }

        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            return (0, 0, ["\(url.lastPathComponent): Failed to read item attributes"])
        }

        if values.isDirectory == true {
            return deleteContents(
                of: url,
                excludedPaths: excludedPaths,
                protectedRootPaths: protectedRootPaths
            )
        }

        let itemSize = FileUtils.itemSize(at: url)
        do {
            try fileManager.removeItem(at: url)
            return (1, itemSize, [])
        } catch {
            return (0, 0, ["\(url.lastPathComponent): \(error.localizedDescription)"])
        }
    }

    private static func isExcluded(_ itemURL: URL, excludedPaths: Set<String>) -> Bool {
        let normalizedItemPath = normalizePath(itemURL.path)
        return excludedPaths.contains { excluded in
            let normalizedExcludedPath = normalizePath(excluded)
            return normalizedItemPath == normalizedExcludedPath
                || normalizedItemPath.hasPrefix(normalizedExcludedPath + "/")
        }
    }

    private static func isProtected(_ itemURL: URL, protectedRootPaths: Set<String>) -> Bool {
        let normalizedItemPath = normalizePath(itemURL.path)

        if protectedRootPaths.contains(where: { root in
            let normalizedRootPath = normalizePath(root)
            return normalizedItemPath == normalizedRootPath
                || normalizedItemPath.hasPrefix(normalizedRootPath + "/")
        }) {
            return true
        }

        if normalizedItemPath.contains("/.ssh/") || normalizedItemPath.hasSuffix("/.ssh") {
            return true
        }

        if normalizedItemPath.contains("/Library/Keychains/") || normalizedItemPath.hasSuffix("/Library/Keychains") {
            return true
        }

        if normalizedItemPath.contains("/Library/MobileDevice/Provisioning Profiles/")
            || normalizedItemPath.hasSuffix("/Library/MobileDevice/Provisioning Profiles") {
            return true
        }

        if URL(fileURLWithPath: normalizedItemPath).pathComponents.contains(".git") {
            return true
        }

        let ext = itemURL.pathExtension.lowercased()
        return protectedFileExtensions.contains(ext)
    }

    private static func shouldSkip(_ itemURL: URL, excludedPaths: Set<String>, protectedRootPaths: Set<String>) -> Bool {
        isExcluded(itemURL, excludedPaths: excludedPaths) || isProtected(itemURL, protectedRootPaths: protectedRootPaths)
    }

    private static func protectedRootPaths(homeDirectory: URL) -> Set<String> {
        Set([
            homeDirectory.appendingPathComponent(".ssh").path,
            homeDirectory.appendingPathComponent("Library/Keychains").path,
            homeDirectory.appendingPathComponent("Library/MobileDevice/Provisioning Profiles").path
        ])
    }

    private static func currentUserHomeDirectory() -> URL {
        let candidate = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        if candidate.path != "/" {
            return candidate
        }

        if let resolved = NSHomeDirectoryForUser(NSUserName()) {
            return URL(fileURLWithPath: resolved, isDirectory: true).standardizedFileURL
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    }

    private static func normalizePath(_ rawPath: String) -> String {
        URL(fileURLWithPath: rawPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}

extension JunkCleanerService: JunkCleaningServicing {
    func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry] {
        Self.scan(locations: locations, homeDirectory: homeDirectory, excludedPaths: excludedPaths)
    }

    func clean(entries: [JunkScanEntry], excludedPaths: Set<String>) -> JunkCleanSummary {
        Self.clean(entries: entries, excludedPaths: excludedPaths)
    }
}
