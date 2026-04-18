//
//  ContentView.swift
//  CleanMacNasio
//
//  Created by Mories Hutapea on 19/07/25.
//

import AppKit
import SwiftUI

private enum DashboardStyle {
    static let text = Color(nsColor: .labelColor)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let backgroundOverlay = Color(nsColor: .underPageBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let recessedPanel = Color(nsColor: .textBackgroundColor)
    static let accent = Color(red: 0.02, green: 0.45, blue: 0.40)
    static let border = Color(nsColor: .separatorColor)
}

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel())
    }

    init(
        previewHomeDirectoryURL: URL?,
        previewScanEntries: [JunkScanEntry],
        previewExcludedPaths: [String],
        previewLogMessage: String
    ) {
        _viewModel = StateObject(
            wrappedValue: ContentViewModel(
                homeDirectoryURL: previewHomeDirectoryURL,
                scanEntries: previewScanEntries,
                excludedPaths: previewExcludedPaths,
                logMessage: previewLogMessage
            )
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DashboardStyle.background,
                    DashboardStyle.backgroundOverlay
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DashboardHeader(
                        homePath: viewModel.homeDirectoryURL?.path,
                        isBusy: viewModel.isBusy,
                        isScanning: viewModel.isScanning,
                        statusText: viewModel.statusText,
                        scanProgressMessage: viewModel.scanProgressMessage,
                        scanProgressDetail: viewModel.scanProgressDetail,
                        scanProgressFraction: viewModel.scanProgressFraction,
                        onScan: viewModel.scanJunk,
                        onStopScan: viewModel.requestStopScan,
                        canScan: viewModel.canScan
                    )

                    HStack(alignment: .top, spacing: 14) {
                        MetricTile(title: "Ready To Clean", value: FileUtils.formatBytes(viewModel.selectedTotalSize), caption: "\(viewModel.selectedCategoryCount) categories")
                        MetricTile(title: "Detected", value: FileUtils.formatBytes(viewModel.totalScanSize), caption: "\(viewModel.totalFileCount) files")
                        MetricTile(title: "Excluded", value: "\(viewModel.excludedPaths.count)", caption: "protected paths")
                    }

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Clean Targets", subtitle: "Auto-scanned from common cache locations")

                            if viewModel.scanEntries.isEmpty {
                                EmptyScanState()
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.scanEntries) { entry in
                                        JunkLocationCard(
                                            entry: entry,
                                            isSelected: viewModel.isSelected(entry.id),
                                            onToggle: { viewModel.toggleSelection(for: entry.id) }
                                        )
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Actions", subtitle: "Pilih item yang mau dihapus")

                            SelectionActionPanel(
                                selectedCount: viewModel.selectedCategoryCount,
                                selectedTotalSize: viewModel.selectedTotalSize,
                                canClean: viewModel.canClean,
                                hasSelection: viewModel.hasSelection,
                                onSelectAll: viewModel.selectAllDetected,
                                onClearSelection: viewModel.clearSelection,
                                onCleanSelected: viewModel.cleanSelected
                            )

                            SectionTitle(title: "Protection", subtitle: "Excluded paths stay untouched")

                            ExcludedPathsPanel(
                                excludedPaths: viewModel.excludedPaths,
                                onAdd: pickExcludePath,
                                onRemove: viewModel.removeExcludedPath
                            )

                            if !viewModel.logMessage.isEmpty || viewModel.isBusy {
                                StatusPanel(
                                    message: viewModel.logMessage,
                                    isWorking: viewModel.isBusy,
                                    workingText: viewModel.workingText,
                                    progressMessage: viewModel.isCleaning ? viewModel.cleanProgressMessage : viewModel.scanProgressMessage,
                                    progressDetail: viewModel.isCleaning ? viewModel.cleanProgressDetail : viewModel.scanProgressDetail,
                                    progressFraction: viewModel.isCleaning ? viewModel.cleanProgressFraction : viewModel.scanProgressFraction
                                )
                            }
                        }
                        .frame(width: 280, alignment: .topLeading)
                    }
                }
                .padding(28)
            }
        }
        .foregroundColor(DashboardStyle.text)
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            guard !isRunningInPreview else { return }
            viewModel.restoreSavedState()
        }
    }

    private func pickExcludePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Pilih file/folder yang tidak boleh ikut dibersihkan"
        panel.prompt = "Exclude"

        if panel.runModal() == .OK, let pickedURL = panel.url {
            viewModel.addExcludedPath(pickedURL.path)
        }
    }
}

