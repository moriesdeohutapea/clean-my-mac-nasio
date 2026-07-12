//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import SwiftUI

struct DashboardHeader: View {
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
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 14) {
                    titleSection
                    actionButtons

                    if isScanning {
                        scanProgress
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    titleSection

                    Spacer()

                    actionButtons

                    if isScanning {
                        scanProgress
                            .frame(width: DashboardLayout.scanProgressWidth, alignment: .trailing)
                    }
                }
            }
        }
        .padding(isCompact ? DashboardLayout.compactHeaderPadding : DashboardLayout.regularHeaderPadding)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("CleanMacNasio")
                    .font(.system(
                        size: isCompact ? DashboardLayout.compactHeaderTitleSize : DashboardLayout.regularHeaderTitleSize,
                        weight: .bold,
                        design: .rounded
                    ))
                StatusPill(text: statusText, isBusy: isBusy)
            }

            Text(homePath ?? "Press Scan to check safe log and cache locations in Home directory.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DashboardStyle.mutedText)
                .lineLimit(2)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button("Scan", action: onScan)
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(!canScan)

            if isScanning {
                Button("Stop", action: onStopScan)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
            }
        }
    }

    private var scanProgress: some View {
        VStack(alignment: isCompact ? .leading : .trailing, spacing: 6) {
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
        .frame(maxWidth: isCompact ? .infinity : nil, alignment: isCompact ? .leading : .trailing)
    }
}

struct StatusPill: View {
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

struct MetricTile: View {
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

struct SectionTitle: View {
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

struct EmptyScanState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No scan result yet")
                .font(.headline)
            Text("Press Scan to check safe log and cache locations, then review detected items.")
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

struct JunkLocationCard: View {
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

struct SelectionActionPanel: View {
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

struct ExcludedPathsPanel: View {
    let excludedPaths: [String]
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        PathManagementPanel(
            paths: excludedPaths,
            addButtonTitle: "Add Exclude Path",
            emptyMessage: "No protected path yet.",
            note: nil,
            onAdd: onAdd,
            onRemove: onRemove
        )
    }
}

struct CustomCleanupTargetsPanel: View {
    let targetPaths: [String]
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        PathManagementPanel(
            paths: targetPaths,
            addButtonTitle: "Add Custom Folder",
            emptyMessage: "No custom folder yet.",
            note: "Custom targets are never selected automatically.",
            onAdd: onAdd,
            onRemove: onRemove
        )
    }
}

struct AppCacheRecommendationsPanel: View {
    let recommendations: [JunkCleanerService.AppCacheRecommendation]
    let customTargetPaths: [String]
    let onAdd: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if recommendations.isEmpty {
                Text("Tidak ada rekomendasi cache yang terdeteksi.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(recommendations) { recommendation in
                        RecommendationCard(
                            recommendation: recommendation,
                            isDisabled: recommendation.directoryURLs.allSatisfy {
                                customTargetPaths.contains(JunkCleanerService.normalizePath($0.path))
                            },
                            customTargetPaths: customTargetPaths,
                            onAdd: onAdd
                        )
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

private struct RecommendationCard: View {
    let recommendation: JunkCleanerService.AppCacheRecommendation
    let isDisabled: Bool
    let customTargetPaths: [String]
    let onAdd: ([URL]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.appName)
                        .font(.system(size: 14, weight: .bold))
                    Text("\(recommendation.directoryURLs.count) folder • \(recommendation.formattedSizeText) • \(recommendation.fileCount) files")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DashboardStyle.mutedText)
                }

                Spacer()

                Button(isDisabled ? "Sudah ada" : "Tambah Semua", action: addAllDirectories)
                    .controlSize(.small)
                    .disabled(isDisabled)
            }

            if let note = recommendation.note {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
            }

            ForEach(recommendation.directoryURLs, id: \.path) { directory in
                HStack(spacing: 8) {
                    Text(directory.path)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(DashboardStyle.mutedText)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Tambah") {
                        onAdd([directory])
                    }
                    .controlSize(.small)
                    .disabled(customTargetPaths.contains(JunkCleanerService.normalizePath(directory.path)))
                }
                .padding(10)
                .background(DashboardStyle.recessedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(12)
        .background(DashboardStyle.recessedPanel, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func addAllDirectories() {
        onAdd(recommendation.directoryURLs)
    }
}

private struct PathManagementPanel: View {
    let paths: [String]
    let addButtonTitle: String
    let emptyMessage: String
    let note: String?
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(addButtonTitle, action: onAdd)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
            }

            if paths.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DashboardStyle.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(paths, id: \.self) { path in
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

struct StatusPanel: View {
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
