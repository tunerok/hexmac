//
//  HistogramBuilder.swift
//  ediHex
//

import Foundation

enum HistogramBuilder {
    nonisolated static let progressChunkSize = 262_144

    static func build(from bytes: [UInt8]) -> [Int] {
        var counts = Array(repeating: 0, count: 256)
        for byte in bytes {
            counts[Int(byte)] += 1
        }
        return counts
    }

    static func build(
        in range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize
    ) -> [Int] {
        buildIncremental(
            in: range,
            bytesProvider: bytesProvider,
            chunkSize: chunkSize,
            onChunk: nil
        )
    }

    static func buildIncremental(
        in range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        onChunk: ((_ counts: [Int], _ progress: Double) -> Void)? = nil
    ) -> [Int] {
        let totalBytes = range.count
        guard totalBytes > 0 else {
            let counts = Array(repeating: 0, count: 256)
            onChunk?(counts, 1)
            return counts
        }

        var counts = Array(repeating: 0, count: 256)
        var processedBytes = 0

        onChunk?(counts, 0)

        ChunkedByteReader.forEachChunk(in: range, chunkSize: chunkSize, bytesProvider: bytesProvider) { chunk, chunkStart in
            accumulate(chunk, into: &counts)
            processedBytes = chunkStart + chunk.count - range.lowerBound
            let progress = Double(processedBytes) / Double(totalBytes)
            onChunk?(counts, progress)
        }

        return counts
    }

    static func buildIncremental(
        in range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8],
        chunkSize: Int = ChunkedByteReader.defaultChunkSize,
        onChunk: ((_ counts: [Int], _ progress: Double) async -> Void)? = nil
    ) async -> [Int] {
        let totalBytes = range.count
        guard totalBytes > 0 else {
            let counts = Array(repeating: 0, count: 256)
            await onChunk?(counts, 1)
            return counts
        }

        var counts = Array(repeating: 0, count: 256)
        var cursor = range.lowerBound

        await onChunk?(counts, 0)

        while cursor < range.upperBound {
            let readEnd = min(range.upperBound, cursor + chunkSize)
            let chunk = bytesProvider(cursor..<readEnd)
            accumulate(chunk, into: &counts)
            let processedBytes = readEnd - range.lowerBound
            let progress = Double(processedBytes) / Double(totalBytes)
            await onChunk?(counts, progress)
            cursor += chunkSize
        }

        return counts
    }

    static func nonZeroEntries(in counts: [Int]) -> [(byte: Int, count: Int)] {
        counts.enumerated()
            .filter { $0.element > 0 }
            .map { (byte: $0.offset, count: $0.element) }
            .sorted { $0.count > $1.count }
    }

    private static func accumulate(_ chunk: [UInt8], into counts: inout [Int]) {
        chunk.withUnsafeBufferPointer { buffer in
            for byte in buffer {
                counts[Int(byte)] += 1
            }
        }
    }
}
