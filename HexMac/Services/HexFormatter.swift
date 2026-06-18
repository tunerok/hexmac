//
//  HexFormatter.swift
//  HexMac
//

import Foundation

enum HexFormatter {
    static func rowCount(for fileSize: Int, bytesPerRow: Int) -> Int {
        guard fileSize > 0, bytesPerRow > 0 else { return 0 }
        return (fileSize + bytesPerRow - 1) / bytesPerRow
    }

    static func rowOffset(for rowIndex: Int, bytesPerRow: Int) -> Int {
        rowIndex * bytesPerRow
    }

    static func byteCount(forRow rowIndex: Int, fileSize: Int, bytesPerRow: Int) -> Int {
        let offset = rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
        guard offset < fileSize else { return 0 }
        return min(bytesPerRow, fileSize - offset)
    }

    static func textColumnWidth(for bytesPerRow: Int) -> CGFloat {
        HexGridLayout.textColumnWidth(for: bytesPerRow)
    }

    static func hexColumnWidth(for bytesPerRow: Int) -> CGFloat {
        HexGridLayout.hexColumnWidth(for: bytesPerRow)
    }

    static func offsetString(for offset: Int, width: Int = 8) -> String {
        String(format: "%0\(width)X", offset)
    }

    static func columnIndexString(for column: Int) -> String {
        String(format: "%02X", column)
    }

    static func hexPair(for byte: UInt8) -> String {
        String(format: "%02X", byte)
    }

    static func hexString(for bytes: [UInt8]) -> String {
        bytes.map { hexPair(for: $0) }.joined(separator: " ")
    }

    static func asciiCharacter(for byte: UInt8) -> Character {
        if byte >= 0x20 && byte <= 0x7E {
            Character(UnicodeScalar(byte))
        } else {
            "."
        }
    }

    static func asciiString(for bytes: [UInt8]) -> String {
        String(bytes.map { asciiCharacter(for: $0) })
    }

    static func utf8String(for bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    static func binaryString(for byte: UInt8) -> String {
        String(byte, radix: 2).leftPadded(to: 8, with: "0")
    }

    static func formattedFileSize(_ size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    static func normalizedHexInput(_ input: String) -> String? {
        let filtered = input.uppercased().filter(\.isHexDigit)
        guard !filtered.isEmpty else { return nil }

        if filtered.count == 1 {
            return "0\(filtered)"
        }
        return String(filtered.prefix(2))
    }
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        if count >= length { return self }
        return String(repeating: character, count: length - count) + self
    }
}
