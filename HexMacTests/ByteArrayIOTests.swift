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

    @Test func fileReferenceRejectsMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacMissing-\(UUID().uuidString).bin")
        #expect(throws: ByteArrayError.openFailed) {
            _ = try FileReference.open(url: url, readOnly: true)
        }
    }

    @Test func fileReferenceRejectsReadPastEOF() throws {
        let url = try makeTempFile(Data([1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: true)
        defer { file.close() }

        var buffer = [UInt8](repeating: 0, count: 2)
        #expect(throws: ByteArrayError.outOfBounds) {
            try file.read(
                into: buffer.withUnsafeMutableBytes { $0.baseAddress! },
                length: 2,
                from: 2
            )
        }
    }

    @Test func fileReferenceRejectsWriteWhenReadOnly() throws {
        let url = try makeTempFile(Data([1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: true)
        defer { file.close() }

        var patch: UInt8 = 0xFF
        #expect(throws: ByteArrayError.writeProtected) {
            try file.write(from: &patch, length: 1, to: 0)
        }
        #expect(throws: ByteArrayError.writeProtected) {
            try file.setLength(1)
        }
    }

    @Test func fileReferenceReadsEmptyFile() throws {
        let url = try makeTempFile(Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: true)
        defer { file.close() }
        #expect(file.length == 0)
    }

    @Test func fileReferenceIsSameFile() throws {
        let url = try makeTempFile(Data([0xAA]))
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try FileReference.open(url: url, readOnly: true)
        let second = try FileReference.open(url: url, readOnly: true)
        defer {
            first.close()
            second.close()
        }

        #expect(first.isSameFile(as: second))

        let otherURL = try makeTempFile(Data([0xBB]))
        defer { try? FileManager.default.removeItem(at: otherURL) }
        let other = try FileReference.open(url: otherURL, readOnly: true)
        defer { other.close() }
        #expect(!first.isSameFile(as: other))
    }

    @Test func fileReferenceSetLengthTruncatesAndGrows() throws {
        let url = try makeTempFile(Data([1, 2, 3, 4, 5]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        defer { file.close() }

        try file.setLength(2)
        #expect(file.length == 2)
        #expect(try readFileData(url) == Data([1, 2]))

        try file.setLength(4)
        #expect(file.length == 4)
        let grown = try readFileData(url)
        #expect(grown.count == 4)
        #expect(grown[0] == 1)
        #expect(grown[1] == 2)
    }

    @Test func saveWithoutEditsPreservesFile() throws {
        let seed = Data((0..<8).map { UInt8($0) })
        let url = try makeTempFile(seed)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        try ByteArrayWriter.write(array, to: url)

        #expect(try readFileData(url) == seed)
    }

    @Test func saveTruncatesFile() throws {
        let url = try makeTempFile(Data((0..<10).map { UInt8($0) }))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        array.delete(range: 3..<10)
        try ByteArrayWriter.write(array, to: url)

        #expect(try readFileData(url) == Data([0, 1, 2]))
    }

    @Test func saveGrowsFile() throws {
        let url = try makeTempFile(Data([0x10, 0x20]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        array.insert(slice: MemoryByteSlice(data: Data([0xDD, 0xEE, 0xFF])), at: array.length)
        try ByteArrayWriter.write(array, to: url)

        #expect(try readFileData(url) == Data([0x10, 0x20, 0xDD, 0xEE, 0xFF]))
    }

    @Test func saveInternalMove() throws {
        let seed = Data((0..<16).map { UInt8($0) })
        let url = try makeTempFile(seed)
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        array.delete(range: 4..<8)
        array.insert(slice: MemoryByteSlice(data: Data([4, 5, 6, 7])), at: array.length)
        try ByteArrayWriter.write(array, to: url)

        let expected = Data([0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15, 4, 5, 6, 7])
        #expect(try readFileData(url) == expected)
    }

    @Test func saveAfterDeleteAll() throws {
        let url = try makeTempFile(Data([1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        array.delete(range: 0..<array.length)
        try ByteArrayWriter.write(array, to: url)

        #expect(try readFileData(url) == Data())
    }

    @Test func saveCancellationThrows() throws {
        let url = try makeTempFile(Data([0, 1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: url) }

        let file = try FileReference.open(url: url, readOnly: false)
        let array = BTreeByteArray.fromFile(file)
        _ = array.replaceByte(at: 0, with: 0xFF)

        var progress = ByteArrayWriteProgress()
        progress.isCancelled = true

        #expect(throws: ByteArrayError.saveFailed) {
            try ByteArrayWriter.write(array, to: url, progress: progress)
        }
    }
}

@Suite(.serialized)
struct HexDocumentTests {
    @Test func documentOpenAndClose() throws {
        let url = try makeTempFile(Data([0x10, 0x20, 0x30]))
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try HexDocument.open(url: url, readOnly: false)
        defer { document.close() }

        #expect(document.fileSize == 3)
        #expect(document.byte(at: 0) == 0x10)
        #expect(document.byte(at: 2) == 0x30)
    }

    @Test func documentMarkDirtyAndClean() throws {
        let url = try makeTempFile(Data([0x00]))
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try HexDocument.open(url: url, readOnly: false)
        defer { document.close() }

        #expect(!document.isDirty)
        document.markDirty()
        #expect(document.isDirty)
        document.markClean()
        #expect(!document.isDirty)
    }

    @Test func documentCollapseToFileBacking() throws {
        let url = try makeTempFile(Data([0, 1, 2, 3, 4]))
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try HexDocument.open(url: url, readOnly: false)
        defer { document.close() }

        _ = document.replaceByte(at: 2, with: 0xFF)
        try ByteArrayWriter.write(document.byteArray, to: url)
        document.collapseToFileBacking()

        #expect(document.byte(at: 2) == 0xFF)
        #expect(try readFileData(url) == Data([0, 1, 0xFF, 3, 4]))
    }

    @Test func documentTruncate() throws {
        let url = try makeTempFile(Data([0, 1, 2, 3, 4]))
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try HexDocument.open(url: url, readOnly: false)
        defer { document.close() }

        document.truncate(to: 2)
        #expect(document.fileSize == 2)
        #expect(document.bytes(in: 0..<2) == [0, 1])
    }
}

private func makeTempFile(_ data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("HexMacTest-\(UUID().uuidString).bin")
    try data.write(to: url)
    return url
}

private func readFileData(_ url: URL) throws -> Data {
    try Data(contentsOf: url)
}

private extension FileReference {
    func byteSlice(at offset: UInt64) throws -> UInt8 {
        var value: UInt8 = 0
        try read(into: &value, length: 1, from: offset)
        return value
    }
}
