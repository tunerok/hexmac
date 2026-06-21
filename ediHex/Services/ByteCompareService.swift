//
//  ByteCompareService.swift
//  ediHex
//

import Foundation

enum CompareSide {
    case left
    case right
}

enum DiffRegionKind: String, CaseIterable {
    case equal
    case deleted
    case added
    case changed

    var label: String { rawValue }
}

struct DiffEntry: Equatable {
    let offset: Int
    let leftByte: UInt8?
    let rightByte: UInt8?
    let kind: DiffRegionKind
}

struct CompareDiffMap: Equatable {
    let bucketCount: Int
    let totalBytes: Int
    let leftKinds: [DiffRegionKind]
    let rightKinds: [DiffRegionKind]

    func bucketStartOffset(for index: Int) -> Int {
        guard bucketCount > 0, totalBytes > 0 else { return 0 }
        return (index * totalBytes) / bucketCount
    }
}

struct DiffRegion: Equatable {
    let start: Int
    let end: Int
    let leftKind: DiffRegionKind
    let rightKind: DiffRegionKind
}

struct HexDiffSpan: Equatable {
    let startColumn: Int
    let endColumn: Int
    let color: HighlightColor
}

struct CompareDiffIndex: Equatable {
    let totalBytes: Int
    let regions: [DiffRegion]
    let map: CompareDiffMap

    func highlight(at offset: Int, side: CompareSide) -> HighlightColor? {
        guard offset >= 0, offset < totalBytes,
              let region = regionContaining(offset) else { return nil }
        let kind = side == .left ? region.leftKind : region.rightKind
        return ByteCompareService.highlightColor(for: kind)
    }

    func highlights(
        in range: Range<Int>,
        side: CompareSide
    ) -> [HighlightColor?] {
        guard range.lowerBound < range.upperBound else { return [] }
        return range.map { highlight(at: $0, side: side) }
    }

    private func regionContaining(_ offset: Int) -> DiffRegion? {
        guard !regions.isEmpty else { return nil }

        var low = 0
        var high = regions.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let region = regions[mid]
            if offset < region.start {
                high = mid - 1
            } else if offset > region.end {
                low = mid + 1
            } else {
                return region
            }
        }
        return nil
    }
}

struct CompareDiffChunkIndex: Equatable {
    let chunkSize: Int
    let totalBytes: Int
    let diffChunkStarts: [Int]
    let map: CompareDiffMap

    var hasDifferences: Bool { !diffChunkStarts.isEmpty }
}

struct CompareRowContext {
    let leftBytes: [UInt8]
    let rightBytes: [UInt8]
    let leftDiffSpans: [HexDiffSpan]?
    let rightDiffSpans: [HexDiffSpan]?
}

enum ByteCompareService {
    nonisolated static let defaultBucketCount = 400
    nonisolated static let largeFileThreshold = 16 * 1024 * 1024

    nonisolated static func highlightColor(for kind: DiffRegionKind) -> HighlightColor? {
        switch kind {
        case .deleted:
            return .red
        case .added:
            return .green
        case .changed:
            return .yellow
        case .equal:
            return nil
        }
    }

    nonisolated static func highlightColor(
        at offset: Int,
        side: CompareSide,
        leftSize: Int,
        rightSize: Int,
        leftByte: UInt8?,
        rightByte: UInt8?
    ) -> HighlightColor? {
        guard let kind = diffKind(
            leftSize: leftSize,
            rightSize: rightSize,
            leftByte: leftByte,
            rightByte: rightByte,
            side: side
        ), kind != .equal else { return nil }
        return highlightColor(for: kind)
    }