private struct DashboardHeader: View {
    let homePath: String?
    let isBusy: Bool
    let isScanning: Bool
    let statusText: String
    let scanProgressMessage: String
    let scanProgressDetail: String
    let scanProgressFraction: Double
    let onScan: () -> Void
    let onStopScan: () -> Void
    let canScan: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("CleanMacNasio")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    StatusPill(text: statusText, isBusy: isBusy)
                }

                Text(homePath ?? "Press Scan to check common cache locations in Home directory.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Scan", action: onScan)
                    .controlSize(.large)
                    .disabled(!canScan)

                if isScanning {
                    Button("Stop", action: onStopScan)
                        .controlSize(.large)
                }
            }

            if isScanning {
                VStack(alignment: .trailing, spacing: 6) {
                    ProgressView(value: scanProgressFraction, total: 1.0)
                        .controlSize(.small)
                    Text(scanProgressMessage.isEmpty ? "Scanning..." : scanProgressMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DashboardStyle.mutedText)
                        .lineLimit(1)
                    if !scanProgressDetail.isEmpty {
                        Text(scanProgressDetail)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(DashboardStyle.mutedText)
                            .lineLimit(2)
                    }
                }
                .frame(width: 420, alignment: .trailing)
            }
        }
        .padding(22)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private struct StatusPill: View {
    let text: String
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isBusy ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DashboardStyle.recessedPanel, in: Capsule())
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .fontWeight(.semibold)
                .foregroundColor(DashboardStyle.mutedText)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DashboardStyle.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DashboardStyle.mutedText)
        }
    }
}

private struct EmptyScanState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No scan result yet")
                .font(.headline)
            Text("Press Scan to check common cache locations and review detected junk.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DashboardStyle.mutedText)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
        .padding(22)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private struct JunkLocationCard: View {
    let entry: JunkScanEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isSelected ? DashboardStyle.accent : DashboardStyle.mutedText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.displayTitle)
                        .font(.system(size: 17, weight: .bold))
                    Text(entry.directoryPathText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(DashboardStyle.mutedText)
                        .lineLimit(3)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(FileUtils.formatBytes(entry.totalSize))
                        .font(.system(size: 17, weight: .bold))
                    Text("\(entry.fileCount) files")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DashboardStyle.mutedText)
                }
            }

            if entry.excludedItemsCount > 0 {
                Text("\(entry.excludedItemsCount) excluded items")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DashboardStyle.mutedText)
            }

            if !entry.previewItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top items")
                        .font(.system(size: 12, weight: .bold))
                        .fontWeight(.semibold)
                    ForEach(entry.previewItems) { item in
                        HStack(spacing: 8) {
                            Text(item.path)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DashboardStyle.mutedText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(FileUtils.formatBytes(item.size))
                                .font(.system(size: 12, weight: .bold))
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(10)
                .background(DashboardStyle.recessedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            if let errorMessage = entry.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? DashboardStyle.accent : DashboardStyle.border, lineWidth: isSelected ? 2 : 1)
        )
    }
}

