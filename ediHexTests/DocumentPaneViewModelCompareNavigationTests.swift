//
//  DocumentPaneViewModelCompareNavigationTests.swift
//  ediHexTests
//

import AppKit
import Foundation
import Testing
@testable import ediHex

@Suite(.serialized)
@MainActor
struct DocumentPaneViewModelCompareNavigationTests {
    private func makeTempFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ediHexCompare-\(UUID().uuidString).bin")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func ensureTestApplication() {
        if NSApp == nil {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
        }
    }

    private func waitForDiffMapCompletion(_ pane: DocumentPaneViewModel, timeoutMs: Int = 10000) async throws {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMs)
        while ContinuousClock.now < deadline {
            if !pane.isDiffMapLoading, pane.comparisonDiffChunkIndex != nil {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("Compare diff map did not complete within timeout")
    }

    @Test func diffNavigationWrapsAround() async throws {
        ensureTestApplication()

        let chunkSize = ChunkedByteReader.defaultChunkSize
        let fileSize = chunkSize * 2
        var left = Array(repeating: UInt8(0x00), count: fileSize)
        var right = Array(repeating: UInt8(0x00), count: fileSize)
        right[1] = 0xFF
        right[chunkSize + 1] = 0xFF

        let leftURL = try makeTempFile(Data(left))
        let rightURL = try makeTempFile(Data(right))
        defer {
            try? FileManager.default.removeItem(at: leftURL)
            try? FileManager.default.removeItem(at: rightURL)
        }

        let pane = DocumentPaneViewModel()
        pane.loadComparison(left: leftURL, right: rightURL)

        try await waitForDiffMapCompletion(pane)

        #expect(pane.comparisonHasDifferences)
        #expect(pane.canNavigateNextDiff)
        #expect(pane.canNavigatePreviousDiff)
        #expect(pane.comparisonDiffChunkIndex?.diffChunkStarts == [0, chunkSize])

        #expect(pane.navigateToNextDiff())
        #expect(pane.comparisonCurrentDiffOffset == 1)

        #expect(pane.navigateToNextDiff())
        #expect(pane.comparisonCurrentDiffOffset == chunkSize + 1)

        #expect(pane.navigateToPreviousDiff())
        #expect(pane.comparisonCurrentDiffOffset == 1)

        #expect(pane.navigateToPreviousDiff())
        #expect(pane.comparisonCurrentDiffOffset == chunkSize + 1)
    }
}
