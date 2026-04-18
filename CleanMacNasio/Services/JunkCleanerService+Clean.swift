import Foundation

extension JunkCleanerService {
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

    static func deleteContents(
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

    static func deleteTarget(
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
}
