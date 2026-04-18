import SwiftUI

private enum AppMetadata {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
}

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

struct AboutAppPanel: View {
    @State private var showDetail = false

    private let supportedTargets: [String] = [
        "Library Caches",
        "Library Logs",
        "Temporary Directory",
        "Android Studio Caches",
        "Gradle Caches (per version + wrapper)",
        "Flutter/Dart Caches",
        "Homebrew Caches",
        "Trash"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About CleanMacNasio")
                .font(.system(size: 14, weight: .semibold))

            aboutRow(label: "App", value: "CleanMacNasio")
            aboutRow(label: "Version", value: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))")

            Button("Show Full About") {
                showDetail = true
            }
            .controlSize(.small)
        }
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
        .sheet(isPresented: $showDetail) {
            AboutDetailView(
                versionText: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))",
                supportedTargets: supportedTargets
            )
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DashboardStyle.mutedText)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutDetailView: View {
    let versionText: String
    let supportedTargets: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About CleanMacNasio")
                .font(.title3)
                .fontWeight(.bold)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("App Information")
                    detailText("Name: CleanMacNasio")
                    detailText("Version: \(versionText)")
                    detailText("Scan Mode: Auto-scan lokasi cache umum saat tombol Scan ditekan.")
                    detailText("Delete Mode: Hanya item yang dipilih user.")

                    sectionTitle("Supported Clean Targets")
                    ForEach(supportedTargets, id: \.self) { target in
                        detailText("• \(target)")
                    }

                    sectionTitle("Safety Rules")
                    detailText("Excluded path tidak akan dihapus.")
                    detailText("Proteksi default aktif untuk: .ssh, Keychains, Provisioning Profiles, .git, ekstensi sensitif (jks, keystore, p12, cer, pem, key, mobileprovision, db, sqlite, sqlite3).")

                    sectionTitle("Workflow")
                    detailText("1. Tekan Scan untuk deteksi multi-path cache umum.")
                    detailText("2. Pilih target yang ingin dibersihkan.")
                    detailText("3. Tekan Clean Selected untuk hapus item terpilih.")
                    detailText("4. Pantau progress scan dan delete pada status panel.")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520, alignment: .topLeading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DashboardStyle.mutedText)
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
    }
}
