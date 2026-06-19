//
//  CompareRowCache.swift
//  HexMac
//

import Foundation

struct CompareRowCache {
    static let maxRows = 512

    private var rows: [Int: CompareRowContext] = [:]
    private var order: [Int] = []
    private var revisions: [Int: Int] = [:]

    mutating func invalidate() {
        rows.removeAll(keepingCapacity: false)
        order.removeAll(keepingCapacity: false)
        revisions.removeAll(keepingCapacity: false)
    }

    func context(for row: Int) -> CompareRowContext? {
        rows[row]
    }

    func revision(for row: Int) -> Int {
        revisions[row] ?? 0
    }

    mutating func store(_ context: CompareRowContext, for row: Int) {
        if rows[row] != nil {
            order.removeAll { $0 == row }
        } else if order.count >= Self.maxRows, let evicted = order.first {
            order.removeFirst()
            rows.removeValue(forKey: evicted)
            revisions.removeValue(forKey: evicted)
        }
        rows[row] = context
        order.append(row)
        revisions[row, default: 0] &+= 1
    }

    mutating func storeBatch(_ batch: [Int: CompareRowContext]) -> [Int] {
        var updatedRows: [Int] = []
        updatedRows.reserveCapacity(batch.count)
        for row in batch.keys.sorted() {
            guard let context = batch[row] else { continue }
            store(context, for: row)
            updatedRows.append(row)
        }
        return updatedRows
    }
}

enum CompareRowLoader {
    nonisolated static func buildContexts(
        for rows: Range<Int>,
        bytesPerRow: Int,
        fileSize: Int,
        leftArray: BTreeByteArray,
        rightArray: BTreeByteArray,
        leftSize: Int,
        rightSize: Int
    ) -> [Int: CompareRowContext] {
        guard !rows.isEmpty else { return [:] }

        let leftBatch = batchRowBytes(
            rows: rows,
            bytesPerRow: bytesPerRow,
            fileSize: fileSize,
            docSize: leftSize,
            byteArray: leftArray
        )
        let rightBatch = batchRowBytes(
            rows: rows,
            bytesPerRow: bytesPerRow,
            fileSize: fileSize,
            docSize: rightSize,
            byteArray: rightArray
        )

        var result: [Int: CompareRowContext] = [:]
        result.reserveCapacity(rows.count)

        for row in rows {
            let leftBytes = leftBatch[row] ?? []
            let rightBytes = rightBatch[row] ?? []
            let count = max(leftBytes.count, rightBytes.count)
            guard count > 0 else { continue }

            let rowOffset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRow)
            let leftDiffSpans = ByteCompareService.diffSpans(
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                rowOffset: rowOffset,
                leftSize: leftSize,
                rightSize: rightSize,
                side: .left
            )
            let rightDiffSpans = ByteCompareService.diffSpans(
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                rowOffset: rowOffset,
                leftSize: leftSize,
                rightSize: rightSize,
                side: .right
            )

            result[row] = CompareRowContext(
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                leftDiffSpans: leftDiffSpans,
                rightDiffSpans: rightDiffSpans
            )
        }

        return result
    }

    nonisolated private static func batchRowBytes(
        rows: Range<Int>,
        bytesPerRow: Int,
        fileSize: Int,
        docSize: Int,
        byteArray: BTreeByteArray
    ) -> [Int: [UInt8]] {
        guard !rows.isEmpty else { return [:] }

        let firstRow = rows.lowerBound
        let lastRow = rows.upperBound - 1
        let startOffset = HexFormatter.rowOffset(for: firstRow, bytesPerRow: bytesPerRow)
        let lastRowOffset = HexFormatter.rowOffset(for: lastRow, bytesPerRow: bytesPerRow)
        let lastRowCount = HexFormatter.byteCount(
            forRow: lastRow,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow
        )
        let endOffset = min(lastRowOffset + lastRowCount, docSize)
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
