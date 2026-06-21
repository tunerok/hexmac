//
//  MemoryByteSlice.swift
//  ediHex
//

import Foundation

final class MemoryByteSlice: ByteSlice, @unchecked Sendable {
    private static let maxTailLength = 32
    private static let maxCoalescedLength: UInt64 = 1 << 24

    private let data: Data
    private let dataOffset: Int
    private let dataLength: Int
    private let tail: [UInt8]

    nonisolated var length: UInt64 { UInt64(dataLength + tail.count) }

    init(data: Data) {
        self.data = data
        self.dataOffset = 0
        self.dataLength = data.count
        self.tail = []
    }

    init(sharedData: Data, offset: Int, length: Int, tail: [UInt8] = []) {
        precondition(offset >= 0)
        precondition(length >= 0)
        precondition(offset + length <= sharedData.count)
        precondition(tail.count <= Self.maxTailLength)
        self.data = sharedData
        self.dataOffset = offset
        self.dataLength = length
        self.tail = tail
    }

    init(singleByte value: UInt8) {
        self.data = Data()
        self.dataOffset = 0
        self.dataLength = 0
        self.tail = [value]
    }

    nonisolated func copyBytes(into buffer: UnsafeMutableRawPointer, range: Range<UInt64>) {
        precondition(range.upperBound <= length)
        guard !range.isEmpty else { return }

        var written = 0
        let dataEnd = UInt64(dataLength)
        let dataRange = range.clamped(to: 0..<dataEnd)
        if !dataRange.isEmpty {
            let count = Int(dataRange.count)
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                memcpy(buffer.advanced(by: written), base + dataOffset + Int(dataRange.lowerBound), count)
            }
            written += Int(dataRange.count)
        }

        let tailStart = max(range.lowerBound, dataEnd)
        let tailEnd = min(range.upperBound, length)
        if tailStart < tailEnd {
            let startInTail = Int(tailStart - dataEnd)
            let count = Int(tailEnd - tailStart)
            tail.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                memcpy(buffer.advanced(by: written), base + startInTail, count)
            }
        }
    }

    func subslice(range: Range<UInt64>) -> any ByteSlice {
        precondition(range.upperBound <= length)
        if range.lowerBound == 0, range.upperBound == length { return self }

        let dataEnd = UInt64(dataLength)
        let dataLower = min(max(range.lowerBound, 0), dataEnd)
        let dataUpper = min(max(range.upperBound, 0), dataEnd)
        let newDataOffset = dataOffset + Int(dataLower)
        let newDataLength = Int(dataUpper - dataLower)

        var newTail: [UInt8] = []
        let tailStart = max(range.lowerBound, dataEnd)
        let tailEnd = min(range.upperBound, length)
        if tailStart < tailEnd {
            let start = Int(tailStart - dataEnd)
            let end = start + Int(tailEnd - tailStart)
            newTail = Array(tail[start..<end])
        }

        return MemoryByteSlice(
            sharedData: data,
            offset: newDataOffset,
            length: newDataLength,
            tail: newTail
        )
    }

    func sourceRange(for file: FileReference) -> Range<UInt64>? {
        nil
    }

    func coalesce(with other: any ByteSlice) -> (any ByteSlice)? {
        guard length + other.length <= Self.maxCoalescedLength else { return nil }

        if other.length == 0 { return self }

        let spaceInTail = Self.maxTailLength - tail.count
        if other.length <= UInt64(spaceInTail) {
            var newTail = tail
            newTail.append(contentsOf: other.bytes(in: 0..<other.length))
            return MemoryByteSlice(
                sharedData: data,
                offset: dataOffset,
                length: dataLength,
                tail: newTail
            )
        }

        guard dataOffset + dataLength == data.count else { return nil }

        var newData = data
        let otherCount = Int(other.length)
        let priorLength = newData.count
        newData.count = priorLength + otherCount
        newData.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            other.copyBytes(into: base.advanced(by: priorLength), range: 0..<other.length)
        }

        return MemoryByteSlice(sharedData: newData, offset: dataOffset, length: newData.count - dataOffset, tail: [])
    }
}
