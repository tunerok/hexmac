//
//  HexRowView.swift
//  HexMac
//

import SwiftUI

struct HexRowView: View {
    let rowIndex: Int
    let bytes: [UInt8]
    let fileSize: Int
    let bytesPerRow: Int
    let selection: HexSelection?
    let editingOffset: Int?
    @Binding var editingHexText: String
    var focusedEditOffset: FocusState<Int?>.Binding
    let textEncoding: TextEncodingMode
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void

    private var rowOffset: Int {
        HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(HexFormatter.offsetString(for: rowOffset))
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: HexGridLayout.offsetColumnWidth, alignment: .leading)

            HStack(spacing: HexGridLayout.cellSpacing) {
                ForEach(0..<bytesPerRow, id: \.self) { column in
                    let offset = rowOffset + column
                    if offset < fileSize, column < bytes.count {
                        HexByteCellView(
                            offset: offset,
                            hexText: HexFormatter.hexPair(for: bytes[column]),
                            isSelected: selection?.contains(offset) ?? false,
                            isEditing: editingOffset == offset,
                            editingText: $editingHexText,
                            focusedEditOffset: focusedEditOffset,
                            onCommit: onCommitEdit,
                            onCancel: onCancelEdit
                        )
                    } else if column < bytesPerRow {
                        Text("  ")
                            .font(.body.monospaced())
                            .frame(width: HexGridLayout.cellWidth)
                    }
                }
            }
            .frame(width: HexFormatter.hexColumnWidth(for: bytesPerRow), alignment: .leading)
            .padding(.leading, HexGridLayout.hexColumnLeadingPadding)

            Divider()
                .padding(.horizontal, HexGridLayout.dividerHorizontalPadding)

            Text(textColumn)
                .font(.body.monospaced())
                .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)
                .lineLimit(1)
        }
        .frame(height: HexGridLayout.rowHeight, alignment: .leading)
    }

    private var textColumn: String {
        switch textEncoding {
        case .ascii:
            HexFormatter.asciiString(for: bytes)
        case .utf8:
            HexFormatter.utf8String(for: bytes)
        }
    }
}
