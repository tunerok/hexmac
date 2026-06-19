//
//  HexDocument.swift
//  HexMac
//

import Foundation

final class HexDocument {
    let url: URL
    private(set) var fileReference: FileReference
    let byteArray: BTreeByteArray

    var displayName: String {
        url.lastPathComponent
    }

    var fileSize: Int {
        let length = byteArray.length
        guard length <= UInt64(Int.max) else { return Int.max }
        return Int(length)
    }

    var isOpen: Bool {
        fileSize >= 0
    }

    private(set) var isDirty = false

    init(url: URL, fileReference: FileReference, byteArray: BTreeByteArray) {
        self.url = url
        self.fileReference = fileReference
        self.byteArray = byteArray
    }

    static func open(url: URL, readOnly: Bool = true) throws -> HexDocument {
        let fileReference = try FileReference.open(url: url, readOnly: readOnly)
        let byteArray = BTreeByteArray.fromFile(fileReference)
        return HexDocument(url: url, fileReference: fileReference, byteArray: byteArray)
    }

    func markDirty() {
        isDirty = true
    }

    func markClean() {
        isDirty = false
    }

    func close() {
        fileReference.close()
    }

    func collapseToFileBacking() {
        let length = byteArray.length
        guard length > 0 else {
            byteArray.delete(range: 0..<0)
            return
        }
        byteArray.delete(range: 0..<length)
        byteArray.insert(slice: FileByteSlice(file: fileReference), at: 0)
    }

    func replaceFileReference(with newReference: FileReference) {
        fileReference.close()
        fileReference = newReference
    }

    func byte(at offset: Int) -> UInt8? {
        guard offset >= 0 else { return nil }
        let uOffset = UInt64(offset)
        guard uOffset < byteArray.length else { return nil }
        return byteArray.byte(at: uOffset)
    }

    func bytes(in range: Range<Int>) -> [UInt8] {
        byteArray.bytes(in: UInt64ByteRange.clamp(range, to: byteArray.length))
    }

    func replaceByte(at offset: Int, with value: UInt8) -> UInt8? {
        byteArray.replaceByte(at: UInt64(offset), with: value)
    }

    func replaceBytes(in range: Range<Int>, with value: UInt8) -> [UInt8] {
        let uintRange = UInt64ByteRange.clamp(range, to: byteArray.length)
        return byteArray.replaceBytes(in: uintRange, with: value)
    }

    func appendByte(_ value: UInt8) {
        byteArray.appendByte(value)
    }

    func truncate(to offset: Int) {
        guard offset >= 0 else { return }
        byteArray.truncate(to: UInt64(offset))
    }
}
