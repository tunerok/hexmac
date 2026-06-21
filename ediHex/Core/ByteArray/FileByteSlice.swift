//
//  FileByteSlice.swift
//  ediHex
//

import Foundation

final class FileByteSlice: ByteSlice, @unchecked Sendable {
    let file: FileReference
    let offset: UInt64
    private let byteLength: UInt64

    nonisolated var length: UInt64 { byteLength }

    init(file: FileReference, offset: UInt64 = 0, length: UInt64? = nil) {
        self.file = file
        self.offset = offset
        self.byteLength = length ?? file.length
    }

    nonisolated func copyBytes(into buffer: UnsafeMutableRawPointer, range: Range<UInt64>) {
        precondition(range.upperBound <= byteLength)
        guard !range.isEmpty else { return }
        let count = Int(range.count)
        do {
            try file.read(into: buffer, length: count, from: offset + range.lowerBound)
        } catch {
            // Caller pre-fills with zeros; avoid crashing on concurrent close or I/O errors.
        }
    }

    func subslice(range: Range<UInt64>) -> any ByteSlice {
        precondition(range.upperBound <= byteLength)
        if range.lowerBound == 0, range.upperBound == byteLength { return self }
        return FileByteSlice(file: file, offset: offset + range.lowerBound, length: UInt64(range.count))
    }

    func sourceRange(for file: FileReference) -> Range<UInt64>? {
        guard self.file.isSameFile(as: file) else { return nil }
        return offset..<(offset + byteLength)
    }

    func coalesce(with other: any ByteSlice) -> (any ByteSlice)? {
        nil
    }
}