private struct SelectionActionPanel: View {
    let selectedCount: Int
    let selectedTotalSize: UInt64
    let canClean: Bool
    let hasSelection: Bool
    let onSelectAll: () -> Void
    let onClearSelection: () -> Void
    let onCleanSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected: \(selectedCount) categories")
                .font(.system(size: 13, weight: .semibold))
            Text("Total: \(FileUtils.formatBytes(selectedTotalSize))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DashboardStyle.mutedText)

            HStack(spacing: 8) {
                Button("Select All", action: onSelectAll)
                    .controlSize(.small)
                Button("Clear", action: onClearSelection)
                    .controlSize(.small)
                    .disabled(!hasSelection)
            }

            Button("Clean Selected", action: onCleanSelected)
                .controlSize(.large)
                .disabled(!canClean)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private struct ExcludedPathsPanel: View {
    let excludedPaths: [String]
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Add Exclude Path", action: onAdd)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)

            if excludedPaths.isEmpty {
                Text("No protected path yet.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(excludedPaths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Text(path)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DashboardStyle.mutedText)
                                .lineLimit(2)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Remove") {
                                onRemove(path)
                            }
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(DashboardStyle.recessedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private struct StatusPanel: View {
    let message: String
    let isWorking: Bool
    let workingText: String
    let progressMessage: String
    let progressDetail: String
    let progressFraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isWorking {
                ProgressView(value: progressFraction, total: 1.0) {
                    Text(progressMessage.isEmpty ? workingText : progressMessage)
                        .font(.system(size: 12, weight: .semibold))
                }
                .controlSize(.small)

                if !progressDetail.isEmpty {
                    Text(progressDetail)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(DashboardStyle.mutedText)
                        .lineLimit(3)
                }
            }

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }
}

private extension ContentView {
    static var previewContent: ContentView {
        ContentView(
            previewHomeDirectoryURL: URL(fileURLWithPath: "/Users/yourname"),
            previewScanEntries: [
                JunkScanEntry(
                    location: .caches,
                    directoryURLs: [URL(fileURLWithPath: "/Users/yourname/Library/Caches")],
                    totalSize: 3_456_789_012,
                    fileCount: 1284,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/Library/Caches/Xcode/DerivedData", size: 1_734_003_456),
                        JunkPreviewItem(path: "/Users/yourname/Library/Caches/Google/Chrome", size: 754_008_112)
                    ],
                    excludedItemsCount: 1
                ),
                JunkScanEntry(
                    location: .androidStudioCaches,
                    directoryURLs: [
                        URL(fileURLWithPath: "/Users/yourname/Library/Caches/Google/AndroidStudio2025.1"),
                        URL(fileURLWithPath: "/Users/yourname/Library/Application Support/Google/AndroidStudio2025.1/caches")
                    ],
                    totalSize: 2_012_300_000,
                    fileCount: 845,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/Library/Caches/Google/AndroidStudio2025.1/index", size: 1_102_000_000)
                    ],
                    excludedItemsCount: 0
                ),
                JunkScanEntry(
                    location: .gradleCaches,
                    directoryURLs: [
                        URL(fileURLWithPath: "/Users/yourname/.gradle/caches"),
                        URL(fileURLWithPath: "/Users/yourname/.gradle/wrapper")
                    ],
                    totalSize: 945_230_000,
                    fileCount: 390,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/.gradle/caches/modules-2", size: 690_000_000)
                    ],
                    excludedItemsCount: 0
                ),
                JunkScanEntry(
                    location: .homebrewCaches,
                    directoryURLs: [
                        URL(fileURLWithPath: "/Users/yourname/Library/Caches/Homebrew"),
                        URL(fileURLWithPath: "/Users/yourname/.cache/Homebrew")
                    ],
                    totalSize: 430_120_000,
                    fileCount: 52,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/Library/Caches/Homebrew/downloads/ruby-3.3.tar.gz", size: 220_000_000)
                    ],
                    excludedItemsCount: 0
                ),
                JunkScanEntry(
                    location: .trash,
                    directoryURLs: [
                        URL(fileURLWithPath: "/Users/yourname/.Trash")
                    ],
                    totalSize: 120_500_000,
                    fileCount: 16,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/.Trash/old-build.zip", size: 75_000_000)
                    ],
                    excludedItemsCount: 0
                ),
                JunkScanEntry(
                    location: .largeFiles,
                    directoryURLs: [
                        URL(fileURLWithPath: "/Users/yourname/Movies/archive-raw.mov")
                    ],
                    totalSize: 1_600_000_000,
                    fileCount: 1,
                    errorMessage: nil,
                    previewItems: [
                        JunkPreviewItem(path: "/Users/yourname/Movies/archive-raw.mov", size: 1_600_000_000)
                    ],
                    excludedItemsCount: 0
                )
            ],
            previewExcludedPaths: [
                "/Users/yourname/Library/Caches/Google/Chrome/Profile 1",
                "/Users/yourname/.gradle/caches/keep-this-folder"
            ],
            previewLogMessage: "Scan selesai. Total junk: 6.4 GB."
        )
    }
}

#Preview("Layout Preview - Light", traits: .sizeThatFitsLayout) {
    ContentView.previewContent
        .preferredColorScheme(.light)
}

#Preview("Layout Preview - Dark", traits: .sizeThatFitsLayout) {
    ContentView.previewContent
        .preferredColorScheme(.dark)
}

#Preview("Layout Preview", traits: .sizeThatFitsLayout) {
    ContentView.previewContent
}
