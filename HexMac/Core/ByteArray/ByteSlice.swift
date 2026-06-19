//
//  ByteSlice.swift
//  HexMac
//

import Foundation

protocol ByteSlice: AnyObject, Sendable {
    var length: UInt64 { get }
    func copyBytes(into buffer: UnsafeMutableRawPointer, range: Range<UInt64>)
    func subslice(range: Range<UInt64>) -> any ByteSlice
    func sourceRange(for file: FileReference) -> Range<UInt64>?
    func coalesce(with other: any ByteSlice) -> (any ByteSlice)?
}

final class SliceBox: @unchecked Sendable {
    let slice: any ByteSlice

    var length: UInt64 { slice.length }

    init(_ slice: any ByteSlice) {
        self.slice = slice
    }
}

extension ByteSlice {
    func bytes(in range: Range<UInt64>) -> [UInt8] {
        let count = Int(range.count)
        guard count > 0 else { return [] }
        var result = [UInt8](repeating: 0, count: count)
        result.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            copyBytes(into: base, range: range)
        }
        return result
    }

    func byte(at offset: UInt64) -> UInt8 {
        var value: UInt8 = 0
        withUnsafeMutableBytes(of: &value) { buffer in
            guard let base = buffer.baseAddress else { return }
            copyBytes(into: base, range: offset..<(offset + 1))
        }
        return value
    }
}
