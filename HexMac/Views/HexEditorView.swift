//
//  HexEditorView.swift
//  HexMac
//

import SwiftUI

struct HexEditorView: View {
    @Bindable var viewModel: HexEditorViewModel
    @FocusState private var focusedEditOffset: Int?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rowCount == 0 {
                ContentUnavailableView(
                    String(localized: "Empty File"),
                    systemImage: "doc",
                    description: Text("This file contains no data")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VSplitView {
                    HSplitView {
                        hexGrid
                            .frame(minWidth: 400)
                            .layoutPriority(1)

                        InspectorPanelView(
                            selection: viewModel.selection,
                            bytes: inspectorBytes,
                            selectedOffset: viewModel.selectedOffset,
                            highlights: viewModel.highlights,
                            onAddHighlight: { color in
                                viewModel.addHighlight(color: color)
                            },
                            onRemoveHighlight: { id in
                                viewModel.removeHighlight(id: id)
                            },
                            onNavigateToHighlight: { highlight in
                                viewModel.navigateToHighlight(highlight)
                            }
                        )
                        .layoutPriority(0)
                    }

                    TerminalPanelView(viewModel: viewModel)
                        .layoutPriority(0)
                }
            }

            Divider()

            StatusBarView(
                selectedOffset: viewModel.selectedOffset,
                fileSize: viewModel.fileSize,
                textEncoding: Binding(
                    get: { viewModel.textEncoding },
                    set: { viewModel.textEncoding = $0 }
                ),
                bytesPerRow: Binding(
                    get: { viewModel.bytesPerRow },
                    set: { viewModel.setBytesPerRow($0) }
                )
            )
        }
        .sheet(isPresented: $viewModel.showCRCSheet) {
            CRCCalculatorView(inputBytes: viewModel.crcInputBytes) {
                viewModel.showCRCSheet = false
            }
        }
        .confirmationDialog(
            String(localized: "Fill selection with"),
            isPresented: $viewModel.showFillDialog,
            titleVisibility: .visible
        ) {
            Button("0x00") {
                viewModel.fillSelection(with: 0x00)
            }
            Button("0xFF") {
                viewModel.fillSelection(with: 0xFF)
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .onChange(of: viewModel.editingOffset) { _, newValue in
            focusedEditOffset = newValue
        }
        .onChange(of: focusedEditOffset) { oldValue, newValue in
            guard oldValue != nil, newValue == nil, viewModel.editingOffset != nil else { return }
            finishEditing()
        }
    }

    private var hexGrid: some View {
        HexGridView(
            rowCount: viewModel.rowCount,
            fileSize: viewModel.fileSize,
            bytesPerRow: viewModel.bytesPerRow.rawValue,
            dataRevision: viewModel.dataRevision,
            selection: viewModel.selection,
            editingOffset: viewModel.editingOffset,
            scrollTargetOffset: viewModel.scrollTargetOffset,
            editingHexText: Binding(
                get: { viewModel.editingHexText },
                set: { newValue in
                    let filtered = newValue.uppercased().filter(\.isHexDigit)
                    viewModel.editingHexText = String(filtered.prefix(2))
                }
            ),
            focusedEditOffset: $focusedEditOffset,
            textEncoding: viewModel.textEncoding,
            highlightColor: { viewModel.highlight(at: $0) },
            rowBytes: { viewModel.rowBytes(for: $0) },
            onFinishEditing: finishEditing,
            onBeginSelection: { offset, extending in
                viewModel.beginSelection(at: offset, extending: extending)
            },
            onUpdateSelection: { offset in
                viewModel.updateSelection(to: offset)
            },
            onEndSelection: { offset in
                viewModel.endSelection(at: offset)
            },
            onBeginEdit: { offset in
                viewModel.beginEditing(at: offset)
                focusedEditOffset = offset
            },
            onCommitEdit: {
                if viewModel.commitEditing() {
                    advanceAfterEdit()
                }
            },
            onCancelEdit: {
                viewModel.cancelEditing()
                focusedEditOffset = nil
            },
            onAddHighlight: { color in
                viewModel.addHighlight(color: color)
            },
            onRemoveHighlight: { offset in
                viewModel.removeHighlights(containing: offset)
            },
            onCopySelection: {
                viewModel.copySelectionHex()
            },
            onClearSelection: {
                viewModel.requestFillSelection()
            },
            onCalculateCRC: {
                viewModel.openCRCSheet()
            },
            onScrollTargetHandled: {
                viewModel.clearScrollTarget()
            }
        )
    }

    private func finishEditing() {
        guard viewModel.editingOffset != nil else { return }
        if !viewModel.commitEditing() {
            viewModel.cancelEditing()
        }
        focusedEditOffset = nil
    }

    private var inspectorBytes: [UInt8] {
        guard let selection = viewModel.selection else { return [] }
        return viewModel.bytes(in: selection.start..<(selection.end + 1))
    }

    private func advanceAfterEdit() {
        guard let offset = viewModel.selectedOffset,
              offset + 1 < viewModel.fileSize else {
            focusedEditOffset = nil
            return
        }
        viewModel.beginEditing(at: offset + 1)
        focusedEditOffset = offset + 1
    }
}
