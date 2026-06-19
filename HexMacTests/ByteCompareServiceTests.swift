//
//  ByteCompareServiceTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class ByteCompareServiceTests: XCTestCase {
    func testEqualBytesHaveNoHighlight() {
        XCTAssertNil(ByteCompareService.highlightColor(
            at: 0,
            side: .left,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0xAA,
            rightByte: 0xAA
        ))
        XCTAssertNil(ByteCompareService.highlightColor(
            at: 0,
            side: .right,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0xAA,
            rightByte: 0xAA
        ))
    }

    func testChangedByteIsYellowOnBothSides() {
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 1,
            side: .left,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0x01,
            rightByte: 0x02
        ), .yellow)
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 1,
            side: .right,
            leftSize: 4,
            rightSize: 4,
            leftByte: 0x01,
            rightByte: 0x02
        ), .yellow)
    }

    func testLeftOnlyRegionIsRedOnLeft() {
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 3,
            side: .left,
            leftSize: 4,
            rightSize: 2,
            leftByte: 0xFF,
            rightByte: nil
        ), .red)
        XCTAssertNil(ByteCompareService.highlightColor(
            at: 3,
            side: .right,
            leftSize: 4,
            rightSize: 2,
            leftByte: 0xFF,
            rightByte: nil
        ))
    }

    func testRightOnlyRegionIsGreenOnRight() {
        XCTAssertNil(ByteCompareService.highlightColor(
            at: 2,
            side: .left,
            leftSize: 2,
            rightSize: 4,
            leftByte: nil,
            rightByte: 0xAB
        ))
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 2,
            side: .right,
            leftSize: 2,
            rightSize: 4,
            leftByte: nil,
            rightByte: 0xAB
        ), .green)
    }

    func testUnequalSizesAtBoundary() {
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 1,
            side: .left,
            leftSize: 2,
            rightSize: 1,
            leftByte: 0x10,
            rightByte: nil
        ), .red)
        XCTAssertEqual(ByteCompareService.highlightColor(
            at: 0,
            side: .right,
            leftSize: 0,
            rightSize: 1,
            leftByte: nil,
            rightByte: 0x20
        ), .green)
    }

    func testCollectDiffEntriesFindsAllKinds() {
        let left: [UInt8] = [0x01, 0x02, 0x03]
        let right: [UInt8] = [0x01, 0xFF]

        let entries = ByteCompareService.collectDiffEntries(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].kind, .changed)
        XCTAssertEqual(entries[0].offset, 1)
        XCTAssertEqual(entries[1].kind, .deleted)
        XCTAssertEqual(entries[1].offset, 2)
    }

    func testBuildDiffMapClassifiesBuckets() {
        let left: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let right: [UInt8] = [0x00, 0xFF]

        let map = ByteCompareService.buildDiffMap(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] },
            bucketCount: 4
        )

        XCTAssertEqual(map.bucketCount, 4)
        XCTAssertEqual(map.totalBytes, 4)
        XCTAssertEqual(map.leftKinds[1], .changed)
        XCTAssertEqual(map.rightKinds[1], .changed)
        XCTAssertEqual(map.leftKinds[3], .deleted)
        XCTAssertEqual(map.rightKinds[3], .equal)
    }

    func testFormatTextReportCollapsesRanges() {
        let entries = [
            DiffEntry(offset: 4, leftByte: 0x01, rightByte: 0x02, kind: .changed),
            DiffEntry(offset: 5, leftByte: 0x03, rightByte: 0x04, kind: .changed)
        ]

        let report = ByteCompareService.formatTextReport(
            entries: entries,
            leftName: "a.bin",
            rightName: "b.bin"
        )

        XCTAssertTrue(report.contains("Left:  a.bin"))
        XCTAssertTrue(report.contains("0x00000004-00000005  changed"))
    }

    func testFormatCSVIncludesHeaderAndRows() {
        let entries = [
            DiffEntry(offset: 0, leftByte: nil, rightByte: 0x20, kind: .added)
        ]

        let csv = ByteCompareService.formatCSV(entries: entries)
        XCTAssertEqual(csv, "offset,kind,left_hex,right_hex\n00000000,added,,20")
    }

    func testBuildDiffIndexMergesAdjacentRegions() {
        let left: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let right: [UInt8] = [0x01, 0xFF, 0xFE, 0x04]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] },
            bucketCount: 4
        )

        XCTAssertEqual(index.regions.count, 1)
        XCTAssertEqual(index.regions[0].start, 1)
        XCTAssertEqual(index.regions[0].end, 2)
        XCTAssertEqual(index.regions[0].leftKind, .changed)
        XCTAssertEqual(index.regions[0].rightKind, .changed)
    }

    func testBuildDiffIndexIdenticalFilesHaveNoRegions() {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: bytes.count,
            rightSize: bytes.count,
            leftByte: { offset in bytes[offset] },
            rightByte: { offset in bytes[offset] }
        )

        XCTAssertTrue(index.regions.isEmpty)
        XCTAssertEqual(index.map.leftKinds, Array(repeating: .equal, count: index.map.bucketCount))
    }

    func testDiffIndexHighlightLookup() {
        let left: [UInt8] = [0x01, 0x02, 0x03]
        let right: [UInt8] = [0x01, 0xFF]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        XCTAssertNil(index.highlight(at: 0, side: .left))
        XCTAssertEqual(index.highlight(at: 1, side: .left), .yellow)
        XCTAssertEqual(index.highlight(at: 2, side: .left), .red)
        XCTAssertNil(index.highlight(at: 2, side: .right))
    }

    func testCollectDiffEntriesFromIndexMatchesFullScan() {
        let left: [UInt8] = [0x01, 0x02, 0x03]
        let right: [UInt8] = [0x01, 0xFF]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        let fromIndex = ByteCompareService.collectDiffEntries(
            from: index,
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )
        let fullScan = ByteCompareService.collectDiffEntries(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        XCTAssertEqual(fromIndex, fullScan)
    }
}
