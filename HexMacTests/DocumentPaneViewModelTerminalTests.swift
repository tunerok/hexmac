//
//  DocumentPaneViewModelTerminalTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

@MainActor
final class DocumentPaneViewModelTerminalTests: XCTestCase {
    private func makeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HexMacVMTest-\(UUID().uuidString).bin")
        try data.write(to: url)
        return url
    }

    func testGotoUpdatesSelectionAndHistory() throws {
        let url = try makeTempFile(Data((0..<32).map { UInt8($0) }))
        defer { try? FileManager.default.removeItem(at: url) }

        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        pane.executeTerminalCommand("goto 0x10")

        XCTAssertEqual(pane.selection?.start, 16)
        XCTAssertEqual(pane.scrollTargetOffset, 16)
        XCTAssertTrue(pane.terminalHistory.contains { $0.text.contains("→ 0x") })
    }

    func testTerminalIgnoredOnComparisonPane() throws {
        let leftURL = try makeTempFile(Data([1, 2, 3]))
        let rightURL = try makeTempFile(Data([1, 2, 4]))
        defer {
            try? FileManager.default.removeItem(at: leftURL)
            try? FileManager.default.removeItem(at: rightURL)
        }

        let pane = DocumentPaneViewModel()
        pane.loadComparison(left: leftURL, right: rightURL)
        pane.executeTerminalCommand("goto 0")

        XCTAssertTrue(pane.terminalHistory.isEmpty)
    }

    func testTerminalHistoryClearedOnLoadFile() throws {
        let firstURL = try makeTempFile(Data([0, 1, 2]))
        let secondURL = try makeTempFile(Data([3, 4, 5]))
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let pane = DocumentPaneViewModel()
        pane.loadFile(from: firstURL)
        pane.executeTerminalCommand("goto 0")
        XCTAssertFalse(pane.terminalHistory.isEmpty)

        pane.loadFile(from: secondURL)
        XCTAssertTrue(pane.terminalHistory.isEmpty)
    }

    func testTerminalErrorAppendedToHistory() throws {
        let url = try makeTempFile(Data([0, 1, 2]))
        defer { try? FileManager.default.removeItem(at: url) }

        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        pane.executeTerminalCommand("not-a-command")

        XCTAssertEqual(pane.terminalHistory.count, 2)
        XCTAssertEqual(pane.terminalHistory[0].kind, .input)
        XCTAssertEqual(pane.terminalHistory[1].kind, .error)
    }

    func testSaveMarksDocumentClean() throws {
        let url = try makeTempFile(Data([0, 1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: url) }

        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        pane.beginSelection(at: 0)
        pane.endSelection(at: 0)
        pane.fillSelection(with: 0xFF)

        XCTAssertTrue(pane.isDirty)

        pane.save()

        XCTAssertFalse(pane.isDirty)
        XCTAssertEqual(pane.byte(at: 0), 0xFF)
    }
}
