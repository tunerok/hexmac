//
//  WorkspaceView.swift
//  ediHex
//

import SwiftUI

struct WorkspaceView: View {
    @Bindable var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            editorArea

            Divider()

            statusBar
        }
        .sheet(isPresented: activePaneBinding(\.showFindSheet)) {
            if let pane = workspace.activePane {
                FindPanelView(pane: pane) {
                    pane.closeFindSheet()
                }
            }
        }
        .sheet(isPresented: activePaneBinding(\.showBinarySheet)) {
            if let pane = workspace.activePane {
                BinarySelectionView(
                    selectionStart: pane.binarySelectionStart,
                    selectionEnd: pane.binarySelectionEnd,
                    byteCount: pane.binarySelectionByteCount,
                    bytesProvider: { range in
                        pane.bytes(in: range)
                    }
                ) {
                    pane.showBinarySheet = false
                }
            }
        }
        .sheet(isPresented: activePaneBinding(\.showCRCSheet)) {
            if let pane = workspace.activePane {
                CRCCalculatorView(inputBytes: pane.crcInputBytes) {
                    pane.showCRCSheet = false
                }
            }
        }
        .sheet(isPresented: activePaneBinding(\.showHistogramSheet)) {
            if let pane = workspace.activePane {
                HistogramView(
                    fileName: pane.histogramFileName,
                    title: pane.histogramTitle,
                    byteCount: pane.histogramByteCount,
                    counts: pane.histogramCounts,
                    isLoading: pane.isHistogramLoading,
                    progress: pane.histogramProgress,
                    uniqueValueCount: pane.histogramUniqueValueCount,
                    topEntries: pane.histogramTopEntries
                ) {
                    pane.showHistogramSheet = false
                }
            }
        }
        .sheet(isPresented: activePaneBinding(\.showHashSheet)) {
            if let pane = workspace.activePane {
                HashCalculatorView(
                    fileName: pane.hashFileName,
                    title: pane.hashTitle,
                    inputBytes: pane.hashInputBytes,
                    inputRange: pane.hashInputRange,
                    bytesProvider: { range in pane.bytes(in: range) }
                ) {
                    pane.showHashSheet = false
                }
            }
        }
        .sheet(isPresented: $workspace.showComparePicker) {
            CompareFilePickerView(
                workspace: workspace,
                panes: workspace.openDocumentPanes(),
                presetLeftPaneID: workspace.comparePickerPresetLeftPaneID
            )
        }
        .confirmationDialog(
            String(localized: "Fill selection with"),
            isPresented: activePaneBinding(\.showFillDialog),
            titleVisibility: .visible
        ) {
            Button("0x00") {
                workspace.activePane?.fillSelection(with: 0x00)
            }
            Button("0xFF") {
                workspace.activePane?.fillSelection(with: 0xFF)
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            String(localized: "Save changes to “\(workspace.pendingClosePaneTitle())”?"),
            isPresented: $workspace.showClosePaneConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Save")) {
                workspace.confirmClosePane(save: true)
            }
            Button(String(localized: "Don't Save"), role: .destructive) {
                workspace.confirmClosePane(save: false)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                workspace.cancelClosePane()
            }
        }
        .confirmationDialog(
            String(localized: "Close tabs?"),
            isPresented: $workspace.showClosePanesConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Save All")) {
                workspace.confirmClosePanes(save: true)
            }
            Button(String(localized: "Don't Save"), role: .destructive) {
                workspace.confirmClosePanes(save: false)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                workspace.cancelClosePanes()
            }
        } message: {
            Text("Unsaved changes will be lost.")
        }
        .confirmationDialog(
            String(localized: "Close editor group?"),
            isPresented: $workspace.showCloseGroupConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Save All")) {
                workspace.confirmCloseGroup(save: true)
            }
            Button(String(localized: "Don't Save"), role: .destructive) {
                workspace.confirmCloseGroup(save: false)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                workspace.cancelCloseGroup()
            }
        } message: {
            Text("Unsaved changes will be lost.")
        }
        .alert(
            String(localized: "Error"),
            isPresented: activePaneErrorBinding
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(workspace.activePane?.errorMessage ?? workspace.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var editorArea: some View {
        if let rootGroup = workspace.rootGroup {
            HSplitView {
                VSplitView {
                    EditorGroupView(workspace: workspace, node: rootGroup)
                        .frame(minWidth: 400, minHeight: 200)
                        .layoutPriority(1)

                    Group {
                        if let pane = workspace.activePane {
                            TerminalPanelView(pane: pane)
                        } else {
                            TerminalPanelView(pane: nil)
                        }
                    }
                    .frame(minHeight: 72, idealHeight: 92, maxHeight: 320)
                    .layoutPriority(0)
                }
                .layoutPriority(1)

                if let pane = workspace.activePane, pane.isComparisonPane {
                    InspectorPanelView(
                        selection: nil,
                        bytes: [],
                        selectedOffset: pane.comparisonCurrentDiffOffset,
                        highlights: [],
                        findSession: nil,
                        compareState: CompareInspectorState(
                            leftName: pane.comparisonLeftName,
                            rightName: pane.comparisonRightName,
                            isLoading: pane.isDiffMapLoading,
                            progress: pane.isDiffMapLoading ? pane.diffMapProgress : nil,
                            diffCount: pane.comparisonDiffCount,
                            currentDiffOffset: pane.comparisonCurrentDiffOffset,
                            canNavigatePrevious: pane.canNavigatePreviousDiff,
                            canNavigateNext: pane.canNavigateNextDiff,
                            onNavigatePrevious: { _ = pane.navigateToPreviousDiff() },
                            onNavigateNext: { _ = pane.navigateToNextDiff() }
                        ),
                        canFindPrevious: false,
                        canFindNext: false,
                        onAddHighlight: { _ in },
                        onRemoveHighlight: { _ in },
                        onNavigateToHighlight: { _ in },
                        onFindPrevious: {},
                        onFindNext: {},
                        onClearFind: {}
                    )
                    .layoutPriority(0)
                } else if let pane = workspace.activePane {
                    InspectorPanelView(
                        selection: pane.selection,
                        bytes: inspectorBytes(for: pane),
                        selectedOffset: pane.selectedOffset,
                        highlights: pane.highlights,
                        findSession: pane.findSession,
                        compareState: nil,
                        canFindPrevious: pane.canFindPrevious,
                        canFindNext: pane.canFindNext,
                        onAddHighlight: { color in
                            pane.addHighlight(color: color)
                        },
                        onRemoveHighlight: { id in
                            pane.removeHighlight(id: id)
                        },
                        onNavigateToHighlight: { highlight in
                            pane.navigateToHighlight(highlight)
                        },
                        onFindPrevious: { _ = pane.findPreviousMatch() },
                        onFindNext: { _ = pane.findNextMatch() },
                        onClearFind: { pane.clearFindResults() }
                    )
                    .layoutPriority(0)
                } else {
                    InspectorPanelView(
                        selection: nil,
                        bytes: [],
                        selectedOffset: nil,
                        highlights: [],
                        findSession: nil,
                        compareState: nil,
                        canFindPrevious: false,
                        canFindNext: false,
                        onAddHighlight: { _ in },
                        onRemoveHighlight: { _ in },
                        onNavigateToHighlight: { _ in },
                        onFindPrevious: {},
                        onFindNext: {},
                        onClearFind: {}
                    )
                    .layoutPriority(0)
                }
            }
        }
    }

    private var statusBar: some View {
        Group {
            if let pane = workspace.activePane {
                StatusBarView(
                    selectedOffset: pane.selectedOffset,
                    fileSize: pane.fileSize,
                    textEncoding: Binding(
                        get: { pane.textEncoding },
                        set: { pane.textEncoding = $0 }
                    ),
                    bytesPerRow: Binding(
                        get: { pane.bytesPerRow },
                        set: { pane.setBytesPerRow($0) }
                    )
                )
            } else {
                StatusBarView(
                    selectedOffset: nil,
                    fileSize: 0,
                    textEncoding: .constant(.ascii),
                    bytesPerRow: .constant(.sixteen)
                )
            }
        }
    }

    private func inspectorBytes(for pane: DocumentPaneViewModel) -> [UInt8] {
        guard let selection = pane.selection else { return [] }
        return pane.bytes(in: selection.start..<(selection.end + 1))
    }

    private func activePaneBinding(_ keyPath: ReferenceWritableKeyPath<DocumentPaneViewModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { workspace.activePane?[keyPath: keyPath] ?? false },
            set: { newValue in
                workspace.activePane?[keyPath: keyPath] = newValue
            }
        )
    }

    private var activePaneErrorBinding: Binding<Bool> {
        Binding(
            get: {
                workspace.activePane?.showError ?? workspace.showError
            },
            set: { newValue in
                if let pane = workspace.activePane {
                    pane.showError = newValue
                } else {
                    workspace.showError = newValue
                }
            }
        )
    }
}
