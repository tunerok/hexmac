//
//  HexGridHeaderView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct HexGridHeaderView: View {
    let bytesPerRow: Int

    var body: some View {
        HStack(spacing: 0) {
            Text(String(localized: "Offset"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: HexGridLayout.offsetColumnWidth, alignment: .leading)

            HStack(spacing: HexGridLayout.cellSpacing) {
                ForEach(0..<bytesPerRow, id: \.self) { column in
                    Text(HexFormatter.columnIndexString(for: column))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: HexGridLayout.cellWidth)
                }
            }
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
        .background(Color(nsColor: .textBackgroundColor))
        .compositingGroup()
        .zIndex(1)
    }
}
