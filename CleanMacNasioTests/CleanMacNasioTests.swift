//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

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

    func testLogsScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let logs = home.appendingPathComponent("Library/Logs", isDirectory: true)
        try fileManager.createDirectory(at: logs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 12).write(to: logs.appendingPathComponent("app.log"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.logs],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .logs)
        XCTAssertEqual(entry.totalSize, 12)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testCustomTargetScanFindsSelectedDirectory() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let customTarget = home.appendingPathComponent("Library/Logs/CustomApp", isDirectory: true)
        try fileManager.createDirectory(at: customTarget, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 42).write(to: customTarget.appendingPathComponent("custom.log"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scanCustomTargets(
                directories: [customTarget],
                homeDirectory: home,
                excludedPaths: [],
                shouldCancel: { false }
            ).first
        )

        XCTAssertEqual(entry.location, .customCleanupTarget)
        XCTAssertEqual(entry.displayTitle, "Custom: CustomApp")
        XCTAssertEqual(entry.totalSize, 42)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testTemporaryDirectoryResolvePointsToSystemTemp() {
        let home = URL(fileURLWithPath: "/tmp/fake-home", isDirectory: true)
        let directories = JunkLocation.temporaryDirectory.resolveDirectories(homeDirectory: home)

        XCTAssertEqual(directories.count, 1)
        XCTAssertEqual(
            normalizedPath(directories[0].path),
            normalizedPath(URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).path)
        )
    }

    func testFlutterScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pubCache = home.appendingPathComponent(".pub-cache", isDirectory: true)
        let flutterCache = home.appendingPathComponent("Library/Caches/flutter", isDirectory: true)

        try fileManager.createDirectory(at: pubCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: flutterCache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 15).write(to: pubCache.appendingPathComponent("a.bin"))
        try Data(repeating: 1, count: 25).write(to: flutterCache.appendingPathComponent("b.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.flutterCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .flutterCaches)
        XCTAssertEqual(entry.totalSize, 40)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testUnityScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let unityCache = home.appendingPathComponent("Library/Unity/cache", isDirectory: true)
        let unityCacheMirror = home.appendingPathComponent("Library/Caches/Unity", isDirectory: true)
        let unityLogs = home.appendingPathComponent("Library/Logs/Unity", isDirectory: true)
        let unityHubLogs = home.appendingPathComponent("Library/Application Support/UnityHub/logs", isDirectory: true)

        try fileManager.createDirectory(at: unityCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unityCacheMirror, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unityLogs, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: unityHubLogs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 10).write(to: unityCache.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 20).write(to: unityCacheMirror.appendingPathComponent("mirror.bin"))
        try Data(repeating: 1, count: 30).write(to: unityLogs.appendingPathComponent("editor.log"))
        try Data(repeating: 1, count: 40).write(to: unityHubLogs.appendingPathComponent("hub.log"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.unityCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .unityCaches)
        XCTAssertEqual(entry.totalSize, 100)
        XCTAssertEqual(entry.fileCount, 4)
    }

    func testRobloxScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let robloxCache = home.appendingPathComponent("Library/Caches/Roblox", isDirectory: true)
        let robloxPlayerCache = home.appendingPathComponent("Library/Caches/com.roblox.RobloxPlayer", isDirectory: true)
        let robloxStudioCache = home.appendingPathComponent("Library/Caches/com.roblox.RobloxStudio", isDirectory: true)
        let robloxLogs = home.appendingPathComponent("Library/Logs/Roblox", isDirectory: true)

        try fileManager.createDirectory(at: robloxCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: robloxPlayerCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: robloxStudioCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: robloxLogs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 11).write(to: robloxCache.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 22).write(to: robloxPlayerCache.appendingPathComponent("player.bin"))
        try Data(repeating: 1, count: 33).write(to: robloxStudioCache.appendingPathComponent("studio.bin"))
        try Data(repeating: 1, count: 44).write(to: robloxLogs.appendingPathComponent("roblox.log"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.robloxCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .robloxCaches)
        XCTAssertEqual(entry.totalSize, 110)
        XCTAssertEqual(entry.fileCount, 4)
    }

    func testWhatsAppScanFindsCacheAndLogPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let containerCache = home.appendingPathComponent("Library/Containers/net.whatsapp.WhatsApp/Data/Library/Caches", isDirectory: true)
        let containerLogs = home.appendingPathComponent("Library/Containers/net.whatsapp.WhatsApp/Data/Library/Logs", isDirectory: true)
        let desktopCache = home.appendingPathComponent("Library/Caches/WhatsApp", isDirectory: true)
        let desktopLogs = home.appendingPathComponent("Library/Logs/WhatsApp", isDirectory: true)

        try fileManager.createDirectory(at: containerCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: containerLogs, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: desktopCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: desktopLogs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 12).write(to: containerCache.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 24).write(to: containerLogs.appendingPathComponent("app.log"))
        try Data(repeating: 1, count: 36).write(to: desktopCache.appendingPathComponent("desktop-cache.bin"))
        try Data(repeating: 1, count: 48).write(to: desktopLogs.appendingPathComponent("desktop.log"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.whatsAppCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .whatsAppCaches)
        XCTAssertEqual(entry.totalSize, 120)
        XCTAssertEqual(entry.fileCount, 4)
    }

    func testRecommendationDetectionFindsInstalledAppCaches() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let discordCache = home.appendingPathComponent("Library/Caches/com.hnc.Discord", isDirectory: true)
        let slackLog = home.appendingPathComponent("Library/Logs/Slack", isDirectory: true)
        let telegramCache = home.appendingPathComponent("Library/Caches/com.tdesktop.Telegram", isDirectory: true)

        try fileManager.createDirectory(at: discordCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: slackLog, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: telegramCache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 13).write(to: discordCache.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 23).write(to: slackLog.appendingPathComponent("log.bin"))
        try Data(repeating: 1, count: 31).write(to: telegramCache.appendingPathComponent("tg.bin"))

        let recommendations = JunkCleanerService.detectInstalledAppCacheRecommendations(homeDirectory: home)

        let names = Set(recommendations.map(\.appName))
        XCTAssertTrue(names.contains("Discord"))
        XCTAssertTrue(names.contains("Slack"))
        XCTAssertTrue(names.contains("Telegram"))
        XCTAssertEqual(recommendations.count, 3)

        let discord = try XCTUnwrap(recommendations.first(where: { $0.appName == "Discord" }))
        XCTAssertEqual(discord.directoryURLs.first?.path, discordCache.path)
        XCTAssertEqual(discord.fileCount, 1)
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

    func testCustomTargetStoreDeduplicatesNormalizesAndSortsPaths() {
        let suiteName = "CleanMacNasioTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CustomTargetStore(userDefaults: defaults)
        store.save(["/tmp/z/../z", "/tmp/a", "/tmp/z"])

        XCTAssertEqual(store.load(), ["/tmp/a", "/tmp/z"])
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

    func testXcodeDerivedDataScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)

        try fileManager.createDirectory(at: derivedData, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 17).write(to: derivedData.appendingPathComponent("index.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.xcodeDerivedData],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .xcodeDerivedData)
        XCTAssertEqual(entry.totalSize, 17)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testCocoaPodsScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cocoaPods = home.appendingPathComponent("Library/Caches/CocoaPods", isDirectory: true)

        try fileManager.createDirectory(at: cocoaPods, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 19).write(to: cocoaPods.appendingPathComponent("pod.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.cocoaPodsCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .cocoaPodsCaches)
        XCTAssertEqual(entry.totalSize, 19)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testSwiftPMScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let swiftPM = home.appendingPathComponent("Library/Caches/org.swift.swiftpm", isDirectory: true)

        try fileManager.createDirectory(at: swiftPM, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 23).write(to: swiftPM.appendingPathComponent("spm.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.swiftPMCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .swiftPMCaches)
        XCTAssertEqual(entry.totalSize, 23)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testNpmScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let npm = home.appendingPathComponent(".npm", isDirectory: true)

        try fileManager.createDirectory(at: npm, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 13).write(to: npm.appendingPathComponent("npm.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.npmCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .npmCaches)
        XCTAssertEqual(entry.totalSize, 13)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testYarnScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let yarnLibrary = home.appendingPathComponent("Library/Caches/Yarn", isDirectory: true)
        let yarnDotCache = home.appendingPathComponent(".cache/yarn", isDirectory: true)

        try fileManager.createDirectory(at: yarnLibrary, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: yarnDotCache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 14).write(to: yarnLibrary.appendingPathComponent("yarn1.bin"))
        try Data(repeating: 1, count: 16).write(to: yarnDotCache.appendingPathComponent("yarn2.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.yarnCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .yarnCaches)
        XCTAssertEqual(entry.totalSize, 30)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testPnpmStoreScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pnpmLibrary = home.appendingPathComponent("Library/pnpm/store", isDirectory: true)
        let pnpmDotStore = home.appendingPathComponent(".pnpm-store", isDirectory: true)

        try fileManager.createDirectory(at: pnpmLibrary, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: pnpmDotStore, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 18).write(to: pnpmLibrary.appendingPathComponent("pnpm1.bin"))
        try Data(repeating: 1, count: 21).write(to: pnpmDotStore.appendingPathComponent("pnpm2.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.pnpmStore],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .pnpmStore)
        XCTAssertEqual(entry.totalSize, 39)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testMavenScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let maven = home.appendingPathComponent(".m2/repository", isDirectory: true)

        try fileManager.createDirectory(at: maven, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 31).write(to: maven.appendingPathComponent("maven.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.mavenCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .mavenCaches)
        XCTAssertEqual(entry.totalSize, 31)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testIvyScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let ivy = home.appendingPathComponent(".ivy2/cache", isDirectory: true)

        try fileManager.createDirectory(at: ivy, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 32).write(to: ivy.appendingPathComponent("ivy.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.ivyCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .ivyCaches)
        XCTAssertEqual(entry.totalSize, 32)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testPipScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pipDotCache = home.appendingPathComponent(".cache/pip", isDirectory: true)
        let pipLibraryCache = home.appendingPathComponent("Library/Caches/pip", isDirectory: true)

        try fileManager.createDirectory(at: pipDotCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: pipLibraryCache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 17).write(to: pipDotCache.appendingPathComponent("pip-a.bin"))
        try Data(repeating: 1, count: 19).write(to: pipLibraryCache.appendingPathComponent("pip-b.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.pipCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .pipCaches)
        XCTAssertEqual(entry.totalSize, 36)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testCargoScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cargoRegistry = home.appendingPathComponent(".cargo/registry", isDirectory: true)
        let cargoGit = home.appendingPathComponent(".cargo/git", isDirectory: true)

        try fileManager.createDirectory(at: cargoRegistry, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cargoGit, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 26).write(to: cargoRegistry.appendingPathComponent("registry.bin"))
        try Data(repeating: 1, count: 24).write(to: cargoGit.appendingPathComponent("git.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.cargoCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .cargoCaches)
        XCTAssertEqual(entry.totalSize, 50)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testDockerScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dockerBuildx = home.appendingPathComponent(".docker/buildx", isDirectory: true)
        let dockerLibraryCache = home.appendingPathComponent("Library/Caches/com.docker.docker", isDirectory: true)
        let dockerLogs = home.appendingPathComponent("Library/Containers/com.docker.docker/Data/log", isDirectory: true)

        try fileManager.createDirectory(at: dockerBuildx, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dockerLibraryCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dockerLogs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 11).write(to: dockerBuildx.appendingPathComponent("buildx.bin"))
        try Data(repeating: 1, count: 22).write(to: dockerLibraryCache.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 33).write(to: dockerLogs.appendingPathComponent("log.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.dockerCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .dockerCaches)
        XCTAssertEqual(entry.totalSize, 66)
        XCTAssertEqual(entry.fileCount, 3)
    }

    func testPoetryPipenvScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let poetry = home.appendingPathComponent(".cache/pypoetry", isDirectory: true)
        let virtualenvs = home.appendingPathComponent(".local/share/virtualenvs", isDirectory: true)
        let pipenv = home.appendingPathComponent(".cache/pipenv", isDirectory: true)

        try fileManager.createDirectory(at: poetry, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: virtualenvs, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: pipenv, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 10).write(to: poetry.appendingPathComponent("poetry.bin"))
        try Data(repeating: 1, count: 20).write(to: virtualenvs.appendingPathComponent("venv.bin"))
        try Data(repeating: 1, count: 30).write(to: pipenv.appendingPathComponent("pipenv.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.poetryPipenvCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .poetryPipenvCaches)
        XCTAssertEqual(entry.totalSize, 60)
        XCTAssertEqual(entry.fileCount, 3)
    }

    func testGoScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let goBuild = home.appendingPathComponent("Library/Caches/go-build", isDirectory: true)
        let goMod = home.appendingPathComponent("go/pkg/mod", isDirectory: true)

        try fileManager.createDirectory(at: goBuild, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: goMod, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 12).write(to: goBuild.appendingPathComponent("gobuild.bin"))
        try Data(repeating: 1, count: 18).write(to: goMod.appendingPathComponent("gomod.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.goCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .goCaches)
        XCTAssertEqual(entry.totalSize, 30)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testRubyBundlerScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundleCache = home.appendingPathComponent(".bundle/cache", isDirectory: true)
        let gems = home.appendingPathComponent(".gem", isDirectory: true)

        try fileManager.createDirectory(at: bundleCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: gems, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 14).write(to: bundleCache.appendingPathComponent("bundle.bin"))
        try Data(repeating: 1, count: 16).write(to: gems.appendingPathComponent("gem.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.rubyBundlerCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .rubyBundlerCaches)
        XCTAssertEqual(entry.totalSize, 30)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testKubernetesHelmScanFindsPaths() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let kubeCache = home.appendingPathComponent(".kube/cache", isDirectory: true)
        let helmCache = home.appendingPathComponent(".cache/helm", isDirectory: true)

        try fileManager.createDirectory(at: kubeCache, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: helmCache, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 13).write(to: kubeCache.appendingPathComponent("kube.bin"))
        try Data(repeating: 1, count: 17).write(to: helmCache.appendingPathComponent("helm.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.kubernetesHelmCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .kubernetesHelmCaches)
        XCTAssertEqual(entry.totalSize, 30)
        XCTAssertEqual(entry.fileCount, 2)
    }

    func testXcodeArchivesScanFindsPath() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let archives = home.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true)

        try fileManager.createDirectory(at: archives, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 27).write(to: archives.appendingPathComponent("archive.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.xcodeArchives],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .xcodeArchives)
        XCTAssertEqual(entry.totalSize, 27)
        XCTAssertEqual(entry.fileCount, 1)
    }

    func testNixScanFindsUserNixCaches() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dotCacheNix = home.appendingPathComponent(".cache/nix", isDirectory: true)
        let localStateNix = home.appendingPathComponent(".local/state/nix", isDirectory: true)
        let libraryCacheNix = home.appendingPathComponent("Library/Caches/nix", isDirectory: true)

        try fileManager.createDirectory(at: dotCacheNix, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: localStateNix, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: libraryCacheNix, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }

        try Data(repeating: 1, count: 11).write(to: dotCacheNix.appendingPathComponent("cache.bin"))
        try Data(repeating: 1, count: 22).write(to: localStateNix.appendingPathComponent("state.bin"))
        try Data(repeating: 1, count: 33).write(to: libraryCacheNix.appendingPathComponent("index.bin"))

        let entry = try XCTUnwrap(
            JunkCleanerService.scan(
                locations: [.nixCaches],
                homeDirectory: home,
                excludedPaths: []
            ).first
        )

        XCTAssertEqual(entry.location, .nixCaches)
        XCTAssertEqual(entry.totalSize, 66)
        XCTAssertEqual(entry.fileCount, 3)
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

    func testCleanSkipsProtectedSensitiveFiles() throws {
        let fileManager = FileManager.default
        let home = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        let protectedFile = caches.appendingPathComponent("private.pem")

        try fileManager.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: home) }
        try Data(repeating: 1, count: 256).write(to: protectedFile)

        let entry = JunkScanEntry(
            location: .caches,
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
            exclusionStore: FakeExclusionStore(paths: ["/tmp/restored-home/keep"]),
            customTargetStore: FakeCustomTargetStore(paths: ["/tmp/restored-home/custom"])
        )

        viewModel.restoreSavedState()

        XCTAssertEqual(viewModel.homeDirectoryURL, expectedHome)
        XCTAssertEqual(viewModel.excludedPaths, ["/tmp/restored-home/keep"])
        XCTAssertEqual(viewModel.customTargetPaths, ["/tmp/restored-home/custom"])
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
    func testViewModelAddRecommendedCacheDirectoriesPersistsAndDedupes() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let recommendationPath = home.appendingPathComponent("Library/Caches/Discord", isDirectory: true)
        let service = FakeJunkCleaningService(scanEntries: [])
        let customTargetStore = FakeCustomTargetStore(paths: [])
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            customTargetStore: customTargetStore,
            homeDirectoryURL: home
        )

        viewModel.addRecommendedCacheDirectories([recommendationPath])
        viewModel.addRecommendedCacheDirectories([recommendationPath])

        XCTAssertEqual(viewModel.customTargetPaths, [recommendationPath.path])
        XCTAssertEqual(customTargetStore.savedPathsHistory, [[recommendationPath.path]])
        XCTAssertEqual(service.scanCallCount, 1)
    }

    @MainActor
    func testViewModelCustomTargetPersistsRescansAndStaysUnselected() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let customTarget = home.appendingPathComponent("Library/Logs/CustomApp", isDirectory: true)
        let customEntry = JunkScanEntry(
            location: .customCleanupTarget,
            directoryURLs: [customTarget],
            totalSize: 64,
            fileCount: 1,
            errorMessage: nil,
            previewItems: [],
            excludedItemsCount: 0
        )
        let service = FakeJunkCleaningService(scanEntries: [], customTargetEntries: [customEntry])
        let customTargetStore = FakeCustomTargetStore(paths: [])
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            customTargetStore: customTargetStore,
            homeDirectoryURL: home
        )

        viewModel.addCustomTarget(customTarget)

        XCTAssertEqual(viewModel.customTargetPaths, [customTarget.path])
        XCTAssertEqual(customTargetStore.savedPathsHistory, [[customTarget.path]])
        XCTAssertEqual(service.customTargetScanCallCount, 1)
        XCTAssertEqual(service.lastCustomTargetDirectories, [customTarget])
        XCTAssertFalse(viewModel.isSelected(customEntry.id))

        viewModel.removeCustomTarget(customTarget.path)

        XCTAssertEqual(viewModel.customTargetPaths, [])
        XCTAssertEqual(customTargetStore.savedPathsHistory, [[customTarget.path], []])
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
        let custom = makeScanEntry(location: .customCleanupTarget, home: home, totalSize: 50, fileCount: 1)
        let viewModel = ContentViewModel(
            cleanerService: FakeJunkCleaningService(scanEntries: []),
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [first, second, zero, custom]
        )

        viewModel.selectAllDetected()
        XCTAssertTrue(viewModel.isSelected(first.id))
        XCTAssertTrue(viewModel.isSelected(second.id))
        XCTAssertFalse(viewModel.isSelected(zero.id))
        XCTAssertFalse(viewModel.isSelected(custom.id))
        XCTAssertEqual(viewModel.selectedTotalSize, 300)
        XCTAssertEqual(viewModel.selectedCategoryCount, 2)

        viewModel.clearSelection()
        XCTAssertFalse(viewModel.hasSelection)
        XCTAssertEqual(viewModel.selectedTotalSize, 0)
    }

    @MainActor
    func testViewModelRequiresConfirmationForXcodeArchivesClean() {
        let home = URL(fileURLWithPath: "/tmp/home")
        let archiveEntry = makeScanEntry(location: .xcodeArchives, home: home, totalSize: 120, fileCount: 1)
        let service = FakeJunkCleaningService(
            scanEntries: [makeScanEntry(location: .caches, home: home, totalSize: 0, fileCount: 0)],
            cleanSummary: JunkCleanSummary(results: [
                JunkCleanEntryResult(location: .xcodeArchives, deletedItems: 1, freedSize: 120, errors: [])
            ])
        )
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [archiveEntry]
        )

        viewModel.toggleSelection(for: archiveEntry.id)
        viewModel.cleanSelected()
        XCTAssertTrue(viewModel.showArchiveCleanConfirmation)
        XCTAssertEqual(service.cleanCallCount, 0)

        viewModel.confirmCleanSelectedIncludingArchives()
        XCTAssertFalse(viewModel.showArchiveCleanConfirmation)
        XCTAssertEqual(service.cleanCallCount, 1)
    }

    @MainActor
    func testViewModelRequiresConfirmationForCustomTargetClean() {
        let home = URL(fileURLWithPath: "/tmp/home", isDirectory: true)
        let customEntry = makeScanEntry(location: .customCleanupTarget, home: home, totalSize: 120, fileCount: 1)
        let service = FakeJunkCleaningService(
            scanEntries: [],
            cleanSummary: JunkCleanSummary(results: [
                JunkCleanEntryResult(location: .customCleanupTarget, deletedItems: 1, freedSize: 120, errors: [])
            ])
        )
        let viewModel = ContentViewModel(
            cleanerService: service,
            bookmarkStore: FakeBookmarkStore(url: home),
            exclusionStore: FakeExclusionStore(paths: []),
            customTargetStore: FakeCustomTargetStore(paths: []),
            homeDirectoryURL: home,
            scanEntries: [customEntry]
        )

        viewModel.toggleSelection(for: customEntry.id)
        viewModel.cleanSelected()
        XCTAssertTrue(viewModel.showCustomTargetCleanConfirmation)
        XCTAssertEqual(service.cleanCallCount, 0)

        viewModel.confirmCleanSelectedIncludingCustomTargets()
        XCTAssertFalse(viewModel.showCustomTargetCleanConfirmation)
        XCTAssertEqual(service.cleanCallCount, 1)
    }
}

private final class FakeJunkCleaningService: @unchecked Sendable, JunkCleaningServicing {
    private let scanEntries: [JunkScanEntry]
    private let customTargetEntries: [JunkScanEntry]
    private let cleanSummary: JunkCleanSummary
    private(set) var lastExcludedPaths: Set<String> = []
    private(set) var lastHomeDirectoryURL: URL?
    private(set) var lastCleanEntries: [JunkScanEntry] = []
    private(set) var lastCustomTargetDirectories: [URL] = []
    private(set) var scanCallCount = 0
    private(set) var customTargetScanCallCount = 0
    private(set) var cleanCallCount = 0

    init(
        scanEntries: [JunkScanEntry],
        customTargetEntries: [JunkScanEntry] = [],
        cleanSummary: JunkCleanSummary = JunkCleanSummary(results: [])
    ) {
        self.scanEntries = scanEntries
        self.customTargetEntries = customTargetEntries
        self.cleanSummary = cleanSummary
    }

    func scan(locations: [JunkLocation], homeDirectory: URL, excludedPaths: Set<String>) -> [JunkScanEntry] {
        scanCallCount += 1
        lastHomeDirectoryURL = homeDirectory
        lastExcludedPaths = excludedPaths
        return scanEntries
    }

    func scanCustomTargets(
        directories: [URL],
        homeDirectory: URL,
        excludedPaths: Set<String>,
        shouldCancel: @escaping @Sendable () -> Bool
    ) -> [JunkScanEntry] {
        customTargetScanCallCount += 1
        lastCustomTargetDirectories = directories
        lastHomeDirectoryURL = homeDirectory
        lastExcludedPaths = excludedPaths
        return customTargetEntries
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

private final class FakeCustomTargetStore: CustomTargetStoring {
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
