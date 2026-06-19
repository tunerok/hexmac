//
//  HexOffsetColumnView.swift
//  HexMac
//

import SwiftUI

struct HexOffsetColumnView: View {
    let firstVisibleRow: Int
    let rowCount: Int
    let bytesPerRow: Int
    let visibleRowCount: Int
    let height: CGFloat

    var body: some View {
        let window = HexScrollWindow(
            firstVisibleRow: firstVisibleRow,
            visibleRowCount: visibleRowCount,
            phase: .idle
        )
        let renderedRange = window.renderedRange(for: rowCount)
        let rowHeight = HexGridLayout.rowHeight
        let topPadding = HexGridLayout.contentPadding

        ZStack(alignment: .topLeading) {
            ForEach(Array(renderedRange), id: \.self) { rowIndex in
                Text(HexFormatter.offsetString(for: HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: HexGridLayout.offsetColumnWidth, height: rowHeight, alignment: .leading)
                    .offset(y: topPadding + CGFloat(rowIndex - firstVisibleRow) * rowHeight)
            }
        }
        .frame(width: HexGridLayout.offsetColumnWidth, height: height, alignment: .topLeading)
        .clipped()
    }
}

struct HexOffsetHeaderView: View {
    var body: some View {
        Text(String(localized: "Offset"))
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .frame(width: HexGridLayout.offsetColumnWidth, height: HexGridLayout.headerContentHeight, alignment: .leading)
            .padding(.bottom, HexGridLayout.headerBottomPadding)
            .background(Color(nsColor: .textBackgroundColor))
    }
}
