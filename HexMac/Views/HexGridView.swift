//
//  HexGridView.swift
//  HexMac
//

import SwiftUI

struct HexGridView: View {
    let rowCount: Int
    let fileSize: Int
    let bytesPerRow: Int
    let dataRevision: Int
    let selection: HexSelection?
    let editingOffset: Int?
    @Binding var editingHexText: String
    var focusedEditOffset: FocusState<Int?>.Binding
    let textEncoding: TextEncodingMode
    let rowBytes: (Int) -> [UInt8]
    let onFinishEditing: () -> Void
    let onBeginSelection: (Int, Bool) -> Void
    let onUpdateSelection: (Int) -> Void
    let onEndSelection: (Int) -> Void
    let onBeginEdit: (Int) -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerRow

                Divider()

                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    HexRowView(
                        rowIndex: rowIndex,
                        bytes: rowBytes(rowIndex),
                        fileSize: fileSize,
                        bytesPerRow: bytesPerRow,
                        selection: selection,
                        editingOffset: editingOffset,
                        editingHexText: $editingHexText,
                        focusedEditOffset: focusedEditOffset,
                        textEncoding: textEncoding,
                        onCommitEdit: onCommitEdit,
                        onCancelEdit: onCancelEdit
                    )
                    .id("\(rowIndex)-\(dataRevision)")
                }
            }
            .padding(HexGridLayout.contentPadding)
            .overlay {
                HexSelectionHandlingView(
                    rowCount: rowCount,
                    fileSize: fileSize,
                    bytesPerRow: bytesPerRow,
                    editingOffset: editingOffset,
                    onFinishEditing: onFinishEditing,
                    onBeginSelection: onBeginSelection,
                    onUpdateSelection: onUpdateSelection,
                    onEndSelection: onEndSelection,
                    onBeginEdit: onBeginEdit
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text(String(localized: "Offset"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: HexGridLayout.offsetColumnWidth, alignment: .leading)

            Text(String(localized: "Hex"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: HexFormatter.hexColumnWidth(for: bytesPerRow), alignment: .leading)
                .padding(.leading, HexGridLayout.hexColumnLeadingPadding)

            Divider()
                .padding(.horizontal, HexGridLayout.dividerHorizontalPadding)

            Text(String(localized: "Text"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)
        }
        .frame(height: HexGridLayout.headerContentHeight, alignment: .leading)
        .padding(.bottom, HexGridLayout.headerBottomPadding)
    }
}
