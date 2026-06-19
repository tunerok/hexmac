//
//  HexHighlightSpansTests.swift
//  HexMacTests
//

import XCTest
@testable import HexMac

final class HexHighlightSpansTests: XCTestCase {
    func testSpansForSingleHighlightInRow() {
        let highlights = [
            HexHighlight(start: 18, end: 20, color: .yellow)
        ]

        let spans = HexHighlightSpans.spans(
            for: 1,
            bytesPerRow: 16,
            fileSize: 32,
            highlights: highlights
        )

        XCTAssertEqual(spans?.count, 1)
        XCTAssertEqual(spans?[0].startColumn, 2)
        XCTAssertEqual(spans?[0].endColumn, 4)
        XCTAssertEqual(spans?[0].color, .yellow)
    }

    func testSpansMergesAdjacentSameColor() {
        let highlights = [
            HexHighlight(start: 16, end: 17, color: .green),
            HexHighlight(start: 18, end: 19, color: .green)
        ]

        let spans = HexHighlightSpans.spans(
            for: 1,
            bytesPerRow: 16,
            fileSize: 32,
            highlights: highlights
        )

        XCTAssertEqual(spans?.count, 1)
        XCTAssertEqual(spans?[0].startColumn, 0)
        XCTAssertEqual(spans?[0].endColumn, 3)
        XCTAssertEqual(spans?[0].color, .green)
    }

    func testSpansReturnsNilWhenNoOverlap() {
        let highlights = [
            HexHighlight(start: 0, end: 3, color: .red)
        ]

        let spans = HexHighlightSpans.spans(
            for: 1,
            bytesPerRow: 16,
            fileSize: 32,
            highlights: highlights
        )

        XCTAssertNil(spans)
    }
}
