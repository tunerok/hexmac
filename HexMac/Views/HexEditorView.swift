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
                HSplitView {
                    HexGridView(
                        rowCount: viewModel.rowCount,
                        fileSize: viewModel.fileSize,
                        bytesPerRow: viewModel.bytesPerRow.rawValue,
                        dataRevision: viewModel.dataRevision,
                        selection: viewModel.selection,
                        editingOffset: viewModel.editingOffset,
                        editingHexText: Binding(
                            get: { viewModel.editingHexText },
                            set: { newValue in
                                let filtered = newValue.uppercased().filter(\.isHexDigit)
                                viewModel.editingHexText = String(filtered.prefix(2))
                            }
                        ),
                        focusedEditOffset: $focusedEditOffset,
                        textEncoding: viewModel.textEncoding,
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
                        }
                    )
                    .frame(minWidth: 400)
                    .layoutPriority(1)

                    InspectorPanelView(
                        selection: viewModel.selection,
                        bytes: inspectorBytes,
                        selectedOffset: viewModel.selectedOffset
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
        .onChange(of: viewModel.editingOffset) { _, newValue in
            focusedEditOffset = newValue
        }
        .onChange(of: focusedEditOffset) { oldValue, newValue in
            guard oldValue != nil, newValue == nil, viewModel.editingOffset != nil else { return }
            finishEditing()
        }
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
