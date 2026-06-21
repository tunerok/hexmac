//
//  ChunkedByteReader.swift
//  ediHex
//

import Foundation

enum ChunkedByteReader {
    nonisolated static let defaultChunkSize = 1_048_576

    nonisolated static func forEachChunk(
        in range: Range<Int>,
        chunkSize: Int = defaultChunkSize,
        overlap: Int = 0,
        bytesProvider: (Range<Int>) -> [UInt8],
        body: (_ chunk: [UInt8], _ chunkStartOffset: Int) -> Void
    ) {
        guard range.lowerBound < range.upperBound else { return }
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let readStart = cursor == range.lowerBound ? range.lowerBound : max(range.lowerBound, cursor - overlap)
            let readEnd = min(range.upperBound, cursor + chunkSize + overlap)
            let chunk = bytesProvider(readStart..<readEnd)
            body(chunk, readStart)
            cursor += chunkSize
        }
    }
}
