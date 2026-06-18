//
//  HexEditorView.swift
//  HexMac
//

import SwiftUI

struct HexEditorView: View {
    @Bindable var viewModel: HexEditorViewModel

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
                HSplitView {
                    VSplitView {
                        hexGrid
                            .frame(minWidth: 400, minHeight: 200)
                            .layoutPriority(1)

                        TerminalPanelView(viewModel: viewModel)
                            .frame(minHeight: 72, idealHeight: 92, maxHeight: 320)
                            .layoutPriority(0)
                    }
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
        .sheet(isPresented: $viewModel.showHistogramSheet) {
            HistogramView(
                fileName: viewModel.histogramFileName,
                title: viewModel.histogramTitle,
                byteCount: viewModel.histogramByteCount,
                counts: viewModel.histogramCounts
            ) {
                viewModel.showHistogramSheet = false
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
            editingHexText: viewModel.editingHexText,
            textEncoding: viewModel.textEncoding,
            highlightColor: { viewModel.highlight(at: $0) },
            rowBytes: { viewModel.rowBytes(for: $0) },
            onBeginSelection: { offset, extending in
                viewModel.beginSelection(at: offset, extending: extending)
            },
            onUpdateSelection: { offset in
                viewModel.updateSelection(to: offset)
            },
            onEndSelection: { offset in
                viewModel.endSelection(at: offset)
            },
            onHexDigit: { character in
                viewModel.typeHexDigit(character)
            },
            onBackspace: {
                viewModel.backspaceEditing()
            },
            onCancelEdit: {
                viewModel.cancelEditing()
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

    private var inspectorBytes: [UInt8] {
        guard let selection = viewModel.selection else { return [] }
        return viewModel.bytes(in: selection.start..<(selection.end + 1))
    }
}
