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

enum CompareDiffExportFormat {
    case text
    case csv

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .csv: "csv"
        }
    }
}

enum ByteCompareService {
    static let defaultBucketCount = 400

    static func highlightColor(for kind: DiffRegionKind) -> HighlightColor? {
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

    static func highlightColor(
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

    static func diffKind(
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
            return side == .left ? .deleted : nil
        case (false, true):
            return side == .right ? .added : nil
        case (true, true):
            guard let leftByte, let rightByte, leftByte != rightByte else { return .equal }
            return .changed
        case (false, false):
            return .equal
        }
    }

    static func diffEntry(
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

    static func collectDiffEntries(
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

    static func collectDiffEntries(
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

    static func buildDiffIndex(
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

    static func buildDiffMap(
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

    static func formatTextReport(
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

    static func formatCSV(entries: [DiffEntry]) -> String {
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

    static func byte(at offset: Int, in size: Int, provider: (Int) -> UInt8?) -> UInt8? {
        guard offset < size else { return nil }
        return provider(offset)
    }

    private static func diffKinds(
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

    private static func maxPriority(_ current: DiffRegionKind, _ candidate: DiffRegionKind) -> DiffRegionKind {
        priority(for: candidate) > priority(for: current) ? candidate : current
    }

    private static func priority(for kind: DiffRegionKind) -> Int {
        switch kind {
        case .changed: 3
        case .deleted, .added: 2
        case .equal: 0
        }
    }

    private static func formatTextLine(
        offset: String,
        kind: DiffRegionKind,
        leftByte: UInt8?,
        rightByte: UInt8?
    ) -> String {
        let left = leftByte.map { HexFormatter.hexPair(for: $0) } ?? "--"
        let right = rightByte.map { HexFormatter.hexPair(for: $0) } ?? "--"
        return "0x\(offset)  \(kind.label)  \(left) -> \(right)"
    }
}
