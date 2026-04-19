//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import Foundation

extension JunkCleanerService {
    static func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry] {
        scan(
            locations: locations,
            homeDirectory: homeDirectory,
            excludedPaths: excludedPaths,
            shouldCancel: { false }
        )
    }

    static func scan(
        locations: [JunkLocation],
        homeDirectory: URL,
        excludedPaths: Set<String>,
        shouldCancel: @escaping @Sendable () -> Bool
    ) -> [JunkScanEntry] {
        let protectedRoots = protectedRootPaths(homeDirectory: homeDirectory)
        var allEntries: [JunkScanEntry] = []

        for location in locations {
            if shouldCancel() { break }
            switch location {
            case .gradleCaches:
                allEntries.append(contentsOf: buildGradleScanEntries(
                    homeDirectory: homeDirectory,
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRoots,
                    shouldCancel: shouldCancel
                ))
            default:
                let directories = location.resolveDirectories(homeDirectory: homeDirectory)
                allEntries.append(
                    buildScanEntry(
                        location: location,
                        directories: directories,
                        excludedPaths: excludedPaths,
                        protectedRootPaths: protectedRoots,
                        shouldCancel: shouldCancel
                    )
                )
            }
        }

        return allEntries
    }

    static func buildScanEntry(
        location: JunkLocation,
        directories: [URL],
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>,
        shouldCancel: @escaping @Sendable () -> Bool
    ) -> JunkScanEntry {
        var totalSize: UInt64 = 0
        var totalFiles = 0
        var excludedItemsCount = 0
        var previewRows: [JunkPreviewItem] = []
        var errors: [String] = []

        for directory in directories {
            if shouldCancel() { break }
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            do {
                let children = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                )

                for child in children {
                    if shouldCancel() { break }
                    if shouldSkip(child, excludedPaths: excludedPaths, protectedRootPaths: protectedRootPaths) {
                        excludedItemsCount += 1
                        continue
                    }
                    let metrics = FileUtils.itemMetrics(at: child)
                    totalSize += metrics.totalSize
                    totalFiles += metrics.fileCount
                    updateTopPreviewRows(
                        &previewRows,
                        item: JunkPreviewItem(path: child.path, size: metrics.totalSize),
                        limit: 5
                    )
                }
            } catch {
                errors.append("\(directory.path): \(error.localizedDescription)")
            }
        }

        return JunkScanEntry(
            location: location,
            directoryURLs: directories,
            totalSize: totalSize,
            fileCount: totalFiles,
            errorMessage: errors.isEmpty ? nil : errors.joined(separator: "\n"),
            previewItems: previewRows,
            excludedItemsCount: excludedItemsCount
        )
    }

    static func buildGradleScanEntries(
        homeDirectory: URL,
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>,
        shouldCancel: @escaping @Sendable () -> Bool
    ) -> [JunkScanEntry] {
        let cacheRoot = homeDirectory.appendingPathComponent(".gradle/caches")
        let wrapperRoot = homeDirectory.appendingPathComponent(".gradle/wrapper")

        var entries: [JunkScanEntry] = []

        let versionDirectories = gradleVersionDirectories(in: cacheRoot).sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        for versionDirectory in versionDirectories {
            if shouldCancel() { break }
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [versionDirectory],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths,
                    shouldCancel: shouldCancel
                )
            )
        }

        if shouldCancel() {
            return entries
        }

        let sharedDirectories = gradleSharedDirectories(in: cacheRoot, excluding: Set(versionDirectories.map(\.path)))
        if !sharedDirectories.isEmpty {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: sharedDirectories,
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths,
                    shouldCancel: shouldCancel
                )
            )
        }

        if !shouldCancel(), fileManager.fileExists(atPath: wrapperRoot.path) {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [wrapperRoot],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths,
                    shouldCancel: shouldCancel
                )
            )
        }

        if entries.isEmpty, !shouldCancel() {
            entries.append(
                buildScanEntry(
                    location: .gradleCaches,
                    directories: [cacheRoot, wrapperRoot],
                    excludedPaths: excludedPaths,
                    protectedRootPaths: protectedRootPaths,
                    shouldCancel: shouldCancel
                )
            )
        }

        return entries
    }

    static func gradleVersionDirectories(in cacheRoot: URL) -> [URL] {
        childDirectories(in: cacheRoot).filter { looksLikeGradleVersion($0.lastPathComponent) }
    }

    static func gradleSharedDirectories(in cacheRoot: URL, excluding excludedPaths: Set<String>) -> [URL] {
        childDirectories(in: cacheRoot).filter { !excludedPaths.contains($0.path) }
    }

    static func childDirectories(in parent: URL) -> [URL] {
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

    static func looksLikeGradleVersion(_ value: String) -> Bool {
        value.range(of: #"^[0-9]+(\.[0-9A-Za-z-]+)+$"#, options: .regularExpression) != nil
    }

    private static func updateTopPreviewRows(_ rows: inout [JunkPreviewItem], item: JunkPreviewItem, limit: Int) {
        guard item.size > 0 else { return }
        rows.append(item)
        rows.sort { $0.size > $1.size }
        if rows.count > limit {
            rows.removeSubrange(limit...)
        }
    }
}
