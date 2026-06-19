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

    func testCacheEvictsOldestRows() {
        var cache = CompareRowCache()
        let context = CompareRowContext(
            leftBytes: [0x01],
            rightBytes: [0x02],
            leftHighlights: [nil],
            rightHighlights: [nil]
        )

        for row in 0..<(CompareRowCache.maxRows + 4) {
            cache.store(context, for: row)
        }

        XCTAssertNil(cache.context(for: 0))
        XCTAssertNotNil(cache.context(for: CompareRowCache.maxRows + 3))
    }
}
