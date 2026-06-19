//
//  HistogramBuilderTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class HistogramBuilderTests: XCTestCase {
    func testBuildIncrementalMatchesFullBuild() {
        let bytes = (0..<512).map { UInt8($0 % 256) }

        let full = HistogramBuilder.build(from: bytes)
        let incremental = HistogramBuilder.buildIncremental(in: 0..<bytes.count) { range in
            Array(bytes[range])
        }

        XCTAssertEqual(incremental, full)
    }

    func testBuildIncrementalReportsProgress() {
        let bytes = Array(repeating: UInt8(0xAB), count: 128)
        var progressValues: [Double] = []

        _ = HistogramBuilder.buildIncremental(
            in: 0..<bytes.count,
            bytesProvider: { range in
                Array(bytes[range])
            },
            chunkSize: 32,
            onChunk: { _, progress in
                progressValues.append(progress)
            }
        )

        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.first ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(progressValues.last ?? -1, 1, accuracy: 0.0001)
    }
}
