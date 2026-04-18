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
        }
    }

    private var relativePath: String? {
        switch self {
        case .caches:
            return "Library/Caches"
        case .logs:
            return "Library/Logs"
        case .temporaryDirectory, .androidStudioCaches, .gradleCaches, .flutterCaches, .homebrewCaches, .trash:
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
    static let fileManager = FileManager.default
    static let protectedFileExtensions: Set<String> = [
        "jks", "keystore",
        "p12", "cer", "pem", "key", "mobileprovision",
        "db", "sqlite", "sqlite3"
    ]

    static func isExcluded(_ itemURL: URL, excludedPaths: Set<String>) -> Bool {
        let normalizedItemPath = normalizePath(itemURL.path)
        return excludedPaths.contains { excluded in
            let normalizedExcludedPath = normalizePath(excluded)
            return normalizedItemPath == normalizedExcludedPath
                || normalizedItemPath.hasPrefix(normalizedExcludedPath + "/")
        }
    }

    static func isProtected(_ itemURL: URL, protectedRootPaths: Set<String>) -> Bool {
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

    static func shouldSkip(_ itemURL: URL, excludedPaths: Set<String>, protectedRootPaths: Set<String>) -> Bool {
        isExcluded(itemURL, excludedPaths: excludedPaths)
            || isProtected(itemURL, protectedRootPaths: protectedRootPaths)
    }

    static func protectedRootPaths(homeDirectory: URL) -> Set<String> {
        Set([
            homeDirectory.appendingPathComponent(".ssh").path,
            homeDirectory.appendingPathComponent("Library/Keychains").path,
            homeDirectory.appendingPathComponent("Library/MobileDevice/Provisioning Profiles").path
        ])
    }

    static func currentUserHomeDirectory() -> URL {
        let candidate = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        if candidate.path != "/" {
            return candidate
        }

        if let resolved = NSHomeDirectoryForUser(NSUserName()) {
            return URL(fileURLWithPath: resolved, isDirectory: true).standardizedFileURL
        }

        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
    }

    static func normalizePath(_ rawPath: String) -> String {
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
