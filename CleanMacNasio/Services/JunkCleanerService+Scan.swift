import Foundation

extension JunkCleanerService {
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

    static func buildScanEntry(
        location: JunkLocation,
        directories: [URL],
        excludedPaths: Set<String>,
        protectedRootPaths: Set<String>
    ) -> JunkScanEntry {
        var totalSize: UInt64 = 0
        var totalFiles = 0
        var excludedItemsCount = 0
        var previewRows: [JunkPreviewItem] = []
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
