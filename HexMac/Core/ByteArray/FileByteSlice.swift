//
//  FileByteSlice.swift
//  HexMac
//

import Foundation

final class FileByteSlice: ByteSlice, @unchecked Sendable {
    let file: FileReference
    let offset: UInt64
    let length: UInt64

    init(file: FileReference, offset: UInt64 = 0, length: UInt64? = nil) {
        self.file = file
        self.offset = offset
        self.length = length ?? file.length
    }

    func copyBytes(into buffer: UnsafeMutableRawPointer, range: Range<UInt64>) {
        precondition(range.upperBound <= length)
        guard !range.isEmpty else { return }
        let count = Int(range.count)
        try! file.read(into: buffer, length: count, from: offset + range.lowerBound)
    }

    func subslice(range: Range<UInt64>) -> any ByteSlice {
        precondition(range.upperBound <= length)
        if range.lowerBound == 0, range.upperBound == length { return self }
        return FileByteSlice(file: file, offset: offset + range.lowerBound, length: UInt64(range.count))
    }

    func sourceRange(for file: FileReference) -> Range<UInt64>? {
        guard self.file.isSameFile(as: file) else { return nil }
        return offset..<(offset + length)
    }

    func coalesce(with other: any ByteSlice) -> (any ByteSlice)? {
        nil
    }
}
