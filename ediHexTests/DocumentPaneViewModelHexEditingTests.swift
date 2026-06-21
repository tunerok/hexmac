//
//  DocumentPaneViewModelHexEditingTests.swift
//  ediHexTests
//

import AppKit
import Foundation
import Testing
@testable import ediHex

@Suite(.serialized)
@MainActor
struct DocumentPaneViewModelHexEditingTests {
    private func makeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ediHexHexEdit-\(UUID().uuidString).bin")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makePaneWithFile(_ data: Data) throws -> (DocumentPaneViewModel, URL) {
        ensureTestApplication()
        let url = try makeTempFile(data)
        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        #expect(pane.isDocumentOpen, "loadFile failed: \(pane.errorMessage ?? "unknown error")")
        return (pane, url)
    }

    private func ensureTestApplication() {
        if NSApp == nil {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
        }
    }

    private func typePair(_ pane: DocumentPaneViewModel, high: Character, low: Character) {
        pane.typeHexDigit(high)
        pane.typeHexDigit(low)
    }

    @Test func repeatedDigitPairsOverwriteSequentialBytesOnExistingFile() throws {
        let seed = Data((0..<32).map { UInt8($0) })
        let (pane, url) = try makePaneWithFile(seed)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)

        for _ in 0..<8 {
            typePair(pane, high: "1", low: "1")
        }

        #expect(pane.fileSize == 32)
        #expect(pane.isDirty)
        for index in 0..<8 {
            #expect(pane.byte(at: index) == 0x11)
        }
        for index in 8..<32 {
            #expect(pane.byte(at: index) == UInt8(index))
        }
    }

    @Test func pngLikeHeaderRepeatedOnesThenFives() throws {
        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let seed = Data(header + Array(repeating: 0xAA, count: 96))
        let (pane, url) = try makePaneWithFile(seed)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)

        for _ in 0..<6 {
            typePair(pane, high: "1", low: "1")
        }
        for _ in 0..<2 {
            typePair(pane, high: "5", low: "5")
        }

        #expect(pane.fileSize == 104)
        #expect(pane.bytes(in: 0..<6) == Array(repeating: 0x11, count: 6))
        #expect(pane.bytes(in: 6..<8) == [0x55, 0x55])

        var expected = Data(Array(repeating: 0x11, count: 6) + [0x55, 0x55])
        expected.append(contentsOf: seed.suffix(from: 8))
        #expect(pane.bytes(in: 0..<104) == Array(expected))

        pane.save()
        #expect(try Data(contentsOf: url) == expected)
    }

    @Test func noOpCommitAdvancesCursor() throws {
        let (pane, url) = try makePaneWithFile(Data([0x11, 0x22, 0x33]))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)
        typePair(pane, high: "1", low: "1")

        #expect(pane.byte(at: 0) == 0x11)
        #expect(pane.byte(at: 1) == 0x22)
        #expect(!pane.isDirty)
        #expect(pane.selection?.start == 1)
        #expect(pane.editingOffset == 1)
    }

    @Test func repeatedSameValuePairsAdvanceThroughBytes() throws {
        let (pane, url) = try makePaneWithFile(Data([0x11, 0x11, 0x11, 0x33]))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)

        for _ in 0..<3 {
            typePair(pane, high: "1", low: "1")
        }

        #expect(pane.byte(at: 0) == 0x11)
        #expect(pane.byte(at: 1) == 0x11)
        #expect(pane.byte(at: 2) == 0x11)
        #expect(!pane.isDirty)
        #expect(pane.selection?.start == 3)
        #expect(pane.editingOffset == 3)
    }

    @Test func appendAfterLastByteEntersAppendMode() throws {
        let (pane, url) = try makePaneWithFile(Data([0x00, 0x01, 0x02]))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 2)
        pane.endSelection(at: 2)
        typePair(pane, high: "A", low: "A")

        #expect(pane.fileSize == 3)
        #expect(pane.byte(at: 2) == 0xAA)
        #expect(pane.editingOffset == 3)
        #expect(pane.selection?.start == 2)
    }

    @Test func appendAfterLastByteGrowsFileOnFirstNibble() throws {
        let (pane, url) = try makePaneWithFile(Data([0x00, 0x01, 0x02]))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 2)
        pane.endSelection(at: 2)
        typePair(pane, high: "A", low: "A")
        pane.typeHexDigit("1")

        #expect(pane.fileSize == 4)
        #expect(pane.byte(at: 2) == 0xAA)
        #expect(pane.byte(at: 3) == 0x00)
        #expect(pane.editingOffset == 3)
        #expect(pane.editingHexText == "1")
    }

    @Test func sequentialAppendAddsBytes() throws {
        let (pane, url) = try makePaneWithFile(Data([0x00, 0x01, 0x02]))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 2)
        pane.endSelection(at: 2)
        typePair(pane, high: "A", low: "A")
        typePair(pane, high: "B", low: "B")

        #expect(pane.fileSize == 4)
        #expect(pane.byte(at: 2) == 0xAA)
        #expect(pane.byte(at: 3) == 0xBB)
        #expect(pane.editingOffset == 4)
        #expect(pane.selection?.start == 3)
    }

    @Test func appendCrossesRowBoundary() throws {
        let (pane, url) = try makePaneWithFile(Data(repeating: 0x00, count: 16))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 15)
        pane.endSelection(at: 15)
        typePair(pane, high: "F", low: "F")
        typePair(pane, high: "1", low: "0")

        #expect(pane.fileSize == 17)
        #expect(pane.rowCount == 2)
        #expect(pane.byte(at: 15) == 0xFF)
        #expect(pane.byte(at: 16) == 0x10)
    }

    @Test func saveAfterRepeatedHexTypingPersistsExactBytes() throws {
        let (pane, url) = try makePaneWithFile(Data(repeating: 0x00, count: 16))
        defer { try? FileManager.default.removeItem(at: url) }

        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)

        for _ in 0..<8 {
            typePair(pane, high: "1", low: "1")
        }

        pane.save()

        let expected = Data(repeating: 0x11, count: 8) + Data(repeating: 0x00, count: 8)
        #expect(try Data(contentsOf: url) == expected)
        #expect(!pane.isDirty)
    }
}
