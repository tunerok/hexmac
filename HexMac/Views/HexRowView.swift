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
    let editingHexText: String
    let textEncoding: TextEncodingMode
    let highlightColor: (Int) -> HighlightColor?
    let columnHighlights: [HighlightColor?]?

    init(
        rowIndex: Int,
        bytes: [UInt8],
        fileSize: Int,
        bytesPerRow: Int,
        selection: HexSelection?,
        editingOffset: Int?,
        editingHexText: String,
        textEncoding: TextEncodingMode,
        highlightColor: @escaping (Int) -> HighlightColor?,
        columnHighlights: [HighlightColor?]? = nil
    ) {
        self.rowIndex = rowIndex
        self.bytes = bytes
        self.fileSize = fileSize
        self.bytesPerRow = bytesPerRow
        self.selection = selection
        self.editingOffset = editingOffset
        self.editingHexText = editingHexText
        self.textEncoding = textEncoding
        self.highlightColor = highlightColor
        self.columnHighlights = columnHighlights
    }

    private var rowOffset: Int {
        HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
    }

    private func highlightForColumn(_ column: Int, offset: Int) -> HighlightColor? {
        if let columnHighlights, column < columnHighlights.count {
            return columnHighlights[column]
        }
        return highlightColor(offset)
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
                            editingHexText: editingHexText,
                            highlightColor: highlightForColumn(column, offset: offset)
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

            textColumnView
                .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)
        }
        .frame(height: HexGridLayout.rowHeight, alignment: .leading)
    }

    private var textColumnView: some View {
        HStack(spacing: 0) {
            ForEach(0..<bytesPerRow, id: \.self) { column in
                let offset = rowOffset + column
                if offset < fileSize, column < bytes.count {
                    TextCharacterCellView(
                        character: textCharacter(at: column),
                        isSelected: selection?.contains(offset) ?? false,
                        highlightColor: highlightForColumn(column, offset: offset)
                    )
                } else if column < bytesPerRow {
                    Text(" ")
                        .font(.body.monospaced())
                        .frame(width: HexGridLayout.textCharacterWidth)
                }
            }
        }
        .lineLimit(1)
    }

    private func textCharacter(at column: Int) -> Character {
        textCharacters[column]
    }

    private var textCharacters: [Character] {
        HexFormatter.alignedTextCharacters(for: bytes, encoding: textEncoding)
    }
}

private struct TextCharacterCellView: View {
    let character: Character
    let isSelected: Bool
    let highlightColor: HighlightColor?

    var body: some View {
        Text(String(character))
            .font(.body.monospaced())
            .frame(width: HexGridLayout.textCharacterWidth)
            .padding(.vertical, 1)
            .background(backgroundColor)
            .cornerRadius(2)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if let highlightColor {
            return highlightColor.color.opacity(0.3)
        }
        return .clear
    }
}
