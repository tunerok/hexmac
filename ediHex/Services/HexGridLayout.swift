//
//  HexGridLayout.swift
//  ediHex
//

import CoreGraphics
import Foundation

enum HexGridLayout {
    static let contentPadding: CGFloat = 8
    static let rowHeight: CGFloat = 22
    static let offsetColumnWidth: CGFloat = 80
    static let hexColumnLeadingPadding: CGFloat = 4
    static let cellWidth: CGFloat = 22
    static let cellSpacing: CGFloat = 2
    static let dividerHorizontalPadding: CGFloat = 4
    static let dividerWidth: CGFloat = 1
    static var textCharacterWidth: CGFloat {
        HexFontMetrics.bodyMonospacedCharacterWidth
    }
    static let headerContentHeight: CGFloat = 20
    static let headerBottomPadding: CGFloat = 4

    static var headerTotalHeight: CGFloat {
        headerContentHeight + headerBottomPadding + dividerWidth
    }

    static var dividerSectionWidth: CGFloat {
        dividerHorizontalPadding + dividerWidth + dividerHorizontalPadding
    }

    static func hexColumnWidth(for bytesPerRow: Int) -> CGFloat {
        guard bytesPerRow > 0 else { return 0 }
        return CGFloat(bytesPerRow) * cellWidth + CGFloat(bytesPerRow - 1) * cellSpacing
    }

    static func textColumnWidth(for bytesPerRow: Int) -> CGFloat {
        CGFloat(bytesPerRow) * textCharacterWidth
    }

    static func hexTextContentWidth(for bytesPerRow: Int) -> CGFloat {
        hexColumnLeadingPadding
            + hexColumnWidth(for: bytesPerRow)
            + dividerSectionWidth
            + textColumnWidth(for: bytesPerRow)
    }

    static func rowContentWidth(for bytesPerRow: Int) -> CGFloat {
        offsetColumnWidth + hexTextContentWidth(for: bytesPerRow)
    }

    static func hexCellOriginX(for column: Int) -> CGFloat {
        CGFloat(column) * (cellWidth + cellSpacing)
    }

    static func hexSpanWidth(from startColumn: Int, to endColumn: Int) -> CGFloat {
        let columnCount = endColumn - startColumn + 1
        guard columnCount > 0 else { return 0 }
        return CGFloat(columnCount) * cellWidth + CGFloat(columnCount - 1) * cellSpacing
    }

    static func textCellOriginX(for column: Int) -> CGFloat {
        CGFloat(column) * textCharacterWidth
    }

    static func textSpanWidth(from startColumn: Int, to endColumn: Int) -> CGFloat {
        let columnCount = endColumn - startColumn + 1
        guard columnCount > 0 else { return 0 }
        return CGFloat(columnCount) * textCharacterWidth
    }

    static func hexColumnStartX(
        contentPadding: CGFloat = contentPadding,
        includesOffsetColumn: Bool = true
    ) -> CGFloat {
        if includesOffsetColumn {
            return contentPadding + offsetColumnWidth + hexColumnLeadingPadding
        }
        return hexColumnLeadingPadding
    }

    static func textColumnStartX(
        bytesPerRow: Int,
        contentPadding: CGFloat = contentPadding,
        includesOffsetColumn: Bool = true
    ) -> CGFloat {
        hexColumnStartX(contentPadding: contentPadding, includesOffsetColumn: includesOffsetColumn)
            + hexColumnWidth(for: bytesPerRow)
            + dividerSectionWidth
    }

    static func byteOffset(
        at point: CGPoint,
        rowCount: Int,
        fileSize: Int,
        bytesPerRow: Int,
        firstVisibleRow: Int = 0,
        includesOffsetColumn: Bool = false
    ) -> Int? {
        guard rowCount > 0, bytesPerRow > 0, fileSize > 0 else { return nil }

        let adjustedY = point.y - contentPadding
        guard adjustedY >= 0 else { return nil }

        let localRowIndex = Int(adjustedY / rowHeight)
        let rowIndex = firstVisibleRow + localRowIndex
        guard rowIndex >= 0, rowIndex < rowCount else { return nil }

        let column = columnIndex(
            at: point.x,
            bytesPerRow: bytesPerRow,
            includesOffsetColumn: includesOffsetColumn
        )
        guard let column else { return nil }

        let offset = rowIndex * bytesPerRow + column
        guard offset >= 0, offset < fileSize else { return nil }
        return offset
    }

    private static func columnIndex(
        at x: CGFloat,
        bytesPerRow: Int,
        includesOffsetColumn: Bool
    ) -> Int? {
        let hexStart = hexColumnStartX(includesOffsetColumn: includesOffsetColumn)
        let hexEnd = hexStart + hexColumnWidth(for: bytesPerRow)
        let textStart = textColumnStartX(bytesPerRow: bytesPerRow, includesOffsetColumn: includesOffsetColumn)
        let textEnd = textStart + textColumnWidth(for: bytesPerRow)

        if x >= hexStart, x < hexEnd {
            let relativeX = x - hexStart
            let slotWidth = cellWidth + cellSpacing
            let column = min(bytesPerRow - 1, max(0, Int(relativeX / slotWidth)))
            return column
        }

        if x >= textStart, x < textEnd {
            let relativeX = x - textStart
            let column = min(bytesPerRow - 1, max(0, Int(relativeX / textCharacterWidth)))
            return column
        }

        return nil
    }
}