    nonisolated static func diffSpans(
        from index: CompareDiffIndex,
        row: Int,
        bytesPerRow: Int,
        fileSize: Int,
        side: CompareSide
    ) -> [HexDiffSpan]? {
        let rowOffset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRow)
        let count = HexFormatter.byteCount(
            forRow: row,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow
        )
        guard count > 0 else { return nil }
        return diffSpans(
            from: index,
            rowOffsetRange: rowOffset..<(rowOffset + count),
            side: side
        )
    }

    nonisolated static func diffSpans(
        from index: CompareDiffIndex,
        rowOffsetRange: Range<Int>,
        side: CompareSide
    ) -> [HexDiffSpan]? {
        guard rowOffsetRange.lowerBound < rowOffsetRange.upperBound else { return nil }

        let rowStart = rowOffsetRange.lowerBound
        var spans: [HexDiffSpan] = []

        for region in index.regions {
            guard region.end >= rowOffsetRange.lowerBound else { continue }
            guard region.start < rowOffsetRange.upperBound else { break }

            let intersectStart = max(region.start, rowOffsetRange.lowerBound)
            let intersectEnd = min(region.end, rowOffsetRange.upperBound - 1)
            guard intersectStart <= intersectEnd else { continue }

            let kind = side == .left ? region.leftKind : region.rightKind
            guard kind != .equal, let color = highlightColor(for: kind) else { continue }

            let startColumn = intersectStart - rowStart
            let endColumn = intersectEnd - rowStart

            if let last = spans.last, last.color == color, last.endColumn == startColumn - 1 {
                spans[spans.count - 1] = HexDiffSpan(
                    startColumn: last.startColumn,
                    endColumn: endColumn,
                    color: color
                )
            } else {
                spans.append(HexDiffSpan(
                    startColumn: startColumn,
                    endColumn: endColumn,
                    color: color
                ))
            }
        }

        return spans.isEmpty ? nil : spans
    }

    nonisolated static func diffSpans(
        leftBytes: [UInt8],
        rightBytes: [UInt8],
        rowOffset: Int,
        leftSize: Int,
        rightSize: Int,
        side: CompareSide
    ) -> [HexDiffSpan]? {
        let count = max(leftBytes.count, rightBytes.count)
        guard count > 0 else { return nil }

        var spans: [HexDiffSpan] = []

        for index in 0..<count {
            let offset = rowOffset + index
            let leftByte: UInt8? = offset < leftSize && index < leftBytes.count ? leftBytes[index] : nil
            let rightByte: UInt8? = offset < rightSize && index < rightBytes.count ? rightBytes[index] : nil
            let kinds = diffKinds(leftByte: leftByte, rightByte: rightByte)
            let kind = side == .left ? kinds.left : kinds.right
            guard kind != .equal, let color = highlightColor(for: kind) else { continue }

            if let last = spans.last, last.color == color, last.endColumn == index - 1 {
                spans[spans.count - 1] = HexDiffSpan(
                    startColumn: last.startColumn,
                    endColumn: index,
                    color: color
                )
            } else {
                spans.append(HexDiffSpan(
                    startColumn: index,
                    endColumn: index,
                    color: color
                ))
            }
        }

        return spans.isEmpty ? nil : spans
    }

    nonisolated static func samplingStride(for totalBytes: Int, bucketCount: Int) -> Int {
        guard totalBytes > largeFileThreshold, bucketCount > 0 else { return 1 }
        let bucketWidth = max(1, (totalBytes + bucketCount - 1) / bucketCount)
        return max(1, bucketWidth / 64)
    }

    nonisolated static func diffKind(
        leftSize: Int,
        rightSize: Int,
        leftByte: UInt8?,
        rightByte: UInt8?,
        side: CompareSide
    ) -> DiffRegionKind? {
        let hasLeft = leftByte != nil
        let hasRight = rightByte != nil

        switch (hasLeft, hasRight) {
        case (true, false):
            switch side {
            case .left: return .deleted
            case .right: return nil
            }
        case (false, true):
            switch side {
            case .left: return nil
            case .right: return .added
            }
        case (true, true):
            guard let leftByte, let rightByte, leftByte != rightByte else { return .equal }
            return .changed
        case (false, false):
            return .equal
        }
    }

    nonisolated static func diffEntry(
        at offset: Int,
        leftSize: Int,
        rightSize: Int,
        leftByte: UInt8?,
        rightByte: UInt8?
    ) -> DiffEntry? {
        let hasLeft = offset < leftSize
        let hasRight = offset < rightSize

        switch (hasLeft, hasRight) {
        case (true, false):
            return DiffEntry(offset: offset, leftByte: leftByte, rightByte: nil, kind: .deleted)
        case (false, true):
            return DiffEntry(offset: offset, leftByte: nil, rightByte: rightByte, kind: .added)
        case (true, true):
            guard let leftByte, let rightByte else { return nil }
            guard leftByte != rightByte else { return nil }
            return DiffEntry(offset: offset, leftByte: leftByte, rightByte: rightByte, kind: .changed)
        case (false, false):
            return nil
        }
    }

    nonisolated static func collectDiffEntries(
        from index: CompareDiffIndex,
        leftSize: Int,
        rightSize: Int,
        leftByte: (Int) -> UInt8?,
        rightByte: (Int) -> UInt8?
    ) -> [DiffEntry] {
        var entries: [DiffEntry] = []
        entries.reserveCapacity(index.regions.count * 4)

        for region in index.regions {
            let kind = region.leftKind != .equal ? region.leftKind : region.rightKind
            for offset in region.start...region.end {
                let left = offset < leftSize ? leftByte(offset) : nil
                let right = offset < rightSize ? rightByte(offset) : nil
                entries.append(DiffEntry(
                    offset: offset,
                    leftByte: left,
                    rightByte: right,
                    kind: kind
                ))
            }
        }
        return entries
    }

    nonisolated static func collectDiffEntries(
        leftSize: Int,
        rightSize: Int,
        leftByte: (Int) -> UInt8?,
        rightByte: (Int) -> UInt8?
    ) -> [DiffEntry] {
        let total = max(leftSize, rightSize)
        guard total > 0 else { return [] }

        var entries: [DiffEntry] = []
        entries.reserveCapacity(min(total, 1024))

        for offset in 0..<total {
            let left = offset < leftSize ? leftByte(offset) : nil
            let right = offset < rightSize ? rightByte(offset) : nil
            if let entry = diffEntry(
                at: offset,
                leftSize: leftSize,
                rightSize: rightSize,
                leftByte: left,
                rightByte: right
            ) {
                entries.append(entry)
            }
        }
        return entries
    }

    nonisolated static func buildDiffIndex(
        leftSize: Int,
        rightSize: Int,
        leftByte: (Int) -> UInt8?,
        rightByte: (Int) -> UInt8?,
        bucketCount: Int = defaultBucketCount
    ) -> CompareDiffIndex {
        let total = max(leftSize, rightSize)
        let count = max(1, bucketCount)
        var leftKinds = Array(repeating: DiffRegionKind.equal, count: count)
        var rightKinds = Array(repeating: DiffRegionKind.equal, count: count)
        var regions: [DiffRegion] = []

        guard total > 0 else {
            let map = CompareDiffMap(
                bucketCount: count,
                totalBytes: 0,
                leftKinds: leftKinds,
                rightKinds: rightKinds
            )
            return CompareDiffIndex(totalBytes: 0, regions: [], map: map)
        }

        var bucketIndex = 0
        var nextBucketStart = count > 1 ? total / count : total

        for offset in 0..<total {
            while offset >= nextBucketStart, bucketIndex < count - 1 {
                bucketIndex += 1
                nextBucketStart = ((bucketIndex + 1) * total) / count
            }

            let left = offset < leftSize ? leftByte(offset) : nil
            let right = offset < rightSize ? rightByte(offset) : nil
            let kinds = diffKinds(leftByte: left, rightByte: right)

            if kinds.left != .equal {
                leftKinds[bucketIndex] = maxPriority(leftKinds[bucketIndex], kinds.left)
            }
            if kinds.right != .equal {
                rightKinds[bucketIndex] = maxPriority(rightKinds[bucketIndex], kinds.right)
            }

            guard kinds.left != .equal || kinds.right != .equal else { continue }

            if let last = regions.last,
               last.end == offset - 1,
               last.leftKind == kinds.left,
               last.rightKind == kinds.right {
                regions[regions.count - 1] = DiffRegion(
                    start: last.start,
                    end: offset,
                    leftKind: kinds.left,
                    rightKind: kinds.right
                )
            } else {
                regions.append(DiffRegion(
                    start: offset,
                    end: offset,
                    leftKind: kinds.left,
                    rightKind: kinds.right
                ))
            }
        }

        let map = CompareDiffMap(
            bucketCount: count,
            totalBytes: total,
            leftKinds: leftKinds,
            rightKinds: rightKinds
        )
        return CompareDiffIndex(totalBytes: total, regions: regions, map: map)
    }

    nonisolated static func buildDiffMap(
        leftSize: Int,
        rightSize: Int,
        leftByte: (Int) -> UInt8?,
        rightByte: (Int) -> UInt8?,
        bucketCount: Int = defaultBucketCount
    ) -> CompareDiffMap {
        buildDiffIndex(
            leftSize: leftSize,
            rightSize: rightSize,
            leftByte: leftByte,
            rightByte: rightByte,
            bucketCount: bucketCount
        ).map
    }

    nonisolated static func buildDiffMapIncremental(
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        bucketCount: Int = defaultBucketCount,
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        strideOverride: Int? = nil,
        onChunk: ((CompareDiffMap, Double) -> Void)? = nil
    ) -> CompareDiffMap {
        let total = max(leftSize, rightSize)
        let count = max(1, bucketCount)
        var leftKinds = Array(repeating: DiffRegionKind.equal, count: count)
        var rightKinds = Array(repeating: DiffRegionKind.equal, count: count)

        guard total > 0 else {
            let map = CompareDiffMap(
                bucketCount: count,
                totalBytes: 0,
                leftKinds: leftKinds,
                rightKinds: rightKinds
            )
            onChunk?(map, 1)
            return map
        }

        let stride = strideOverride ?? samplingStride(for: total, bucketCount: count)
        var cursor = 0

        while cursor < total {
            let chunkEnd = min(total, cursor + chunkSize)
            let leftRange = clampedRange(from: cursor, to: min(leftSize, chunkEnd))
            let rightRange = clampedRange(from: cursor, to: min(rightSize, chunkEnd))
            let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
            let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

            let sampleOffsets = sampleOffsets(
                from: cursor,
                to: chunkEnd,
                stride: stride,
                total: total,
                bucketCount: count
            )

            for offset in sampleOffsets {
                let leftByte = byteInChunk(
                    at: offset,
                    fileSize: leftSize,
                    chunkStart: leftRange.lowerBound,
                    chunk: leftChunk
                )
                let rightByte = byteInChunk(
                    at: offset,
                    fileSize: rightSize,
                    chunkStart: rightRange.lowerBound,
                    chunk: rightChunk
                )
                updateBucketKinds(
                    offset: offset,
                    leftByte: leftByte,
                    rightByte: rightByte,
                    total: total,
                    bucketCount: count,
                    leftKinds: &leftKinds,
                    rightKinds: &rightKinds
                )
            }

            cursor = chunkEnd
            let progress = Double(cursor) / Double(total)
            let map = CompareDiffMap(
                bucketCount: count,
                totalBytes: total,
                leftKinds: leftKinds,
                rightKinds: rightKinds
            )
            onChunk?(map, progress)
        }

        return CompareDiffMap(
            bucketCount: count,
            totalBytes: total,
            leftKinds: leftKinds,
            rightKinds: rightKinds
        )
    }

    nonisolated static func buildDiffRegionsIncremental(
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        onChunk: (([DiffRegion], Double) -> Void)? = nil
    ) -> [DiffRegion] {
        let total = max(leftSize, rightSize)
        guard total > 0 else {
            onChunk?([], 1)
            return []
        }

        var regions: [DiffRegion] = []
        regions.reserveCapacity(min(total / 64, 4096))
        var cursor = 0

        while cursor < total {
            let chunkEnd = min(total, cursor + chunkSize)
            let leftRange = clampedRange(from: cursor, to: min(leftSize, chunkEnd))
            let rightRange = clampedRange(from: cursor, to: min(rightSize, chunkEnd))
            let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
            let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

            appendDiffRegions(
                from: cursor,
                to: chunkEnd,
                leftSize: leftSize,
                rightSize: rightSize,
                leftChunk: leftChunk,
                rightChunk: rightChunk,
                leftChunkStart: leftRange.lowerBound,
                rightChunkStart: rightRange.lowerBound,
                regions: &regions
            )

            cursor = chunkEnd
            onChunk?(regions, Double(cursor) / Double(total))
        }

        let coalesced = coalesceSizeOnlyTail(
            regions: regions,
            leftSize: leftSize,
            rightSize: rightSize
        )
        onChunk?(coalesced, 1)
        return coalesced
    }

    nonisolated static func coalesceSizeOnlyTail(
        regions: [DiffRegion],
        leftSize: Int,
        rightSize: Int
    ) -> [DiffRegion] {
        guard leftSize != rightSize else { return regions }

        let overlap = min(leftSize, rightSize)
        let totalEnd = max(leftSize, rightSize) - 1
        guard overlap <= totalEnd else { return regions }

        let tailLeftKind: DiffRegionKind = leftSize > rightSize ? .deleted : .equal
        let tailRightKind: DiffRegionKind = rightSize > leftSize ? .added : .equal

        var result: [DiffRegion] = []
        result.reserveCapacity(regions.count)
        var tailStart: Int?
        var tailEnd: Int?

        for region in regions {
            let isTail = region.start >= overlap
                && region.leftKind == tailLeftKind
                && region.rightKind == tailRightKind

            if isTail {
                if tailStart == nil {
                    tailStart = max(region.start, overlap)
                    tailEnd = region.end
                } else {
                    tailEnd = region.end
                }
            } else {
                if let start = tailStart, let end = tailEnd {
                    result.append(DiffRegion(
                        start: start,
                        end: end,
                        leftKind: tailLeftKind,
                        rightKind: tailRightKind
                    ))
                    tailStart = nil
                    tailEnd = nil
                }
                result.append(region)
            }
        }

        if let start = tailStart, let end = tailEnd {
            result.append(DiffRegion(
                start: start,
                end: end,
                leftKind: tailLeftKind,
                rightKind: tailRightKind
            ))
        }

        return result
    }

    nonisolated static func buildDiffIndexIncremental(
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        bucketCount: Int = defaultBucketCount,
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        onChunk: ((CompareDiffIndex, Double) -> Void)? = nil
    ) -> CompareDiffIndex {
        let total = max(leftSize, rightSize)

        let map = buildDiffMapIncremental(
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            bucketCount: bucketCount,
            chunkSize: chunkSize
        ) { partialMap, progress in
            let index = CompareDiffIndex(
                totalBytes: total,
                regions: [],
                map: partialMap
            )
            onChunk?(index, progress * 0.2)
        }

        let regions = buildDiffRegionsIncremental(
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkSize
        ) { partialRegions, progress in
            let index = CompareDiffIndex(totalBytes: total, regions: partialRegions, map: map)
            onChunk?(index, 0.2 + progress * 0.8)
        }

        let index = CompareDiffIndex(totalBytes: total, regions: regions, map: map)
        onChunk?(index, 1)
        return index
    }

    nonisolated static func buildDiffChunkIndexIncremental(
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        bucketCount: Int = defaultBucketCount,
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        onChunk: ((CompareDiffChunkIndex, Double) -> Void)? = nil
    ) -> CompareDiffChunkIndex {
        let total = max(leftSize, rightSize)
        let count = max(1, bucketCount)
        var leftKinds = Array(repeating: DiffRegionKind.equal, count: count)
        var rightKinds = Array(repeating: DiffRegionKind.equal, count: count)
        var diffChunkStarts: [Int] = []
        diffChunkStarts.reserveCapacity(min((total + chunkSize - 1) / chunkSize, 4096))

        guard total > 0 else {
            let map = CompareDiffMap(
                bucketCount: count,
                totalBytes: 0,
                leftKinds: leftKinds,
                rightKinds: rightKinds
            )
            let index = CompareDiffChunkIndex(
                chunkSize: chunkSize,
                totalBytes: 0,
                diffChunkStarts: [],
                map: map
            )
            onChunk?(index, 1)
            return index
        }

        var cursor = 0
        while cursor < total {
            let chunkEnd = min(total, cursor + chunkSize)
            let leftRange = clampedRange(from: cursor, to: min(leftSize, chunkEnd))
            let rightRange = clampedRange(from: cursor, to: min(rightSize, chunkEnd))
            let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
            let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

            if chunksDiffer(leftChunk: leftChunk, rightChunk: rightChunk) {
                diffChunkStarts.append(cursor)
                markBucketsForDiffChunk(
                    chunkStart: cursor,
                    chunkEnd: chunkEnd,
                    leftSize: leftSize,
                    rightSize: rightSize,
                    total: total,
                    bucketCount: count,
                    leftKinds: &leftKinds,
                    rightKinds: &rightKinds
                )
            }

            cursor = chunkEnd
            let progress = Double(cursor) / Double(total)
            let map = CompareDiffMap(
                bucketCount: count,
                totalBytes: total,
                leftKinds: leftKinds,
                rightKinds: rightKinds
            )
            let partialIndex = CompareDiffChunkIndex(
                chunkSize: chunkSize,
                totalBytes: total,
                diffChunkStarts: diffChunkStarts,
                map: map
            )
            onChunk?(partialIndex, progress)
        }

        let map = CompareDiffMap(
            bucketCount: count,
            totalBytes: total,
            leftKinds: leftKinds,
            rightKinds: rightKinds
        )
        return CompareDiffChunkIndex(
            chunkSize: chunkSize,
            totalBytes: total,
            diffChunkStarts: diffChunkStarts,
            map: map
        )
    }

    nonisolated static func findFirstDiffOffset(
        in range: Range<Int>,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> Int? {
        guard range.lowerBound < range.upperBound else { return nil }

        var regions: [DiffRegion] = []
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let chunkEnd = min(range.upperBound, cursor + chunkSize)
            let leftRange = clampedRange(from: cursor, to: min(leftSize, chunkEnd))
            let rightRange = clampedRange(from: cursor, to: min(rightSize, chunkEnd))
            let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
            let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

            appendDiffRegions(
                from: cursor,
                to: chunkEnd,
                leftSize: leftSize,
                rightSize: rightSize,
                leftChunk: leftChunk,
                rightChunk: rightChunk,
                leftChunkStart: leftRange.lowerBound,
                rightChunkStart: rightRange.lowerBound,
                regions: &regions
            )
            cursor = chunkEnd
        }

        return regions.first?.start
    }

    nonisolated static func findLastDiffOffset(
        in range: Range<Int>,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> Int? {
        guard range.lowerBound < range.upperBound else { return nil }

        var regions: [DiffRegion] = []
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let chunkEnd = min(range.upperBound, cursor + chunkSize)
            let leftRange = clampedRange(from: cursor, to: min(leftSize, chunkEnd))
            let rightRange = clampedRange(from: cursor, to: min(rightSize, chunkEnd))
            let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
            let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

            appendDiffRegions(
                from: cursor,
                to: chunkEnd,
                leftSize: leftSize,
                rightSize: rightSize,
                leftChunk: leftChunk,
                rightChunk: rightChunk,
                leftChunkStart: leftRange.lowerBound,
                rightChunkStart: rightRange.lowerBound,
                regions: &regions
            )
            cursor = chunkEnd
        }

        return regions.last?.start
    }

    nonisolated static func diffRegionBounds(
        containing offset: Int,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> (start: Int, end: Int)? {
        let total = max(leftSize, rightSize)
        guard offset >= 0, offset < total else { return nil }

        if leftSize != rightSize {
            let overlap = min(leftSize, rightSize)
            let totalEnd = total - 1
            if offset >= overlap {
                return (overlap, totalEnd)
            }
        }

        let chunkStart = (offset / chunkSize) * chunkSize
        let chunkEnd = min(total, chunkStart + chunkSize)
        let leftRange = clampedRange(from: chunkStart, to: min(leftSize, chunkEnd))
        let rightRange = clampedRange(from: chunkStart, to: min(rightSize, chunkEnd))
        let leftChunk = leftRange.isEmpty ? [] : leftBytes(leftRange)
        let rightChunk = rightRange.isEmpty ? [] : rightBytes(rightRange)

        var regions: [DiffRegion] = []
        appendDiffRegions(
            from: chunkStart,
            to: chunkEnd,
            leftSize: leftSize,
            rightSize: rightSize,
            leftChunk: leftChunk,
            rightChunk: rightChunk,
            leftChunkStart: leftRange.lowerBound,
            rightChunkStart: rightRange.lowerBound,
            regions: &regions
        )

        for region in regions where offset >= region.start && offset <= region.end {
            return (region.start, region.end)
        }
        return nil
    }

    nonisolated static func endOfDiffRegion(
        at offset: Int,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> Int? {
        diffRegionBounds(
            containing: offset,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkSize
        )?.end
    }

    nonisolated private static func nextDiffSearchStart(
        after offset: Int,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8],
        chunkSize: Int
    ) -> Int {
        if let end = endOfDiffRegion(
            at: offset,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkSize
        ) {
            return end + 1
        }
        return offset + 1
    }

    nonisolated static func findNextDiffOffset(
        after offset: Int,
        chunkIndex: CompareDiffChunkIndex,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8]
    ) -> Int? {
        let total = chunkIndex.totalBytes
        let chunkSize = chunkIndex.chunkSize
        let searchStart = nextDiffSearchStart(
            after: offset,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkSize
        )
        guard searchStart < total else { return nil }

        let currentChunkStart = (searchStart / chunkSize) * chunkSize
        let currentChunkEnd = min(total, currentChunkStart + chunkSize)

        if searchStart < currentChunkEnd,
           let found = findFirstDiffOffset(
               in: searchStart..<currentChunkEnd,
               leftSize: leftSize,
               rightSize: rightSize,
               leftBytes: leftBytes,
               rightBytes: rightBytes,
               chunkSize: chunkSize
           ) {
            return found
        }

        let nextChunkStart = lowerBound(in: chunkIndex.diffChunkStarts, value: currentChunkEnd)
        guard nextChunkStart < chunkIndex.diffChunkStarts.count else { return nil }

        var chunkCursor = nextChunkStart
        while chunkCursor < chunkIndex.diffChunkStarts.count {
            let start = chunkIndex.diffChunkStarts[chunkCursor]
            let end = min(total, start + chunkSize)
            if let found = findFirstDiffOffset(
                in: start..<end,
                leftSize: leftSize,
                rightSize: rightSize,
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                chunkSize: chunkSize
            ) {
                return found
            }
            chunkCursor += 1
        }

        return nil
    }

    nonisolated static func findPreviousDiffOffset(
        before offset: Int,
        chunkIndex: CompareDiffChunkIndex,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8]
    ) -> Int? {
        guard offset > 0 else { return nil }

        let total = chunkIndex.totalBytes
        let chunkSize = chunkIndex.chunkSize

        if let bounds = diffRegionBounds(
            containing: offset,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkSize
        ), offset > bounds.start {
            return bounds.start
        }

        let currentChunkStart = (offset / chunkSize) * chunkSize

        if offset > currentChunkStart,
           let found = findLastDiffOffset(
               in: currentChunkStart..<offset,
               leftSize: leftSize,
               rightSize: rightSize,
               leftBytes: leftBytes,
               rightBytes: rightBytes,
               chunkSize: chunkSize
           ) {
            return found
        }

        let previousChunkEnd = currentChunkStart
        var chunkCursor = lowerBound(in: chunkIndex.diffChunkStarts, value: previousChunkEnd) - 1
        while chunkCursor >= 0 {
            let start = chunkIndex.diffChunkStarts[chunkCursor]
            let end = min(total, start + chunkSize)
            if let found = findLastDiffOffset(
                in: start..<end,
                leftSize: leftSize,
                rightSize: rightSize,
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                chunkSize: chunkSize
            ) {
                return found
            }
            chunkCursor -= 1
        }

        return nil
    }

    nonisolated static func findNextDiffChunkStartWrapping(
        after offset: Int,
        chunkIndex: CompareDiffChunkIndex
    ) -> Int? {
        let starts = chunkIndex.diffChunkStarts
        guard !starts.isEmpty else { return nil }

        let currentIndex = diffChunkIndex(for: offset, in: chunkIndex) ?? -1
        let nextIndex = currentIndex + 1
        if nextIndex < starts.count {
            return starts[nextIndex]
        }
        return starts[0]
    }

    nonisolated static func findPreviousDiffChunkStartWrapping(
        before offset: Int,
        chunkIndex: CompareDiffChunkIndex
    ) -> Int? {
        let starts = chunkIndex.diffChunkStarts
        guard !starts.isEmpty else { return nil }

        let currentIndex: Int
        if offset >= chunkIndex.totalBytes {
            currentIndex = starts.count
        } else {
            currentIndex = diffChunkIndex(for: offset, in: chunkIndex) ?? starts.count
        }

        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            return starts[previousIndex]
        }
        return starts[starts.count - 1]
    }

    nonisolated static func findNextDiffOffsetWrapping(
        after offset: Int,
        chunkIndex: CompareDiffChunkIndex,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8]
    ) -> Int? {
        if let found = findNextDiffOffset(
            after: offset,
            chunkIndex: chunkIndex,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes
        ) {
            return found
        }
        return findFirstDiffOffset(
            in: 0..<chunkIndex.totalBytes,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkIndex.chunkSize
        )
    }

    nonisolated static func findPreviousDiffOffsetWrapping(
        before offset: Int,
        chunkIndex: CompareDiffChunkIndex,
        leftSize: Int,
        rightSize: Int,
        leftBytes: (Range<Int>) -> [UInt8],
        rightBytes: (Range<Int>) -> [UInt8]
    ) -> Int? {
        if let found = findPreviousDiffOffset(
            before: offset,
            chunkIndex: chunkIndex,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes
        ) {
            return found
        }
        return findLastDiffOffset(
            in: 0..<chunkIndex.totalBytes,
            leftSize: leftSize,
            rightSize: rightSize,
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            chunkSize: chunkIndex.chunkSize
        )
    }

    nonisolated static func diffChunkIndex(
        for offset: Int,
        in chunkIndex: CompareDiffChunkIndex
    ) -> Int? {
        let starts = chunkIndex.diffChunkStarts
        guard !starts.isEmpty else { return nil }

        var low = 0
        var high = starts.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if starts[mid] <= offset {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    nonisolated static func diffRegionIndex(
        for offset: Int,
        in regions: [DiffRegion]
    ) -> Int? {
        guard !regions.isEmpty else { return nil }

        var low = 0
        var high = regions.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let region = regions[mid]
            if offset < region.start {
                high = mid - 1
            } else if offset > region.end {
                low = mid + 1
            } else {
                return mid
            }
        }

        return nil
    }

    nonisolated static func diffRegionBounds(
        containing offset: Int,
        in regions: [DiffRegion]
    ) -> (start: Int, end: Int)? {
        guard let index = diffRegionIndex(for: offset, in: regions) else { return nil }
        let region = regions[index]
        return (region.start, region.end)
    }

    nonisolated static func findNextDiffRegionStart(
        after offset: Int,
        in regions: [DiffRegion]
    ) -> Int? {
        guard !regions.isEmpty else { return nil }

        if let index = diffRegionIndex(for: offset, in: regions) {
            let nextIndex = index + 1
            guard nextIndex < regions.count else { return nil }
            return regions[nextIndex].start
        }

        for region in regions where region.start > offset {
            return region.start
        }
        return nil
    }

    nonisolated static func findPreviousDiffRegionStart(
        before offset: Int,
        in regions: [DiffRegion]
    ) -> Int? {
        guard !regions.isEmpty, offset > 0 else { return nil }

        if let index = diffRegionIndex(for: offset, in: regions) {
            let region = regions[index]
            if offset > region.start {
                return region.start
            }
            let previousIndex = index - 1
            guard previousIndex >= 0 else { return nil }
            return regions[previousIndex].start
        }

        var result: Int?
        for region in regions where region.start < offset {
            result = region.start
        }
        return result
    }

    nonisolated static func findNextDiffRegionStartWrapping(
        after offset: Int,
        in regions: [DiffRegion]
    ) -> Int? {
        if let found = findNextDiffRegionStart(after: offset, in: regions) {
            return found
        }
        return regions.first?.start
    }

    nonisolated static func findPreviousDiffRegionStartWrapping(
        before offset: Int,
        in regions: [DiffRegion]
    ) -> Int? {
        if let found = findPreviousDiffRegionStart(before: offset, in: regions) {
            return found
        }
        return regions.last?.start
    }

    nonisolated static func formatTextReport(
        entries: [DiffEntry],
        leftName: String,
        rightName: String
    ) -> String {
        var lines: [String] = [
            "ediHex Compare Report",
            "Left:  \(leftName)",
            "Right: \(rightName)",
            "Differences: \(entries.count)",
            ""
        ]

        if entries.isEmpty {
            lines.append("Files are identical.")
            return lines.joined(separator: "\n")
        }

        var index = 0
        while index < entries.count {
            let entry = entries[index]
            var end = entry.offset
            var leftByte = entry.leftByte
            var rightByte = entry.rightByte
            var next = index + 1

            while next < entries.count,
                  entries[next].kind == entry.kind,
                  entries[next].offset == end + 1 {
                end = entries[next].offset
                leftByte = entries[next].leftByte ?? leftByte
                rightByte = entries[next].rightByte ?? rightByte
                next += 1
            }

            let startText = HexFormatter.offsetString(for: entry.offset)
            if entry.offset == end {
                lines.append(formatTextLine(
                    offset: startText,
                    kind: entry.kind,
                    leftByte: leftByte,
                    rightByte: rightByte
                ))
            } else {
                let endText = HexFormatter.offsetString(for: end)
                lines.append(formatTextLine(
                    offset: "\(startText)-\(endText)",
                    kind: entry.kind,
                    leftByte: leftByte,
                    rightByte: rightByte
                ))
            }
            index = next
        }

        return lines.joined(separator: "\n")
    }

    nonisolated static func formatCSV(entries: [DiffEntry]) -> String {
        var lines = ["offset,kind,left_hex,right_hex"]
        lines.reserveCapacity(entries.count + 1)

        for entry in entries {
            let offset = HexFormatter.offsetString(for: entry.offset)
            let left = entry.leftByte.map { HexFormatter.hexPair(for: $0) } ?? ""
            let right = entry.rightByte.map { HexFormatter.hexPair(for: $0) } ?? ""
            lines.append("\(offset),\(entry.kind.rawValue),\(left),\(right)")
        }
        return lines.joined(separator: "\n")
    }

    nonisolated static func byte(at offset: Int, in size: Int, provider: (Int) -> UInt8?) -> UInt8? {
        guard offset < size else { return nil }
        return provider(offset)
    }

    nonisolated private static func clampedRange(from lower: Int, to upper: Int) -> Range<Int> {
        lower < upper ? lower..<upper : 0..<0
    }

    nonisolated private static func sampleOffsets(
        from rangeStart: Int,
        to rangeEnd: Int,
        stride: Int,
        total: Int,
        bucketCount: Int
    ) -> [Int] {
        guard rangeStart < rangeEnd else { return [] }

        var offsets = Set<Int>()
        var offset = rangeStart
        while offset < rangeEnd {
            offsets.insert(offset)
            let next = offset + stride
            if next >= rangeEnd, offset < rangeEnd - 1 {
                offset = rangeEnd - 1
            } else {
                offset = next
            }
        }

        if stride > 1, total > 0, bucketCount > 0 {
            for bucket in 0..<bucketCount {
                let bucketStart = (bucket * total) / bucketCount
                let bucketEnd = ((bucket + 1) * total) / bucketCount
                guard bucketEnd > bucketStart else { continue }

                let bucketWidth = bucketEnd - bucketStart
                let bucketStride = max(1, bucketWidth / 64)
                var bucketOffset = bucketStart
                while bucketOffset < bucketEnd {
                    if bucketOffset >= rangeStart, bucketOffset < rangeEnd {
                        offsets.insert(bucketOffset)
                    }
                    bucketOffset += bucketStride
                }

                let lastInBucket = bucketEnd - 1
                if lastInBucket >= rangeStart, lastInBucket < rangeEnd {
                    offsets.insert(lastInBucket)
                }
            }
        }

        return offsets.sorted()
    }

    nonisolated private static func byteInChunk(
        at offset: Int,
        fileSize: Int,
        chunkStart: Int,
        chunk: [UInt8]
    ) -> UInt8? {
        guard offset < fileSize else { return nil }
        let local = offset - chunkStart
        guard local >= 0, local < chunk.count else { return nil }
        return chunk[local]
    }

    nonisolated private static func appendDiffRegions(
        from rangeStart: Int,
        to rangeEnd: Int,
        leftSize: Int,
        rightSize: Int,
        leftChunk: [UInt8],
        rightChunk: [UInt8],
        leftChunkStart: Int,
        rightChunkStart: Int,
        regions: inout [DiffRegion]
    ) {
        guard rangeStart < rangeEnd else { return }

        var offset = rangeStart
        while offset < rangeEnd {
            let leftByte = byteInChunk(
                at: offset,
                fileSize: leftSize,
                chunkStart: leftChunkStart,
                chunk: leftChunk
            )
            let rightByte = byteInChunk(
                at: offset,
                fileSize: rightSize,
                chunkStart: rightChunkStart,
                chunk: rightChunk
            )
            let kinds = diffKinds(leftByte: leftByte, rightByte: rightByte)

            if kinds.left == .equal, kinds.right == .equal {
                if offset < leftSize, offset < rightSize {
                    let leftLocal = offset - leftChunkStart
                    let rightLocal = offset - rightChunkStart
                    let overlapEnd = min(rangeEnd, leftSize, rightSize)
                    let remaining = overlapEnd - offset

                    if leftLocal >= 0, rightLocal >= 0,
                       leftLocal < leftChunk.count, rightLocal < rightChunk.count,
                       remaining > 1 {
                        let available = min(
                            remaining,
                            leftChunk.count - leftLocal,
                            rightChunk.count - rightLocal
                        )
                        let equalLength = equalPrefixLength(
                            leftChunk: leftChunk,
                            leftStart: leftLocal,
                            rightChunk: rightChunk,
                            rightStart: rightLocal,
                            count: available
                        )
                        if equalLength > 0 {
                            offset += equalLength
                            continue
                        }
                    }
                }

                offset += 1
                continue
            }

            var end = offset
            while end + 1 < rangeEnd {
                let nextLeft = byteInChunk(
                    at: end + 1,
                    fileSize: leftSize,
                    chunkStart: leftChunkStart,
                    chunk: leftChunk
                )
                let nextRight = byteInChunk(
                    at: end + 1,
                    fileSize: rightSize,
                    chunkStart: rightChunkStart,
                    chunk: rightChunk
                )
                let nextKinds = diffKinds(leftByte: nextLeft, rightByte: nextRight)
                if nextKinds.left != kinds.left || nextKinds.right != kinds.right {
                    break
                }
                end += 1
            }

            mergeDiffRegion(
                start: offset,
                end: end,
                leftKind: kinds.left,
                rightKind: kinds.right,
                into: &regions
            )
            offset = end + 1
        }
    }

    nonisolated private static func equalPrefixLength(
        leftChunk: [UInt8],
        leftStart: Int,
        rightChunk: [UInt8],
        rightStart: Int,
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }

        var matched = 0
        while matched < count,
              leftChunk[leftStart + matched] == rightChunk[rightStart + matched] {
            matched += 1
        }
        return matched
    }

    nonisolated private static func mergeDiffRegion(
        start: Int,
        end: Int,
        leftKind: DiffRegionKind,
        rightKind: DiffRegionKind,
        into regions: inout [DiffRegion]
    ) {
        if let last = regions.last,
           last.end == start - 1,
           last.leftKind == leftKind,
           last.rightKind == rightKind {
            regions[regions.count - 1] = DiffRegion(
                start: last.start,
                end: end,
                leftKind: leftKind,
                rightKind: rightKind
            )
        } else {
            regions.append(DiffRegion(
                start: start,
                end: end,
                leftKind: leftKind,
                rightKind: rightKind
            ))
        }
    }

    nonisolated private static func bucketIndex(for offset: Int, total: Int, bucketCount: Int) -> Int {
        guard total > 0, bucketCount > 0 else { return 0 }
        return min(bucketCount - 1, (offset * bucketCount) / total)
    }

    nonisolated private static func updateBucketKinds(
        offset: Int,
        leftByte: UInt8?,
        rightByte: UInt8?,
        total: Int,
        bucketCount: Int,
        leftKinds: inout [DiffRegionKind],
        rightKinds: inout [DiffRegionKind]
    ) {
        let bucket = bucketIndex(for: offset, total: total, bucketCount: bucketCount)
        let kinds = diffKinds(leftByte: leftByte, rightByte: rightByte)
        if kinds.left != .equal {
            leftKinds[bucket] = maxPriority(leftKinds[bucket], kinds.left)
        }
        if kinds.right != .equal {
            rightKinds[bucket] = maxPriority(rightKinds[bucket], kinds.right)
        }
    }

    nonisolated private static func diffKinds(
        leftByte: UInt8?,
        rightByte: UInt8?
    ) -> (left: DiffRegionKind, right: DiffRegionKind) {
        let hasLeft = leftByte != nil
        let hasRight = rightByte != nil

        switch (hasLeft, hasRight) {
        case (true, false):
            return (.deleted, .equal)
        case (false, true):
            return (.equal, .added)
        case (true, true):
            guard let leftByte, let rightByte, leftByte != rightByte else {
                return (.equal, .equal)
            }
            return (.changed, .changed)
        case (false, false):
            return (.equal, .equal)
        }
    }

    nonisolated private static func maxPriority(_ current: DiffRegionKind, _ candidate: DiffRegionKind) -> DiffRegionKind {
        priority(for: candidate) > priority(for: current) ? candidate : current
    }

    nonisolated private static func priority(for kind: DiffRegionKind) -> Int {
        switch kind {
        case .changed: 3
        case .deleted, .added: 2
        case .equal: 0
        }
    }

    nonisolated private static func formatTextLine(
        offset: String,
        kind: DiffRegionKind,
        leftByte: UInt8?,
        rightByte: UInt8?
    ) -> String {
        let left = leftByte.map { HexFormatter.hexPair(for: $0) } ?? "--"
        let right = rightByte.map { HexFormatter.hexPair(for: $0) } ?? "--"
        return "0x\(offset)  \(kind.rawValue)  \(left) -> \(right)"
    }

    nonisolated private static func chunkFingerprint(_ bytes: [UInt8]) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        hash ^= UInt64(bytes.count)
        return hash
    }

    nonisolated private static func chunksDiffer(leftChunk: [UInt8], rightChunk: [UInt8]) -> Bool {
        if leftChunk.count != rightChunk.count { return true }
        return chunkFingerprint(leftChunk) != chunkFingerprint(rightChunk)
    }

    nonisolated private static func markBucketsForDiffChunk(
        chunkStart: Int,
        chunkEnd: Int,
        leftSize: Int,
        rightSize: Int,
        total: Int,
        bucketCount: Int,
        leftKinds: inout [DiffRegionKind],
        rightKinds: inout [DiffRegionKind]
    ) {
        guard chunkStart < chunkEnd, total > 0, bucketCount > 0 else { return }

        let firstBucket = bucketIndex(for: chunkStart, total: total, bucketCount: bucketCount)
        let lastOffset = max(chunkStart, chunkEnd - 1)
        let lastBucket = bucketIndex(for: lastOffset, total: total, bucketCount: bucketCount)

        for bucket in firstBucket...lastBucket {
            let bucketStart = (bucket * total) / bucketCount
            let bucketEnd = ((bucket + 1) * total) / bucketCount
            let overlapStart = max(bucketStart, chunkStart)
            let overlapEnd = min(bucketEnd, chunkEnd)

            let hasLeft = overlapStart < leftSize
            let hasRight = overlapStart < rightSize

            if hasLeft, hasRight {
                leftKinds[bucket] = maxPriority(leftKinds[bucket], .changed)
                rightKinds[bucket] = maxPriority(rightKinds[bucket], .changed)
            } else if hasLeft {
                leftKinds[bucket] = maxPriority(leftKinds[bucket], .deleted)
            } else if hasRight {
                rightKinds[bucket] = maxPriority(rightKinds[bucket], .added)
            }

            _ = overlapEnd
        }
    }

    nonisolated private static func lowerBound(in array: [Int], value: Int) -> Int {
        var low = 0
        var high = array.count
        while low < high {
            let mid = (low + high) / 2
            if array[mid] < value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    nonisolated private static func upperBound(in array: [Int], value: Int) -> Int {
        var low = 0
        var high = array.count
        while low < high {
            let mid = (low + high) / 2
            if array[mid] <= value {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
