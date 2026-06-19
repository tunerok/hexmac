//
//  CompareRowCacheTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class CompareRowCacheTests: XCTestCase {
    func testBatchRowBytesSplitsRows() {
        let bytes = Array(0..<64).map { UInt8($0) }
        let array = BTreeByteArray()
        array.insert(slice: MemoryByteSlice(data: Data(bytes)), at: 0)

        let batch = CompareRowLoader.buildContexts(
            for: 0..<4,
            bytesPerRow: 16,
            fileSize: 64,
            leftArray: array,
            rightArray: array,
            leftSize: 64,
            rightSize: 64
        )

        XCTAssertEqual(batch.count, 4)
        XCTAssertEqual(batch[0]?.leftBytes, Array(0..<16))
        XCTAssertEqual(batch[3]?.leftBytes, Array(48..<64))
    }

    func testRowZeroDiffSpansWhenBytesDiffer() {
        let leftBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let rightBytes: [UInt8] = [0x01, 0xFF, 0x03, 0x04]
        let leftArray = BTreeByteArray()
        let rightArray = BTreeByteArray()
        leftArray.insert(slice: MemoryByteSlice(data: Data(leftBytes)), at: 0)
        rightArray.insert(slice: MemoryByteSlice(data: Data(rightBytes)), at: 0)

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
        XCTAssertNotNil(context)
        XCTAssertEqual(context?.leftDiffSpans?.count, 1)
        XCTAssertEqual(context?.rightDiffSpans?.count, 1)
        XCTAssertEqual(context?.leftDiffSpans?.first?.startColumn, 1)
        XCTAssertEqual(context?.leftDiffSpans?.first?.color, .yellow)
        XCTAssertEqual(context?.rightDiffSpans?.first?.startColumn, 1)
        XCTAssertEqual(context?.rightDiffSpans?.first?.color, .yellow)

        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 1,
            side: .left,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0x02,
            rightByte: 0xFF
        ), .yellow)
    }

    func testCacheEvictsOldestRows() {
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

        XCTAssertNil(cache.context(for: 0))
        XCTAssertNotNil(cache.context(for: CompareRowCache.maxRows + 3))
    }
}
