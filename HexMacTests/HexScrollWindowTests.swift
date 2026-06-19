//
//  HexScrollWindowTests.swift
//  HexMacTests
//

import Testing
@testable import HexMac

struct HexScrollWindowTests {
    @Test func renderedRangeStartsAtFirstVisibleRow() {
        var window = HexScrollWindow(firstVisibleRow: 100, visibleRowCount: 10, phase: .scrolling)
        let range = window.renderedRange(for: 200)
        #expect(range.lowerBound == 100)
        #expect(range.upperBound == 134)

        window.phase = .idle
        let idleRange = window.renderedRange(for: 200)
        #expect(idleRange == range)
    }

    @Test func prefetchRangeIsWiderThanRenderedRange() {
        var window = HexScrollWindow(firstVisibleRow: 100, visibleRowCount: 10, phase: .scrolling)
        let prefetch = window.prefetchRange(for: 500)
        let rendered = window.renderedRange(for: 500)
        #expect(prefetch.lowerBound < rendered.lowerBound)
        #expect(prefetch.upperBound > rendered.upperBound)
    }

    @Test func jumpToCenter() {
        var window = HexScrollWindow(firstVisibleRow: 0, visibleRowCount: 10)
        window.jumpTo(row: 50, rowCount: 100, anchor: .center)
        #expect(window.firstVisibleRow == 45)
    }

    @Test func scrollByRespectsBounds() {
        var window = HexScrollWindow(firstVisibleRow: 0, visibleRowCount: 10)
        window.scrollBy(delta: -5, rowCount: 100)
        #expect(window.firstVisibleRow == 0)
        window.scrollBy(delta: 200, rowCount: 100)
        #expect(window.firstVisibleRow == 90)
    }

    @Test func scrollReachesFileStartAndEnd() {
        var window = HexScrollWindow(firstVisibleRow: 50, visibleRowCount: 10)
        let rowCount = 100

        window.firstVisibleRow = 0
        #expect(window.firstVisibleRow == 0)
        #expect(window.visibleRowRange(for: rowCount).lowerBound == 0)

        window.firstVisibleRow = window.maxFirstVisibleRow(for: rowCount)
        #expect(window.firstVisibleRow == 90)
        #expect(window.lastVisibleRow(for: rowCount) == 99)
    }

    @Test func visibleRowRangeAtEnd() {
        var window = HexScrollWindow(firstVisibleRow: 95, visibleRowCount: 10)
        let range = window.visibleRowRange(for: 100)
        #expect(range.lowerBound == 95)
        #expect(range.upperBound == 99)
    }

    @Test func adaptToBytesPerRowChangePreservesTopByteOffset() {
        var window = HexScrollWindow(firstVisibleRow: 12, visibleRowCount: 10)
        window.adaptToBytesPerRowChange(from: 16, to: 8, rowCount: 200)
        #expect(window.firstVisibleRow == 24)

        window.adaptToBytesPerRowChange(from: 8, to: 16, rowCount: 100)
        #expect(window.firstVisibleRow == 12)
    }
}
