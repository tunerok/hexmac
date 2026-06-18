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
                            editingHexText: editingHexText,
                            highlightColor: highlightColor(offset)
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
                        highlightColor: highlightColor(offset)
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
        switch textEncoding {
        case .ascii:
            bytes.map { HexFormatter.asciiCharacter(for: $0) }
        case .utf8:
            utf8CharactersAligned(to: bytes)
        }
    }

    private func utf8CharactersAligned(to bytes: [UInt8]) -> [Character] {
        var result = Array(repeating: Character(" "), count: bytes.count)
        var byteIndex = 0
        let string = HexFormatter.utf8String(for: bytes)
        for character in string {
            guard byteIndex < bytes.count else { break }
            result[byteIndex] = character
            byteIndex += character.utf8.count
        }
        return result
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
