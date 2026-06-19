//
//  HexHighlight.swift
//  HexMac
//

import SwiftUI

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case red
    case blue
    case purple
    case orange

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow:
            String(localized: "Yellow")
        case .green:
            String(localized: "Green")
        case .red:
            String(localized: "Red")
        case .blue:
            String(localized: "Blue")
        case .purple:
            String(localized: "Purple")
        case .orange:
            String(localized: "Orange")
        }
    }

    var color: Color {
        switch self {
        case .yellow:
            .yellow
        case .green:
            .green
        case .red:
            .red
        case .blue:
            .blue
        case .purple:
            .purple
        case .orange:
            .orange
        }
    }
}

struct HexHighlight: Identifiable, Equatable {
    let id: UUID
    var start: Int
    var end: Int
    var color: HighlightColor

    init(id: UUID = UUID(), start: Int, end: Int, color: HighlightColor) {
        self.id = id
        self.start = min(start, end)
        self.end = max(start, end)
        self.color = color
    }

    func contains(_ offset: Int) -> Bool {
        offset >= start && offset <= end
    }

    func overlaps(_ other: HexHighlight) -> Bool {
        start <= other.end && end >= other.start
    }

    func overlaps(rangeStart: Int, rangeEnd: Int) -> Bool {
        start <= rangeEnd && end >= rangeStart
    }
}

enum HexHighlightSpans {
    static func spans(
        for row: Int,
        bytesPerRow: Int,
        fileSize: Int,
        highlights: [HexHighlight]
    ) -> [HexDiffSpan]? {
        let rowOffset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRow)
        let count = HexFormatter.byteCount(
            forRow: row,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow
        )
        guard count > 0 else { return nil }

        let rowEnd = rowOffset + count - 1
        var spans: [HexDiffSpan] = []

        for highlight in highlights {
            guard highlight.overlaps(rangeStart: rowOffset, rangeEnd: rowEnd) else { continue }

            let intersectStart = max(highlight.start, rowOffset)
            let intersectEnd = min(highlight.end, rowEnd)
            let startColumn = intersectStart - rowOffset
            let endColumn = intersectEnd - rowOffset

            if let last = spans.last,
               last.color == highlight.color,
               last.endColumn == startColumn - 1 {
                spans[spans.count - 1] = HexDiffSpan(
                    startColumn: last.startColumn,
                    endColumn: endColumn,
                    color: highlight.color
                )
            } else {
                spans.append(HexDiffSpan(
                    startColumn: startColumn,
                    endColumn: endColumn,
                    color: highlight.color
                ))
            }
        }

        return spans.isEmpty ? nil : spans
    }
}
