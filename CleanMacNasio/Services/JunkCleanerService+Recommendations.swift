//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-07-12
//

import Foundation

struct AppCacheRecommendationProfile {
    let appName: String
    let relativePaths: [String]
    let note: String?
}

extension JunkCleanerService {
    struct AppCacheRecommendation: Identifiable, Equatable {
        let appName: String
        let directoryURLs: [URL]
        let totalSize: UInt64
        let fileCount: Int
        let note: String?

        var id: String {
            let base = directoryURLs.first?.path ?? appName
            return "\(appName)|\(base)"
        }

        var directoryPathText: String {
            directoryURLs.map(\.path).joined(separator: "\n")
        }

        var formattedSizeText: String {
            FileUtils.formatBytes(totalSize)
        }
    }

    static func detectInstalledAppCacheRecommendations(homeDirectory: URL) -> [AppCacheRecommendation] {
        let detected: [AppCacheRecommendation] = recommendedAppCacheProfiles.compactMap { profile in
            let matchedPaths = profile.relativePaths.compactMap { relativePath in
                let directory = homeDirectory
                    .appendingPathComponent(relativePath)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                return fileManager.fileExists(atPath: directory.path) ? directory : nil
            }

            guard !matchedPaths.isEmpty else { return nil }

            var totalSize: UInt64 = 0
            var fileCount: Int = 0
            for path in matchedPaths {
                let folderMetrics = FileUtils.folderMetrics(at: path)
                totalSize += folderMetrics.totalSize
                fileCount += folderMetrics.fileCount
            }
            let metrics = (totalSize: totalSize, fileCount: fileCount)

            return AppCacheRecommendation(
                appName: profile.appName,
                directoryURLs: matchedPaths.sorted(by: { $0.path < $1.path }),
                totalSize: metrics.totalSize,
                fileCount: metrics.fileCount,
                note: profile.note
            )
        }

        return detected
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private static let recommendedAppCacheProfiles: [AppCacheRecommendationProfile] = [
        AppCacheRecommendationProfile(
            appName: "Discord",
            relativePaths: [
                "Library/Caches/com.hnc.Discord",
                "Library/Logs/Discord"
            ],
            note: "Cache Discord yang umum ditemukan di `com.hnc.Discord`."
        ),
        AppCacheRecommendationProfile(
            appName: "Figma",
            relativePaths: [
                "Library/Caches/Figma",
                "Library/Application Support/Figma/Caches"
            ],
            note: "Cache Figma dan cache editor/renderer."
        ),
        AppCacheRecommendationProfile(
            appName: "Notion",
            relativePaths: [
                "Library/Caches/com.notion.id",
                "Library/Logs/notion"
            ],
            note: "Cache Notion lokal."
        ),
        AppCacheRecommendationProfile(
            appName: "Telegram",
            relativePaths: [
                "Library/Caches/com.tdesktop.Telegram",
                "Library/Application Support/Telegram Desktop/tdata",
                "Library/Logs/Telegram Desktop"
            ],
            note: "Cache dan aset sesi Telegram Desktop."
        ),
        AppCacheRecommendationProfile(
            appName: "Obsidian",
            relativePaths: [
                "Library/Caches/md.obsidian",
                "Library/Caches/com.obsidian"
            ],
            note: "Cache Obsidian Vault dan plugins."
        ),
        AppCacheRecommendationProfile(
            appName: "Google Chrome",
            relativePaths: [
                "Library/Caches/Google/Chrome",
                "Library/Logs/Google/Chrome"
            ],
            note: "Cache browser Chrome yang umumnya berada di folder caches/logs."
        ),
        AppCacheRecommendationProfile(
            appName: "Slack",
            relativePaths: [
                "Library/Caches/com.tinyspeck.slackmacgap",
                "Library/Application Support/Slack/Cache",
                "Library/Logs/Slack"
            ],
            note: "Cache cache dan data sesi lokal Slack."
        ),
        AppCacheRecommendationProfile(
            appName: "Spotify",
            relativePaths: [
                "Library/Caches/com.spotify.client",
                "Library/Logs/com.spotify.client"
            ],
            note: "Cache audio art/asset Spotify."
        ),
        AppCacheRecommendationProfile(
            appName: "Visual Studio Code",
            relativePaths: [
                "Library/Caches/com.microsoft.VSCode",
                "Library/Caches/com.microsoft.VSCode.ShipIt",
                "Library/Application Support/Code/Cache"
            ],
            note: "Cache extension/editor dan artefak download."
        ),
        AppCacheRecommendationProfile(
            appName: "Microsoft Edge",
            relativePaths: [
                "Library/Caches/com.microsoft.Edge",
                "Library/Application Support/Microsoft/Edge/Default/Cache",
                "Library/Logs/Microsoft Edge"
            ],
            note: "Cache Edge berbasis cache browser umum."
        ),
        AppCacheRecommendationProfile(
            appName: "Microsoft Teams",
            relativePaths: [
                "Library/Caches/com.microsoft.Teams",
                "Library/Application Support/Microsoft/Teams/Application Cache",
                "Library/Logs/Microsoft/Teams"
            ],
            note: "Cache lokal Microsoft Teams."
        )
    ]
}
