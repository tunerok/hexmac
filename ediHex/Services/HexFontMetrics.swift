//
//  HexFontMetrics.swift
//  ediHex
//

import AppKit
import CoreGraphics

enum HexFontMetrics {
    private static let layoutPadding: CGFloat = 1

    /// Width of one character rendered with `.font(.body.monospaced())` in the hex grid.
    static var bodyMonospacedCharacterWidth: CGFloat {
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let descriptor = bodyFont.fontDescriptor.withDesign(.monospaced) ?? bodyFont.fontDescriptor
        let font = NSFont(descriptor: descriptor, size: bodyFont.pointSize) ?? bodyFont
        let measured = ceil(("0" as NSString).size(withAttributes: [.font: font]).width)
        return measured + layoutPadding
    }
}
