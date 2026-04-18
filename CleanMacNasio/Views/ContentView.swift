//
//  ContentView.swift
//  CleanMacNasio
//
//  Created by Mories Hutapea on 19/07/25.
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

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(
                            title: "Clean Targets",
                            subtitle: "Auto-scanned from common cache locations"
                        )

                        if viewModel.scanEntries.isEmpty {
                            EmptyScanState()
                        } else {
                            ScrollView {
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
