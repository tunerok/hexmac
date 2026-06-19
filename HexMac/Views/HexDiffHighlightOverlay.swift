//
//  HexDiffHighlightOverlay.swift
//  HexMac
//

import SwiftUI

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

typealias HexDiffHighlightOverlay = HexHighlightCanvasOverlay
