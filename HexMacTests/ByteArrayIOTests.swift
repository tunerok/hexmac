//
//  ByteArrayIOTests.swift
//  HexMacTests
//

import Foundation
import Testing
@testable import HexMac

@Suite(.serialized)
struct ByteArrayIOTests {
    @Test func fileReferenceReadsAndWrites() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacByteArray-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }

        let seed = Data((0..<256).map { UInt8($0) })
        try seed.write(to: url)

        let readOnly = try FileReference.open(url: url, readOnly: true)
        defer { readOnly.close() }
        #expect(readOnly.length == 256)

        var buffer = [UInt8](repeating: 0, count: 16)
        try readOnly.read(
            into: buffer.withUnsafeMutableBytes { $0.baseAddress! },
            length: 16,
            from: 240
        )
        #expect(buffer == (240..<256).map { UInt8($0) })

        let writable = try FileReference.open(url: url, readOnly: false)
        defer { writable.close() }
        var patch: UInt8 = 0xAB
        try writable.write(
            from: &patch,
            length: 1,
            to: 10
        )
        let verify = try FileReference.open(url: url, readOnly: true)
        defer { verify.close() }
        #expect(try verify.byteSlice(at: 10) == 0xAB)
    }

    @Test func memorySliceCoalescesAppend() {
        let first = MemoryByteSlice(data: Data([1, 2, 3]))
        let second = MemoryByteSlice(singleByte: 4)
        let merged = first.coalesce(with: second)
        #expect(merged != nil)
        #expect(merged?.length == 4)
        #expect(merged?.byte(at: 3) == 4)
    }

    @Test func btreeStoresAndReadsBytes() {
        let array = BTreeByteArray()
        array.insert(slice: MemoryByteSlice(data: Data([0x10, 0x20, 0x30])), at: 0)
        array.insert(slice: MemoryByteSlice(data: Data([0xAA, 0xBB])), at: 1)

        #expect(array.length == 5)
        #expect(array.byte(at: 0) == 0x10)
        #expect(array.byte(at: 1) == 0xAA)
        #expect(array.bytes(in: 0..<5) == [0x10, 0xAA, 0xBB, 0x20, 0x30])
    }

    @Test func btreeReplaceAndDelete() {
        let array = BTreeByteArray()
        array.insert(slice: MemoryByteSlice(data: Data([1, 2, 3, 4])), at: 0)
        #expect(array.replaceByte(at: 1, with: 9) == 2)
        #expect(array.bytes(in: 0..<4) == [1, 9, 3, 4])

        array.delete(range: 1..<3)
        #expect(array.bytes(in: 0..<array.length) == [1, 4])
    }

    @Test func btreeRandomEdits() {
        let array = BTreeByteArray()
        array.insert(slice: MemoryByteSlice(data: Data(repeating: 0, count: 100)), at: 0)

        for index in 0..<1000 {
            let offset = UInt64(index % 100)
            _ = array.replaceByte(at: offset, with: UInt8(index & 0xFF))
        }

        #expect(array.length == 100)
    }

    @Test func saveRewritesEditedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacSave-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data([0, 1, 2, 3, 4]).write(to: url)
        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        _ = array.replaceByte(at: 2, with: 0xFF)
        try ByteArrayWriter.write(array, to: url)

        let saved = try FileReference.open(url: url, readOnly: true)
        defer { saved.close() }
        let slice = FileByteSlice(file: saved)
        #expect(slice.bytes(in: 0..<saved.length) == [0, 1, 0xFF, 3, 4])
    }

    @Test func createNewFileWritesSingleZeroByte() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacNew-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data([0x00]).write(to: url)

        let file = try FileReference.open(url: url, readOnly: true)
        defer { file.close() }
        #expect(file.length == 1)
        #expect(try file.byteSlice(at: 0) == 0x00)

        let document = try HexDocument.open(url: url, readOnly: false)
        defer { document.close() }
        #expect(document.fileSize == 1)
        #expect(document.byte(at: 0) == 0x00)
    }

    @Test func saveAfterModifyWritesCorrectBytes() throws {
        let insertURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacInsert-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: insertURL) }

        try Data([0, 1, 2, 3]).write(to: insertURL)
        let insertFile = try FileReference.open(url: insertURL, readOnly: false)
        let insertArray = BTreeByteArray.fromFile(insertFile)
        insertArray.insert(slice: MemoryByteSlice(data: Data([0xAA])), at: 2)
        try ByteArrayWriter.write(insertArray, to: insertURL)
        #expect(try Data(contentsOf: insertURL) == Data([0, 1, 0xAA, 2, 3]))

        let appendURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacAppend-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: appendURL) }

        try Data([0x10, 0x20]).write(to: appendURL)
        let appendFile = try FileReference.open(url: appendURL, readOnly: false)
        let appendArray = BTreeByteArray.fromFile(appendFile)
        appendArray.insert(slice: MemoryByteSlice(data: Data([0xDD, 0xEE])), at: appendArray.length)
        try ByteArrayWriter.write(appendArray, to: appendURL)
        #expect(try Data(contentsOf: appendURL) == Data([0x10, 0x20, 0xDD, 0xEE]))

        let deleteURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacDelete-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: deleteURL) }

        try Data([0, 1, 2, 3, 4]).write(to: deleteURL)
        let deleteFile = try FileReference.open(url: deleteURL, readOnly: false)
        let deleteArray = BTreeByteArray.fromFile(deleteFile)
        deleteArray.delete(range: 1..<3)
        try ByteArrayWriter.write(deleteArray, to: deleteURL)
        #expect(try Data(contentsOf: deleteURL) == Data([0, 3, 4]))
    }
}

private extension FileReference {
    func byteSlice(at offset: UInt64) throws -> UInt8 {
        var value: UInt8 = 0
        try read(into: &value, length: 1, from: offset)
        return value
    }
}
