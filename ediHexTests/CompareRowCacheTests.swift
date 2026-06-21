//
//  CompareRowCacheTests.swift
//  ediHexTests
//

import Foundation
import Testing
@testable import ediHex

@Suite(.serialized)
struct CompareRowCacheTests {
    private func makeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ediHexCompareRowCache-\(UUID().uuidString).bin")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeArray(_ bytes: [UInt8]) -> BTreeByteArray {
        let array = BTreeByteArray()
        array.insert(slice: MemoryByteSlice(data: Data(bytes)), at: 0)
        return array
    }

    @Test func batchRowBytesSplitsRows() {
        let bytes = Array((0..<64).map(UInt8.init))
        let leftArray = makeArray(bytes)
        let rightArray = makeArray(bytes)

        let batch = CompareRowLoader.buildContexts(
            for: 0..<4,
            bytesPerRow: 16,
            fileSize: 64,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: 64,
            rightSize: 64
        )

        #expect(batch.count == 4)
        #expect(batch[0]?.leftBytes == Array((0..<16).map(UInt8.init)))
        #expect(batch[3]?.leftBytes == Array((48..<64).map(UInt8.init)))
    }

    @Test func rowZeroDiffSpansWhenBytesDiffer() {
        let leftBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let rightBytes: [UInt8] = [0x01, 0xFF, 0x03, 0x04]
        let leftArray = makeArray(leftBytes)
        let rightArray = makeArray(rightBytes)

        let batch = CompareRowLoader.buildContexts(
            for: 0..<1,
            bytesPerRow: 16,
            fileSize: 4,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: 4,
            rightSize: 4
        )

        let context = batch[0]
        #expect(context != nil)
        #expect(context?.leftDiffSpans?.count == 1)
        #expect(context?.rightDiffSpans?.count == 1)
        #expect(context?.leftDiffSpans?.first?.startColumn == 1)
        #expect(context?.leftDiffSpans?.first?.color == .yellow)
        #expect(context?.rightDiffSpans?.first?.startColumn == 1)
        #expect(context?.rightDiffSpans?.first?.color == .yellow)

        #expect(ByteCompareService.highlightColor(
            at: 1,
            side: .left,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0x02,
            rightByte: 0xFF
        ) == .yellow)
    }

    @Test func cacheEvictsOldestRows() {
        var cache = CompareRowCache()
        let context = CompareRowContext(
            leftBytes: [0x01],
            rightBytes: [0x02],
            leftDiffSpans: nil,
            rightDiffSpans: nil
        )

        for row in 0..<(CompareRowCache.maxRows + 4) {
            cache.store(context, for: row)
        }

        #expect(cache.context(for: 0) == nil)
        #expect(cache.context(for: CompareRowCache.maxRows + 3) != nil)
    }

    @Test func lastRowDiffOffsetStableAcrossBytesPerRow() {
        let fileSize = 0x13EF08
        let diffOffset = fileSize - 1
        var left = Array(repeating: UInt8(0x00), count: fileSize)
        var right = Array(repeating: UInt8(0x00), count: fileSize)
        right[diffOffset] = 0xFF

        let leftArray = makeArray(left)
        let rightArray = makeArray(right)

        for bytesPerRow in [8, 16, 24, 32] {
            let lastRow = HexFormatter.rowCount(for: fileSize, bytesPerRow: bytesPerRow) - 1
            let batch = CompareRowLoader.buildContexts(
                for: lastRow..<(lastRow + 1),
                bytesPerRow: bytesPerRow,
                fileSize: fileSize,
                leftArray: leftArray,
                rightArray: rightArray,
                leftSize: fileSize,
                rightSize: fileSize
            )

            let context = batch[lastRow]
            #expect(context != nil, "Expected context for bpr=\(bytesPerRow)")
            let span = context?.leftDiffSpans?.first
            #expect(span != nil, "Expected diff span for bpr=\(bytesPerRow)")

            let rowOffset = HexFormatter.rowOffset(for: lastRow, bytesPerRow: bytesPerRow)
            let globalOffset = rowOffset + (span?.startColumn ?? -1)
            #expect(globalOffset == diffOffset, "bpr=\(bytesPerRow)")
            #expect(span?.startColumn == diffOffset - rowOffset, "bpr=\(bytesPerRow)")
            #expect(context?.leftBytes[span!.startColumn] == 0x00)
            #expect(context?.rightBytes[span!.startColumn] == 0xFF)
        }
    }

    @Test func compareRowCacheStaleAfterBytesPerRowChange() {
        let fileSize = 256
        let bytes = Array((0..<fileSize).map(UInt8.init))
        let leftArray = makeArray(bytes)
        let rightArray = makeArray(bytes)
        let row = 10

        let batch8 = CompareRowLoader.buildContexts(
            for: row..<(row + 1),
            bytesPerRow: 8,
            fileSize: fileSize,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: fileSize,
            rightSize: fileSize
        )
        guard let context8 = batch8[row] else {
            Issue.record("Expected context for bpr=8")
            return
        }

        var cache = CompareRowCache()
        cache.store(context8, for: row)

        let staleBytes = cache.context(for: row)?.leftBytes ?? []
        #expect(staleBytes.first == UInt8(row * 8))

        cache.invalidate()

        let batch16 = CompareRowLoader.buildContexts(
            for: row..<(row + 1),
            bytesPerRow: 16,
            fileSize: fileSize,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: fileSize,
            rightSize: fileSize
        )
        guard let context16 = batch16[row] else {
            Issue.record("Expected context for bpr=16")
            return
        }
        cache.store(context16, for: row)

        let freshBytes = cache.context(for: row)?.leftBytes ?? []
        #expect(freshBytes.first == UInt8(row * 16))
        #expect(freshBytes != staleBytes)
    }

    @Test func lastRowDiffOffsetFromFileBackedArrays() throws {
        let fileSize = 0x13EF08
        let diffOffset = fileSize - 1
        var left = Array(repeating: UInt8(0x00), count: fileSize)
        var right = Array(repeating: UInt8(0x00), count: fileSize)
        right[diffOffset] = 0xFF

        let leftURL = try makeTempFile(Data(left))
        let rightURL = try makeTempFile(Data(right))
        defer {
            try? FileManager.default.removeItem(at: leftURL)
            try? FileManager.default.removeItem(at: rightURL)
        }

        let leftDoc = try HexDocument.open(url: leftURL)
        let rightDoc = try HexDocument.open(url: rightURL)
        defer {
            leftDoc.close()
            rightDoc.close()
        }

        for bytesPerRow in [8, 16, 24, 32] {
            let lastRow = HexFormatter.rowCount(for: fileSize, bytesPerRow: bytesPerRow) - 1
            let batch = CompareRowLoader.buildContexts(
                for: lastRow..<(lastRow + 1),
                bytesPerRow: bytesPerRow,
                fileSize: fileSize,
                leftArray: leftDoc.byteArray,
                rightArray: rightDoc.byteArray,
                leftSize: leftDoc.fileSize,
                rightSize: rightDoc.fileSize
            )

            let context = batch[lastRow]
            #expect(context != nil, "Expected context for bpr=\(bytesPerRow)")
            let span = context?.leftDiffSpans?.first
            #expect(span != nil, "Expected diff span for bpr=\(bytesPerRow)")

            let rowOffset = HexFormatter.rowOffset(for: lastRow, bytesPerRow: bytesPerRow)
            #expect(rowOffset + (span?.startColumn ?? -1) == diffOffset, "bpr=\(bytesPerRow)")
        }
    }

    @Test func staleRowIndexMapsToDifferentOffsets() {
        let fileSize = 256
        let bytes = Array((0..<fileSize).map(UInt8.init))
        let leftArray = makeArray(bytes)
        let rightArray = makeArray(bytes)
        let row = 10

        let batch8 = CompareRowLoader.buildContexts(
            for: row..<(row + 1),
            bytesPerRow: 8,
            fileSize: fileSize,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: fileSize,
            rightSize: fileSize
        )
        let batch16 = CompareRowLoader.buildContexts(
            for: row..<(row + 1),
            bytesPerRow: 16,
            fileSize: fileSize,
            leftArray: leftArray,
            rightArray: rightArray,
            leftSize: fileSize,
            rightSize: fileSize
        )

        let bytes8 = batch8[row]?.leftBytes ?? []
        let bytes16 = batch16[row]?.leftBytes ?? []
        #expect(!bytes8.isEmpty)
        #expect(!bytes16.isEmpty)
        #expect(bytes8 != bytes16)
        #expect(bytes8.first == UInt8(row * 8))
        #expect(bytes16.first == UInt8(row * 16))
    }
}
