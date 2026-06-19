//
//  HexScrollWindow.swift
//  HexMac
//

import Foundation

enum HexScrollPhase: Equatable {
    case idle
    case scrolling
}

struct HexScrollWindow: Equatable {
    static let renderOverscan = 24
    static let prefetchMargin = 96

    var firstVisibleRow: Int = 0
    var visibleRowCount: Int = 1
    var phase: HexScrollPhase = .idle

    var windowRowCount: Int {
        max(1, visibleRowCount + 2 * Self.renderOverscan)
    }

    func maxFirstVisibleRow(for rowCount: Int) -> Int {
        guard rowCount > 0 else { return 0 }
        return max(0, rowCount - visibleRowCount)
    }

    func renderedRange(for rowCount: Int) -> Range<Int> {
        guard rowCount > 0 else { return 0..<0 }
        let overscan = Self.renderOverscan
        let start = min(max(0, firstVisibleRow), rowCount - 1)
        let end = min(rowCount, firstVisibleRow + visibleRowCount + overscan)
        guard start < end else { return start..<start }
        return start..<end
    }

    func prefetchRange(for rowCount: Int) -> Range<Int> {
        guard rowCount > 0 else { return 0..<0 }
        let start = max(0, firstVisibleRow - Self.prefetchMargin)
        let end = min(rowCount, firstVisibleRow + visibleRowCount + Self.prefetchMargin)
        guard start < end else { return start..<start }
        return start..<end
    }

    func visibleRowRange(for rowCount: Int) -> ClosedRange<Int> {
        guard rowCount > 0 else { return 0...0 }
        let end = min(rowCount - 1, firstVisibleRow + max(0, visibleRowCount - 1))
        return firstVisibleRow...max(firstVisibleRow, end)
    }

    func lastVisibleRow(for rowCount: Int) -> Int {
        visibleRowRange(for: rowCount).upperBound
    }

    mutating func updateVisibleRowCount(_ count: Int) {
        let clamped = max(1, count)
        guard clamped != visibleRowCount else { return }
        visibleRowCount = clamped
    }

    mutating func beginScrolling() {
        phase = .scrolling
    }

    mutating func endScrolling() {
        phase = .idle
    }

    mutating func scrollBy(delta deltaRows: Int, rowCount: Int) {
        guard deltaRows != 0, rowCount > 0 else { return }
        let maxRow = maxFirstVisibleRow(for: rowCount)
        firstVisibleRow = min(max(0, firstVisibleRow + deltaRows), maxRow)
    }

    mutating func jumpTo(row: Int, rowCount: Int, anchor: HexScrollAnchor = .top) {
        guard rowCount > 0 else {
            firstVisibleRow = 0
            return
        }
        let clampedRow = min(max(0, row), rowCount - 1)
        let target: Int
        switch anchor {
        case .top:
            target = clampedRow
        case .center:
            target = clampedRow - visibleRowCount / 2
        }
        firstVisibleRow = min(max(0, target), maxFirstVisibleRow(for: rowCount))
    }

    mutating func revealRow(_ row: Int, rowCount: Int) {
        guard rowCount > 0 else {
            firstVisibleRow = 0
            return
        }
        let clampedRow = min(max(0, row), rowCount - 1)
        let lastVisible = lastVisibleRow(for: rowCount)
        if clampedRow < firstVisibleRow {
            firstVisibleRow = clampedRow
        } else if clampedRow > lastVisible {
            firstVisibleRow = clampedRow - visibleRowCount + 1
            clamp(for: rowCount)
        }
    }

    mutating func jumpToOffset(_ offset: Int, bytesPerRow: Int, rowCount: Int, anchor: HexScrollAnchor) {
        guard bytesPerRow > 0 else { return }
        jumpTo(row: offset / bytesPerRow, rowCount: rowCount, anchor: anchor)
    }

    /// Keeps the top of the viewport on the same byte offset when bytes-per-row changes.
    mutating func adaptToBytesPerRowChange(from oldBytesPerRow: Int, to newBytesPerRow: Int, rowCount: Int) {
        guard oldBytesPerRow > 0, newBytesPerRow > 0, oldBytesPerRow != newBytesPerRow else { return }
        let topByteOffset = firstVisibleRow * oldBytesPerRow
        firstVisibleRow = topByteOffset / newBytesPerRow
        clamp(for: rowCount)
    }

    mutating func clamp(for rowCount: Int) {
        firstVisibleRow = min(max(0, firstVisibleRow), maxFirstVisibleRow(for: rowCount))
    }
}

enum HexScrollAnchor {
    case top
    case center
}

#if DEBUG
import os

enum HexScrollLog {
    private static let logger = Logger(subsystem: "HexMac", category: "Scroll")

    static func windowState(
        _ window: HexScrollWindow,
        rowCount: Int,
        event: String
    ) {
        let range = window.renderedRange(for: rowCount)
        let materialized = range.count
        logger.info(
            "\(event, privacy: .public) firstVisible=\(window.firstVisibleRow) phase=\(String(describing: window.phase)) visibleRows=\(window.visibleRowCount) rendered=\(range.lowerBound)..<\(range.upperBound) materialized=\(materialized) rowCount=\(rowCount)"
        )
    }
}
#endif
