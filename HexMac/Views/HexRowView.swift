//
//  HexRowView.swift
//  HexMac
//

import SwiftUI

struct HexRowView: View, Equatable {
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

    static func == (lhs: HexRowView, rhs: HexRowView) -> Bool {
        lhs.rowIndex == rhs.rowIndex
            && lhs.bytes == rhs.bytes
            && lhs.fileSize == rhs.fileSize
            && lhs.bytesPerRow == rhs.bytesPerRow
            && lhs.selection == rhs.selection
            && lhs.editingOffset == rhs.editingOffset
            && lhs.editingHexText == rhs.editingHexText
            && lhs.textEncoding == rhs.textEncoding
            && lhs.columnHighlights == rhs.columnHighlights
    }

    private var rowOffset: Int {
        HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
    }

    private var rowEndOffset: Int {
        min(fileSize - 1, rowOffset + bytesPerRow - 1)
    }

    private var usesDetailedCells: Bool {
        if columnHighlights != nil { return true }
        if let editingOffset, editingOffset >= rowOffset, editingOffset <= rowEndOffset {
            return true
        }
        if let selection, selection.end >= rowOffset, selection.start <= rowEndOffset {
            return true
        }
        for column in 0..<bytes.count {
            if highlightColor(rowOffset + column) != nil {
                return true
            }
        }
        return false
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

            if usesDetailedCells {
                detailedHexColumn
            } else {
                compactHexColumn
            }

            Divider()
                .padding(.horizontal, HexGridLayout.dividerHorizontalPadding)

            if usesDetailedCells {
                detailedTextColumn
            } else {
                compactTextColumn
            }
        }
        .frame(height: HexGridLayout.rowHeight, alignment: .leading)
    }

    private var compactHexColumn: some View {
        Text(compactHexLine)
            .font(.body.monospaced())
            .frame(width: HexFormatter.hexColumnWidth(for: bytesPerRow), alignment: .leading)
            .padding(.leading, HexGridLayout.hexColumnLeadingPadding)
    }

    private var compactTextColumn: some View {
        Text(compactTextLine)
            .font(.body.monospaced())
            .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)
            .lineLimit(1)
    }

    private var detailedHexColumn: some View {
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
    }

    private var detailedTextColumn: some View {
        HStack(spacing: 0) {
            ForEach(0..<bytesPerRow, id: \.self) { column in
                let offset = rowOffset + column
                if offset < fileSize, column < bytes.count {
                    TextCharacterCellView(
                        character: textCharacters[column],
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
        .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)
    }

    private var compactHexLine: String {
        var parts: [String] = []
        parts.reserveCapacity(bytesPerRow)
        for column in 0..<bytesPerRow {
            let offset = rowOffset + column
            if offset < fileSize, column < bytes.count {
                parts.append(HexFormatter.hexPair(for: bytes[column]))
            } else {
                parts.append("  ")
            }
        }
        return parts.joined(separator: " ")
    }

    private var compactTextLine: String {
        let characters = bytes.isEmpty ? [] : textCharacters
        var line = ""
        line.reserveCapacity(bytesPerRow)
        for column in 0..<bytesPerRow {
            let offset = rowOffset + column
            if offset < fileSize, column < characters.count {
                line.append(characters[column])
            } else {
                line.append(" ")
            }
        }
        return line
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
