//
//  HistogramBuilder.swift
//  HexMac
//

import Foundation

enum HistogramBuilder {
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
        var counts = Array(repeating: 0, count: 256)
        ChunkedByteReader.forEachChunk(in: range, chunkSize: chunkSize, bytesProvider: bytesProvider) { chunk, _ in
            for byte in chunk {
                counts[Int(byte)] += 1
            }
        }
        return counts
    }

    static func nonZeroEntries(in counts: [Int]) -> [(byte: Int, count: Int)] {
        counts.enumerated()
            .filter { $0.element > 0 }
            .map { (byte: $0.offset, count: $0.element) }
            .sorted { $0.count > $1.count }
    }
}
