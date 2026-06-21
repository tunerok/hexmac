//
//  HexDiffHighlightOverlay.swift
//  ediHex
//

import SwiftUI

enum HexOverlayColumn {
    case hex
    case text
}

struct HexHighlightCanvasOverlay: View {
    let spans: [HexDiffSpan]
    let bytesPerRow: Int

    var body: some View {
        Canvas { context, size in
            for span in spans {
                let originX = HexGridLayout.hexCellOriginX(for: span.startColumn)
                let width = HexGridLayout.hexSpanWidth(
                    from: span.startColumn,
                    to: span.endColumn
                )
                let rect = CGRect(
                    x: originX,
                    y: 1,
                    width: width,
                    height: max(0, size.height - 2)
                )
                let path = RoundedRectangle(cornerRadius: 2).path(in: rect)
                context.fill(path, with: .color(span.color.color.opacity(0.3)))
            }
        }
        .frame(
            width: HexFormatter.hexColumnWidth(for: bytesPerRow),
            height: HexGridLayout.rowHeight
        )
        .allowsHitTesting(false)
    }
}

struct HexSelectionCanvasOverlay: View {
    let spans: [HexColumnSpan]
    let column: HexOverlayColumn
    let bytesPerRow: Int

    var body: some View {
        Canvas { context, size in
            for span in spans {
                let originX = cellOriginX(for: span.startColumn)
                let width = spanWidth(from: span.startColumn, to: span.endColumn)
                let rect = CGRect(
                    x: originX,
                    y: 1,
                    width: width,
                    height: max(0, size.height - 2)
                )
                let path = RoundedRectangle(cornerRadius: 2).path(in: rect)
                context.fill(path, with: .color(Color.accentColor.opacity(0.35)))
            }
        }
        .frame(width: columnWidth, height: HexGridLayout.rowHeight)
        .allowsHitTesting(false)
    }

    private var columnWidth: CGFloat {
        switch column {
        case .hex:
            HexFormatter.hexColumnWidth(for: bytesPerRow)
        case .text:
            HexFormatter.textColumnWidth(for: bytesPerRow)
        }
    }

    private func cellOriginX(for column: Int) -> CGFloat {
        switch self.column {
        case .hex:
            HexGridLayout.hexCellOriginX(for: column)
        case .text:
            HexGridLayout.textCellOriginX(for: column)
        }
    }

    private func spanWidth(from startColumn: Int, to endColumn: Int) -> CGFloat {
        switch column {
        case .hex:
            HexGridLayout.hexSpanWidth(from: startColumn, to: endColumn)
        case .text:
            HexGridLayout.textSpanWidth(from: startColumn, to: endColumn)
        }
    }
}

struct HexEditingCellOverlay: View {
    let column: Int
    let hexText: String
    let editingHexText: String
    let bytesPerRow: Int

    var body: some View {
        Text(displayText)
            .font(.body.monospaced())
            .foregroundStyle(Color.accentColor)
            .frame(width: HexGridLayout.cellWidth)
            .padding(.vertical, 1)
            .background(.background, in: RoundedRectangle(cornerRadius: 2))
            .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 2))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.accentColor, lineWidth: 1)
            }
            .offset(x: HexGridLayout.hexCellOriginX(for: column))
            .frame(
                width: HexFormatter.hexColumnWidth(for: bytesPerRow),
                height: HexGridLayout.rowHeight,
                alignment: .leading
            )
            .allowsHitTesting(false)
    }

    private var displayText: String {
        guard !editingHexText.isEmpty else {
            return hexText
        }
        return "\(editingHexText)_"
    }
}

typealias HexDiffHighlightOverlay = HexHighlightCanvasOverlay
