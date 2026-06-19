//
//  DocumentRowLoader.swift
//  HexMac
//

import Foundation

enum DocumentRowLoader {
    nonisolated static func loadRows(
        for rows: Range<Int>,
        bytesPerRow: Int,
        fileSize: Int,
        byteArray: BTreeByteArray
    ) -> [Int: [UInt8]] {
        guard !rows.isEmpty, bytesPerRow > 0, fileSize > 0 else { return [:] }

        let firstRow = rows.lowerBound
        let lastRow = rows.upperBound - 1
        let startOffset = HexFormatter.rowOffset(for: firstRow, bytesPerRow: bytesPerRow)
        let lastRowOffset = HexFormatter.rowOffset(for: lastRow, bytesPerRow: bytesPerRow)
        let lastRowCount = HexFormatter.byteCount(
            forRow: lastRow,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow
        )
        let endOffset = min(lastRowOffset + lastRowCount, fileSize)
        guard startOffset < endOffset else { return [:] }

        let allBytes = byteArray.bytes(in: UInt64(startOffset)..<UInt64(endOffset))
        var result: [Int: [UInt8]] = [:]
        result.reserveCapacity(rows.count)

        for row in rows {
            let offset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRow)
            let count = HexFormatter.byteCount(
                forRow: row,
                fileSize: fileSize,
                bytesPerRow: bytesPerRow
            )
            guard count > 0, offset >= startOffset else { continue }
            let localStart = offset - startOffset
            let localEnd = localStart + count
            guard localEnd <= allBytes.count else { continue }
            result[row] = Array(allBytes[localStart..<localEnd])
        }

        return result
    }
}
