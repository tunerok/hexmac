//
//  HexFontMetricsTests.swift
//  ediHexTests
//

import AppKit
import XCTest
@testable import ediHex

final class HexFontMetricsTests: XCTestCase {
    func testTextColumnWidthFitsMeasuredString() {
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let descriptor = bodyFont.fontDescriptor.withDesign(.monospaced) ?? bodyFont.fontDescriptor
        let font = NSFont(descriptor: descriptor, size: bodyFont.pointSize) ?? bodyFont

        for bytesPerRow in [8, 16, 24, 32] {
            let sample = String(repeating: "0", count: bytesPerRow)
            let measuredWidth = ceil((sample as NSString).size(withAttributes: [.font: font]).width)
            let columnWidth = HexGridLayout.textColumnWidth(for: bytesPerRow)
            XCTAssertGreaterThanOrEqual(
                columnWidth,
                measuredWidth,
                "Text column too narrow for \(bytesPerRow) monospaced characters"
            )
        }
    }

    func testTextColumnWidthScalesWithByteCount() {
        let slotWidth = HexGridLayout.textCharacterWidth
        for bytesPerRow in [8, 16, 24, 32] {
            XCTAssertEqual(
                HexGridLayout.textColumnWidth(for: bytesPerRow),
                CGFloat(bytesPerRow) * slotWidth
            )
        }
    }

    func testAlignedTextCharactersASCIIMatchesByteCount() {
        let bytes: [UInt8] = Array(0x20...0x3F)
        let characters = HexFormatter.alignedTextCharacters(for: bytes, encoding: .ascii)
        XCTAssertEqual(characters.count, bytes.count)
    }
}
