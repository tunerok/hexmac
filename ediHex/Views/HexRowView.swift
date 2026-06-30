//
//  HexRowView.swift
//  ediHex
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
    let userHexSpans: [HexDiffSpan]?
    let diffHexSpans: [HexDiffSpan]?
    let showsOffsetColumn: Bool

    init(
        rowIndex: Int,
        bytes: [UInt8],
        fileSize: Int,
        bytesPerRow: Int,
        selection: HexSelection?,
        editingOffset: Int?,
        editingHexText: String,
        textEncoding: TextEncodingMode,
        userHexSpans: [HexDiffSpan]? = nil,
        diffHexSpans: [HexDiffSpan]? = nil,
        showsOffsetColumn: Bool = true
    ) {
        self.rowIndex = rowIndex
        self.bytes = bytes
        self.fileSize = fileSize
        self.bytesPerRow = bytesPerRow
        self.selection = selection
        self.editingOffset = editingOffset
        self.editingHexText = editingHexText
        self.textEncoding = textEncoding
        self.userHexSpans = userHexSpans
        self.diffHexSpans = diffHexSpans
        self.showsOffsetColumn = showsOffsetColumn
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
            && lhs.userHexSpans == rhs.userHexSpans
            && lhs.diffHexSpans == rhs.diffHexSpans
            && lhs.showsOffsetColumn == rhs.showsOffsetColumn
    }

    private var rowOffset: Int {
        HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
    }

    private var rowEndOffset: Int {
        min(fileSize - 1, rowOffset + bytesPerRow - 1)
    }

    private var hexCanvasSpans: [HexDiffSpan]? {
        let merged = (userHexSpans ?? []) + (diffHexSpans ?? [])
        return merged.isEmpty ? nil : merged
    }

    private var selectionSpans: [HexColumnSpan]? {
        HexSelectionSpans.spans(
            for: rowIndex,
            bytesPerRow: bytesPerRow,
            fileSize: fileSize,
            selection: selection
        )
    }

    private var editingColumn: Int? {
        guard let editingOffset,
              editingOffset >= rowOffset,
              editingOffset <= rowEndOffset else {
            return nil
        }
        return editingOffset - rowOffset
    }

    private var editingHexPair: String? {
        guard let editingColumn, editingColumn < bytes.count else { return nil }
        return HexFormatter.hexPair(for: bytes[editingColumn])
    }

    var body: some View {
        HStack(spacing: 0) {
            if showsOffsetColumn {
                Text(HexFormatter.offsetString(for: rowOffset))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: HexGridLayout.offsetColumnWidth, alignment: .leading)
            }

            hexColumn

            Divider()
                .padding(.horizontal, HexGridLayout.dividerHorizontalPadding)

            textColumn
        }
        .frame(
            width: showsOffsetColumn ? nil : HexGridLayout.hexTextContentWidth(for: bytesPerRow),
            height: HexGridLayout.rowHeight,
            alignment: .leading
        )
    }

    private var hexColumn: some View {
        ZStack(alignment: .leading) {
            Text(compactHexLine)
                .font(.body.monospaced())
                .frame(width: HexFormatter.hexColumnWidth(for: bytesPerRow), alignment: .leading)

            if let hexCanvasSpans {
                HexHighlightCanvasOverlay(spans: hexCanvasSpans, bytesPerRow: bytesPerRow)
            }

            if let selectionSpans {
                HexSelectionCanvasOverlay(
                    spans: selectionSpans,
                    column: .hex,
                    bytesPerRow: bytesPerRow
                )
            }

            if let editingColumn, let editingHexPair {
                HexEditingCellOverlay(
                    column: editingColumn,
                    hexText: editingHexPair,
                    editingHexText: editingHexText,
                    bytesPerRow: bytesPerRow
                )
            }
        }
        .padding(.leading, HexGridLayout.hexColumnLeadingPadding)
    }

    private var textColumn: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { column in
                    Text(String(textCharacter(at: column)))
                        .font(.body.monospaced())
                        .frame(width: HexGridLayout.textCharacterWidth, alignment: .leading)
                }
            }
            .frame(width: HexFormatter.textColumnWidth(for: bytesPerRow), alignment: .leading)

            if let selectionSpans {
                HexSelectionCanvasOverlay(
                    spans: selectionSpans,
                    column: .text,
                    bytesPerRow: bytesPerRow
                )
            }
        }
        .clipped()
    }

    private var compactHexLine: String {
        var parts: [String] = []
        parts.reserveCapacity(bytesPerRow)
        for column in 0..<bytesPerRow {
            let offset = rowOffset + column
            if offset < fileSize, column < bytes.count {
                if column == editingColumn {
                    parts.append("  ")
                } else {
                    parts.append(HexFormatter.hexPair(for: bytes[column]))
                }
            } else {
                parts.append("  ")
            }
        }
        return parts.joined(separator: " ")
    }

    private var textCharacters: [Character] {
        HexFormatter.alignedTextCharacters(for: bytes, encoding: textEncoding)
    }

    private func textCharacter(at column: Int) -> Character {
        let offset = rowOffset + column
        guard offset < fileSize else { return " " }
        let characters = bytes.isEmpty ? [] : textCharacters
        guard column < characters.count else { return " " }
        return characters[column]
    }
}
