//
//  ByteCompareServiceTests.swift
//  ediHexTests
//

import XCTest
@testable import ediHex

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

    func testDiffSpansDetectsChangedDeletedAndAdded() {
        let left: [UInt8] = [0x01, 0x02, 0x03]
        let right: [UInt8] = [0x01, 0xFF]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )
        let leftSpans = ByteCompareService.diffSpans(
            from: index,
            row: 0,
            bytesPerRow: 16,
            fileSize: 3,
            side: .left
        )!
        let rightSpans = ByteCompareService.diffSpans(
            from: index,
            row: 0,
            bytesPerRow: 16,
            fileSize: 3,
            side: .right
        )!

        XCTAssertEqual(leftSpans.count, 2)
        XCTAssertEqual(leftSpans[0].startColumn, 1)
        XCTAssertEqual(leftSpans[0].endColumn, 1)
        XCTAssertEqual(leftSpans[0].color, .yellow)
        XCTAssertEqual(leftSpans[1].startColumn, 2)
        XCTAssertEqual(leftSpans[1].endColumn, 2)
        XCTAssertEqual(leftSpans[1].color, .red)

        XCTAssertEqual(rightSpans.count, 1)
        XCTAssertEqual(rightSpans[0].startColumn, 1)
        XCTAssertEqual(rightSpans[0].endColumn, 1)
        XCTAssertEqual(rightSpans[0].color, .yellow)
    }

    func testDiffSpansMergesAdjacentColumnsWithSameColor() {
        let left: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let right: [UInt8] = [0x01, 0xA0, 0xA1, 0x04]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )
        let spans = ByteCompareService.diffSpans(
            from: index,
            row: 0,
            bytesPerRow: 16,
            fileSize: 4,
            side: .left
        )!

        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].startColumn, 1)
        XCTAssertEqual(spans[0].endColumn, 2)
        XCTAssertEqual(spans[0].color, .yellow)
    }

    func testLocalDiffSpansMatchIndexSpans() {
        let left: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                             0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
                             0x11, 0x12]
        let right: [UInt8] = [0x01, 0xFF, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                              0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
                              0xAA]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        let bytesPerRow = 16
        let fileSize = max(left.count, right.count)
        let rowCount = (fileSize + bytesPerRow - 1) / bytesPerRow

        for row in 0..<rowCount {
            let rowOffset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRow)
            let count = HexFormatter.byteCount(
                forRow: row,
                fileSize: fileSize,
                bytesPerRow: bytesPerRow
            )
            let leftBytes = Array(left[rowOffset..<min(rowOffset + count, left.count)])
            let rightBytes = Array(right[rowOffset..<min(rowOffset + count, right.count)])

            for side: CompareSide in [.left, .right] {
                let fromIndex = ByteCompareService.diffSpans(
                    from: index,
                    row: row,
                    bytesPerRow: bytesPerRow,
                    fileSize: fileSize,
                    side: side
                )
                let local = ByteCompareService.diffSpans(
                    leftBytes: leftBytes,
                    rightBytes: rightBytes,
                    rowOffset: rowOffset,
                    leftSize: left.count,
                    rightSize: right.count,
                    side: side
                )
                XCTAssertEqual(local, fromIndex, "row \(row) side \(side)")
            }
        }
    }

    func testBuildDiffRegionsIncrementalMatchesFullIndex() {
        let left: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let right: [UInt8] = [0x01, 0xFF, 0xFE, 0x04, 0x06]

        let index = ByteCompareService.buildDiffIndex(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] }
        )

        let regions = ByteCompareService.buildDiffRegionsIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )

        XCTAssertEqual(regions, index.regions)
    }

    func testBuildDiffMapIncrementalMatchesFullMapOnSmallFiles() {
        let left: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let right: [UInt8] = [0x00, 0xFF]

        let fullMap = ByteCompareService.buildDiffMap(
            leftSize: left.count,
            rightSize: right.count,
            leftByte: { offset in left[offset] },
            rightByte: { offset in right[offset] },
            bucketCount: 4
        )

        let incrementalMap = ByteCompareService.buildDiffMapIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 4,
            chunkSize: 2,
            strideOverride: 1
        )

        XCTAssertEqual(incrementalMap, fullMap)
    }

    func testBuildDiffMapIncrementalSamplingFindsDiffInBucket() {
        let left = Array(repeating: UInt8(0x00), count: 256)
        let right = Array(repeating: UInt8(0x00), count: 256)
        var leftMut = left
        var rightMut = right
        leftMut[200] = 0x01
        rightMut[200] = 0x02

        let map = ByteCompareService.buildDiffMapIncremental(
            leftSize: leftMut.count,
            rightSize: rightMut.count,
            leftBytes: { range in Array(leftMut[range]) },
            rightBytes: { range in Array(rightMut[range]) },
            bucketCount: 4,
            chunkSize: 64,
            strideOverride: 32
        )

        XCTAssertTrue(map.leftKinds.contains(.changed))
        XCTAssertTrue(map.rightKinds.contains(.changed))
    }

    func testBuildDiffMapIncrementalUnequalSizesDoesNotCrash() {
        let left = Array(repeating: UInt8(0x00), count: 100)
        let right = Array(repeating: UInt8(0xFF), count: 10_000)

        let map = ByteCompareService.buildDiffMapIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 4,
            chunkSize: 64,
            strideOverride: 1
        )

        XCTAssertEqual(map.totalBytes, right.count)
        XCTAssertTrue(map.rightKinds.contains(.added))
    }

    func testChunkHashFindsSingleByteDiffInLargeFile() {
        let chunkSize = 1024
        let fileSize = 100 * chunkSize
        var left = Array(repeating: UInt8(0x00), count: fileSize)
        var right = Array(repeating: UInt8(0x00), count: fileSize)
        let diffOffset = 50 * chunkSize + 17
        left[diffOffset] = 0x01
        right[diffOffset] = 0x02

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 400,
            chunkSize: chunkSize
        )

        XCTAssertEqual(index.diffChunkStarts, [50 * chunkSize])
        XCTAssertTrue(index.map.leftKinds.contains(.changed))
        XCTAssertTrue(index.map.rightKinds.contains(.changed))
    }

    func testChunkHashIdenticalLargeFilesHaveEmptyDiffChunks() {
        let chunkSize = 1024
        let fileSize = 1024 * chunkSize
        let data = Array(repeating: UInt8(0xAB), count: fileSize)

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: data.count,
            rightSize: data.count,
            leftBytes: { range in Array(data[range]) },
            rightBytes: { range in Array(data[range]) },
            bucketCount: 400,
            chunkSize: chunkSize
        )

        XCTAssertTrue(index.diffChunkStarts.isEmpty)
        XCTAssertFalse(index.map.leftKinds.contains(where: { $0 != .equal }))
    }

    func testChunkHashUnequalSizesMarksTailChunks() {
        let chunkSize = 64
        let left = Array(repeating: UInt8(0x00), count: 80)
        let right = Array(repeating: UInt8(0x00), count: 200)

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 4,
            chunkSize: chunkSize
        )

        XCTAssertFalse(index.diffChunkStarts.isEmpty)
        XCTAssertTrue(index.map.rightKinds.contains(.added))
    }

    func testFindNextDiffOffsetSkipsLargeGap() {
        let chunkSize = 64
        let left = Array(repeating: UInt8(0x00), count: 512)
        var right = Array(repeating: UInt8(0x00), count: 512)
        right[0] = 0xFF
        right[400] = 0xFF

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 8,
            chunkSize: chunkSize
        )

        let next = ByteCompareService.findNextDiffOffset(
            after: 0,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )

        XCTAssertEqual(next, 400)
    }

    func testFindNextDiffOffsetFindsSecondDiffInSameChunk() {
        let left: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let right: [UInt8] = [0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00]

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 4,
            chunkSize: 8
        )

        let first = ByteCompareService.findFirstDiffOffset(
            in: 0..<left.count,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(first, 1)

        let second = ByteCompareService.findNextDiffOffset(
            after: 1,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(second, 5)
    }

    func testFindPreviousDiffOffset() {
        let left: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let right: [UInt8] = [0x00, 0xFF, 0x00, 0x00, 0xFF, 0x00]

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 4,
            chunkSize: 8
        )

        let previousFromSecondDiff = ByteCompareService.findPreviousDiffOffset(
            before: 4,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(previousFromSecondDiff, 1)

        let previousFromAfterSecondDiff = ByteCompareService.findPreviousDiffOffset(
            before: 5,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(previousFromAfterSecondDiff, 4)
    }

    func testDiffChunkIndexLookup() {
        let index = CompareDiffChunkIndex(
            chunkSize: 64,
            totalBytes: 256,
            diffChunkStarts: [0, 128],
            map: CompareDiffMap(
                bucketCount: 4,
                totalBytes: 256,
                leftKinds: [.changed, .equal, .changed, .equal],
                rightKinds: [.changed, .equal, .changed, .equal]
            )
        )

        XCTAssertEqual(ByteCompareService.diffChunkIndex(for: 0, in: index), 0)
        XCTAssertEqual(ByteCompareService.diffChunkIndex(for: 50, in: index), 0)
        XCTAssertEqual(ByteCompareService.diffChunkIndex(for: 128, in: index), 1)
        XCTAssertEqual(ByteCompareService.diffChunkIndex(for: 200, in: index), 1)
        XCTAssertNil(ByteCompareService.diffChunkIndex(for: -1, in: index))
    }

    func testFindNextDiffOffsetWrapsFromLastToFirst() {
        let chunkSize = 64
        let left = Array(repeating: UInt8(0x00), count: 512)
        var right = Array(repeating: UInt8(0x00), count: 512)
        right[0] = 0xFF
        right[400] = 0xFF

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 8,
            chunkSize: chunkSize
        )

        XCTAssertEqual(index.diffChunkStarts, [0, 384])

        let wrapped = ByteCompareService.findNextDiffChunkStartWrapping(
            after: 400,
            chunkIndex: index
        )

        XCTAssertEqual(wrapped, 0)
    }

    func testFindPreviousDiffOffsetWrapsFromFirstToLast() {
        let chunkSize = 64
        let left = Array(repeating: UInt8(0x00), count: 512)
        var right = Array(repeating: UInt8(0x00), count: 512)
        right[1] = 0xFF
        right[400] = 0xFF

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 8,
            chunkSize: chunkSize
        )

        XCTAssertEqual(index.diffChunkStarts, [0, 384])

        let wrapped = ByteCompareService.findPreviousDiffChunkStartWrapping(
            before: 1,
            chunkIndex: index
        )

        XCTAssertEqual(wrapped, 384)
    }

    func testFindPreviousDiffOffsetWrapsWhenNoCurrentOffset() {
        let chunkSize = 64
        let left = Array(repeating: UInt8(0x00), count: 512)
        var right = Array(repeating: UInt8(0x00), count: 512)
        right[0] = 0xFF
        right[400] = 0xFF

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 8,
            chunkSize: chunkSize
        )

        let wrapped = ByteCompareService.findPreviousDiffChunkStartWrapping(
            before: left.count,
            chunkIndex: index
        )

        XCTAssertEqual(wrapped, 384)
    }

    func testByteNavigationWrapsToExactDiffBytes() {
        let chunkSize = 1024
        let left = Array(repeating: UInt8(0x00), count: 2048)
        var right = Array(repeating: UInt8(0x00), count: 2048)
        right[17] = 0xFF
        right[1024 + 42] = 0xFF

        let index = ByteCompareService.buildDiffChunkIndexIncremental(
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) },
            bucketCount: 8,
            chunkSize: chunkSize
        )

        XCTAssertEqual(index.diffChunkStarts, [0, 1024])

        let next = ByteCompareService.findNextDiffOffsetWrapping(
            after: -1,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(next, 17)

        let nextChunk = ByteCompareService.findNextDiffOffsetWrapping(
            after: 17,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(nextChunk, 1024 + 42)

        let previous = ByteCompareService.findPreviousDiffOffsetWrapping(
            before: 1024 + 42,
            chunkIndex: index,
            leftSize: left.count,
            rightSize: right.count,
            leftBytes: { range in Array(left[range]) },
            rightBytes: { range in Array(right[range]) }
        )
        XCTAssertEqual(previous, 17)
    }
}
