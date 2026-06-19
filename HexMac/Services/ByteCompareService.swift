//
//  ByteCompareService.swift
//  HexMac
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

struct CompareRowContext {
    let leftBytes: [UInt8]
    let rightBytes: [UInt8]
    let leftHighlights: [HighlightColor?]
    let rightHighlights: [HighlightColor?]
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

    nonisolated static func rowHighlights(
        leftBytes: [UInt8],
        rightBytes: [UInt8],
        rowOffset: Int,
        leftSize: Int,
        rightSize: Int,
        side: CompareSide
    ) -> [HighlightColor?] {
        let count = max(leftBytes.count, rightBytes.count)
        guard count > 0 else { return [] }

        return (0..<count).map { index in
            let offset = rowOffset + index
            let leftByte: UInt8? = offset < leftSize && index < leftBytes.count ? leftBytes[index] : nil
            let rightByte: UInt8? = offset < rightSize && index < rightBytes.count ? rightBytes[index] : nil
            return highlightColor(
                at: offset,
                side: side,
                leftSize: leftSize,
                rightSize: rightSize,
                leftByte: leftByte,
                rightByte: rightByte
            )
        }
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
            let leftRange = cursor..<min(leftSize, chunkEnd)
            let rightRange = cursor..<min(rightSize, chunkEnd)
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

    nonisolated static func formatTextReport(
        entries: [DiffEntry],
        leftName: String,
        rightName: String
    ) -> String {
        var lines: [String] = [
            "HexMac Compare Report",
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
}
