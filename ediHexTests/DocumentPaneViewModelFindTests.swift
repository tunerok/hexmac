//
//  DocumentPaneViewModelFindTests.swift
//  ediHexTests
//

import AppKit
import Foundation
import Testing
@testable import ediHex

@Suite(.serialized)
@MainActor
struct DocumentPaneViewModelFindTests {
    private func makeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ediHexFind-\(UUID().uuidString).bin")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makePaneWithFile(_ data: Data) throws -> (DocumentPaneViewModel, URL) {
        ensureTestApplication()
        let url = try makeTempFile(data)
        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        #expect(pane.isDocumentOpen)
        return (pane, url)
    }

    private func ensureTestApplication() {
        if NSApp == nil {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
        }
    }

    private func waitForFindCompletion(_ pane: DocumentPaneViewModel, timeoutMs: Int = 5000) async throws {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMs)
        while ContinuousClock.now < deadline {
            if pane.findSession?.isScanningComplete == true, !pane.isFindLoading {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("Find did not complete within timeout")
    }

    private func sampleSession(matches: [Int] = [0, 4, 8], currentIndex: Int = 0) -> FindSession {
        FindSession(
            queryText: "01 02",
            pattern: [0x01, 0x02],
            mode: .hex,
            entireFile: true,
            direction: .down,
            matches: matches,
            currentIndex: currentIndex,
            isScanningComplete: true
        )
    }

    @Test func findSessionParametersDescriptionEntireFileHex() {
        let session = sampleSession()
        #expect(session.parametersDescription.contains("Hex"))
        #expect(session.entireFile)
    }

    @Test func findSessionParametersDescriptionFromCursorDown() {
        let session = FindSession(
            queryText: "hello",
            pattern: Array("hello".utf8),
            mode: .ascii,
            entireFile: false,
            direction: .down,
            matches: [10],
            currentIndex: 0
        )
        #expect(session.parametersDescription.contains("ASCII"))
        #expect(!session.entireFile)
    }

    @Test func findSessionResultsSummary() {
        #expect(sampleSession().resultsSummary.contains("3"))
        #expect(sampleSession(matches: []).resultsSummary == String(localized: "Not found"))

        var stopped = sampleSession()
        stopped.isScanningComplete = false
        #expect(stopped.resultsSummary.contains("scan stopped"))
    }

    @Test func closeFindSheetPreservesSession() async throws {
        let data = Data([0x01, 0x02, 0x00, 0x01, 0x02, 0x00])
        let (pane, url) = try makePaneWithFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.startFind(input: "01 02", mode: .hex, entireFile: true, direction: .down)
        try await waitForFindCompletion(pane)
        pane.showFindSheet = true

        pane.closeFindSheet()

        #expect(!pane.showFindSheet)
        #expect(pane.findSession?.queryText == "01 02")
        #expect(pane.findSession?.matches.count == 2)
    }

    @Test func closeFindSheetMarksPartialScanComplete() async throws {
        let data = Data(repeating: 0x01, count: 512 * 1024)
        let (pane, url) = try makePaneWithFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.startFind(input: "01", mode: .hex, entireFile: true, direction: .down)

        for _ in 0..<100 {
            if pane.findSession != nil, pane.isFindLoading {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(pane.findSession != nil)
        pane.closeFindSheet()

        #expect(pane.findSession?.isScanningComplete == true)
    }

    @Test func clearFindResultsRemovesSession() async throws {
        let data = Data([0x01, 0x02, 0x00, 0x01, 0x02])
        let (pane, url) = try makePaneWithFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.startFind(input: "01 02", mode: .hex, entireFile: true, direction: .down)
        try await waitForFindCompletion(pane)

        pane.clearFindResults()

        #expect(pane.findSession == nil)
    }

    @Test func canFindPreviousAndNext() async throws {
        let data = Data([0x01, 0x02, 0x00, 0x01, 0x02, 0x00, 0x01, 0x02])
        let (pane, url) = try makePaneWithFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.startFind(input: "01 02", mode: .hex, entireFile: true, direction: .down)
        try await waitForFindCompletion(pane)

        #expect(pane.canFindNext)
        #expect(!pane.canFindPrevious)

        _ = pane.findNextMatch()
        #expect(pane.canFindPrevious)
        #expect(pane.canFindNext)

        _ = pane.findNextMatch()
        #expect(pane.canFindPrevious)
        #expect(!pane.canFindNext)
    }

    @Test func findPreviousAndNextNavigate() async throws {
        let data = Data([0x01, 0x02, 0x00, 0x01, 0x02, 0x00, 0x01, 0x02])
        let (pane, url) = try makePaneWithFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        pane.startFind(input: "01 02", mode: .hex, entireFile: true, direction: .down)
        try await waitForFindCompletion(pane)

        _ = pane.findNextMatch()
        #expect(pane.selectedOffset == 3)

        _ = pane.findPreviousMatch()
        #expect(pane.selectedOffset == 0)
    }
}
