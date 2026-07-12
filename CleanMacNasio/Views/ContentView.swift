//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
    }

    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel())
    }

    init(
        previewHomeDirectoryURL: URL?,
        previewScanEntries: [JunkScanEntry],
        previewExcludedPaths: [String],
        previewLogMessage: String,
        previewSelectedEntryIDs: Set<String> = [],
        previewIsScanning: Bool = false,
        previewIsCleaning: Bool = false,
        previewScanProgressMessage: String = "",
        previewScanProgressDetail: String = "",
        previewScanProgressFraction: Double = 0,
        previewCleanProgressMessage: String = "",
        previewCleanProgressDetail: String = "",
        previewCleanProgressFraction: Double = 0
    ) {
        let previewViewModel = ContentViewModel(
                homeDirectoryURL: previewHomeDirectoryURL,
                scanEntries: previewScanEntries,
                selectedEntryIDs: previewSelectedEntryIDs,
                excludedPaths: previewExcludedPaths,
                logMessage: previewLogMessage,
                scanProgressMessage: previewScanProgressMessage,
                scanProgressDetail: previewScanProgressDetail,
                scanProgressFraction: previewScanProgressFraction,
                cleanProgressMessage: previewCleanProgressMessage,
                cleanProgressDetail: previewCleanProgressDetail,
                cleanProgressFraction: previewCleanProgressFraction
            )
        previewViewModel.isScanning = previewIsScanning
        previewViewModel.isCleaning = previewIsCleaning
        _viewModel = StateObject(wrappedValue: previewViewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < DashboardLayout.compactWidth

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
                    dashboardContent(isCompact: isCompact)
                        .padding(isCompact ? DashboardLayout.compactPadding : DashboardLayout.regularPadding)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .foregroundColor(DashboardStyle.text)
        .frame(
            minWidth: DashboardLayout.minimumWindowWidth,
            minHeight: DashboardLayout.minimumWindowHeight
        )
        .onAppear {
            guard !isRunningInPreview else { return }
            viewModel.restoreSavedState()
        }
        .alert("Konfirmasi Hapus Xcode Archives", isPresented: $viewModel.showArchiveCleanConfirmation) {
            Button("Batal", role: .cancel) {
                viewModel.cancelCleanSelectedIncludingArchives()
            }
            Button("Lanjut Hapus", role: .destructive) {
                viewModel.confirmCleanSelectedIncludingArchives()
            }
        } message: {
            Text("Xcode Archives biasanya berisi arsip build release. Pastikan kamu memang ingin menghapus item ini.")
        }
        .alert("Konfirmasi Hapus Custom Target", isPresented: $viewModel.showCustomTargetCleanConfirmation) {
            Button("Batal", role: .cancel) {
                viewModel.cancelCleanSelectedIncludingCustomTargets()
            }
            Button("Lanjut Hapus", role: .destructive) {
                viewModel.confirmCleanSelectedIncludingCustomTargets()
            }
        } message: {
            Text("Isi folder custom yang dipilih akan dihapus. Folder induknya tetap ada.")
        }
    }

    private func dashboardContent(isCompact: Bool) -> some View {
        VStack(
            alignment: .leading,
            spacing: isCompact ? DashboardLayout.compactSpacing : DashboardLayout.regularSpacing
        ) {
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
                canScan: viewModel.canScan,
                isCompact: isCompact
            )

            metricTiles(isCompact: isCompact)

            if isCompact {
                VStack(alignment: .leading, spacing: DashboardLayout.compactSpacing) {
                    cleanTargetsSection
                    actionSidebar
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    cleanTargetsSection
                    actionSidebar
                        .frame(width: DashboardLayout.sidebarWidth, alignment: .topLeading)
                }
            }
        }
    }

    private func metricTiles(isCompact: Bool) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: DashboardLayout.metricSpacing),
                count: isCompact ? 2 : 3
            ),
            spacing: DashboardLayout.metricSpacing
        ) {
            MetricTile(
                title: "Ready To Clean",
                value: FileUtils.formatBytes(viewModel.selectedTotalSize),
                caption: "\(viewModel.selectedCategoryCount) categories"
            )
            MetricTile(
                title: "Detected",
                value: FileUtils.formatBytes(viewModel.totalScanSize),
                caption: "\(viewModel.totalFileCount) files"
            )
            MetricTile(
                title: "Excluded",
                value: "\(viewModel.excludedPaths.count)",
                caption: "protected paths"
            )
        }
    }

    private var cleanTargetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "Clean Targets",
                subtitle: "Auto-scanned from safe log and cache locations"
            )

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
    }

    private var actionSidebar: some View {
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

            SectionTitle(title: "Custom Targets", subtitle: "Folder manual tidak dipilih otomatis")

            CustomCleanupTargetsPanel(
                targetPaths: viewModel.customTargetPaths,
                onAdd: pickCustomTarget,
                onRemove: viewModel.removeCustomTarget
            )

            SectionTitle(title: "Rekomendasi Cache Aplikasi", subtitle: "Folder cache aplikasi terdeteksi untuk kamu tambahkan.")

            AppCacheRecommendationsPanel(
                recommendations: viewModel.detectedAppCacheRecommendations,
                customTargetPaths: viewModel.customTargetPaths,
                onAdd: viewModel.addRecommendedCacheDirectories
            )

            SectionTitle(title: "Protection", subtitle: "Excluded paths stay untouched")

            ExcludedPathsPanel(
                excludedPaths: viewModel.excludedPaths,
                onAdd: pickExcludePath,
                onRemove: viewModel.removeExcludedPath
            )

            SectionTitle(title: "About", subtitle: "Informasi aplikasi")

            AboutAppPanel()

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
        .frame(maxWidth: .infinity, alignment: .topLeading)
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

    private func pickCustomTarget() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = viewModel.homeDirectoryURL
        panel.message = "Pilih folder cache atau log yang aman dibersihkan"
        panel.prompt = "Add Target"

        if panel.runModal() == .OK, let pickedURL = panel.url {
            viewModel.addCustomTarget(pickedURL)
        }
    }
}
