//
//  FileUtils.swift
//  CleanMacNasio
//
//  Created by Mories Hutapea on 19/07/25.
//

import Foundation

struct FileUtils {
    static let fileManager = FileManager.default
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    struct FolderMetrics {
        let totalSize: UInt64
        let fileCount: Int
    }

    struct ItemMetrics {
        let totalSize: UInt64
        let fileCount: Int
    }

    /// Hitung total size (dalam byte) dan jumlah file dari semua isi folder.
    static func folderMetrics(at url: URL) -> FolderMetrics {
        guard fileManager.fileExists(atPath: url.path) else {
            return FolderMetrics(totalSize: 0, fileCount: 0)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return FolderMetrics(totalSize: 0, fileCount: 0)
        }

        var totalSize: UInt64 = 0
        var fileCount: Int = 0

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile ?? false {
                    totalSize += UInt64(resourceValues.fileSize ?? 0)
                    fileCount += 1
                }
            } catch {}
        }

        return FolderMetrics(totalSize: totalSize, fileCount: fileCount)
    }

    /// Hitung total size (dalam byte) dari semua isi folder.
    static func folderSize(at url: URL) -> UInt64 {
        folderMetrics(at: url).totalSize
    }

    /// Hitung ukuran satu file/folder secara rekursif.
    static func itemSize(at url: URL) -> UInt64 {
        itemMetrics(at: url).totalSize
    }

    /// Hitung ukuran dan jumlah file pada satu file/folder.
    static func itemMetrics(at url: URL) -> ItemMetrics {
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])

            if values.isRegularFile ?? false {
                return ItemMetrics(totalSize: UInt64(values.fileSize ?? 0), fileCount: 1)
            }

            if values.isDirectory ?? false {
                let folder = folderMetrics(at: url)
                return ItemMetrics(totalSize: folder.totalSize, fileCount: folder.fileCount)
            }
        } catch {}

        return ItemMetrics(totalSize: 0, fileCount: 0)
    }

    /// Format byte ke string human readable (KB/MB/GB)
    static func formatBytes(_ bytes: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(bytes))
    }
}
