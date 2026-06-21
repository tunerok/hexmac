//
//  HexFormatter.swift
//  ediHex
//

import Foundation

enum HexFormatter {
    nonisolated static func rowCount(for fileSize: Int, bytesPerRow: Int) -> Int {
        guard fileSize > 0, bytesPerRow > 0 else { return 0 }
        return (fileSize + bytesPerRow - 1) / bytesPerRow
    }

    nonisolated static func rowOffset(for rowIndex: Int, bytesPerRow: Int) -> Int {
        rowIndex * bytesPerRow
    }

    nonisolated static func byteCount(forRow rowIndex: Int, fileSize: Int, bytesPerRow: Int) -> Int {
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

    nonisolated static func offsetString(for offset: Int, width: Int = 8) -> String {
        String(format: "%0\(width)X", offset)
    }

    nonisolated static func columnIndexString(for column: Int) -> String {
        String(format: "%02X", column)
    }

    nonisolated static func hexPair(for byte: UInt8) -> String {
        String(format: "%02X", byte)
    }

    nonisolated static func hexString(for bytes: [UInt8]) -> String {
        bytes.map { hexPair(for: $0) }.joined(separator: " ")
    }

    nonisolated static func asciiCharacter(for byte: UInt8) -> Character {
        if byte >= 0x20 && byte <= 0x7E {
            Character(UnicodeScalar(byte))
        } else {
            "."
        }
    }

    nonisolated static func asciiString(for bytes: [UInt8]) -> String {
        String(bytes.map { asciiCharacter(for: $0) })
    }

    nonisolated static func utf8String(for bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    static func alignedTextCharacters(for bytes: [UInt8], encoding: TextEncodingMode) -> [Character] {
        guard !bytes.isEmpty else { return [] }

        switch encoding {
        case .ascii:
            return bytes.map { asciiCharacter(for: $0) }
        case .utf8:
            return utf8CharactersAligned(to: bytes)
        case .utf16LittleEndian:
            return utf16CharactersAligned(to: bytes, littleEndian: true)
        case .utf16BigEndian:
            return utf16CharactersAligned(to: bytes, littleEndian: false)
        case .isoLatin1, .windowsCP1252, .macRoman:
            return singleByteCharactersAligned(to: bytes, encoding: encoding.stringEncoding)
        }
    }

    nonisolated static func binaryString(for byte: UInt8) -> String {
        String(byte, radix: 2).leftPadded(to: 8, with: "0")
    }

    nonisolated static func binaryString(for bytes: [UInt8], bitWidth: Int) -> String {
        let byteCount = bitWidth / 8
        let used = Array(bytes.prefix(byteCount))
        let padded = used.count >= byteCount
            ? used
            : used + Array(repeating: 0, count: byteCount - used.count)
        return padded.map { binaryString(for: $0) }.joined()
    }

    nonisolated static func formattedFileSize(_ size: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private static func printableCharacter(for character: Character) -> Character {
        if character == "\t" || character == "\n" || character == "\r" {
            return character
        }
        guard character.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) else {
            return "."
        }
        return character
    }

    private static func singleByteCharactersAligned(to bytes: [UInt8], encoding: String.Encoding) -> [Character] {
        bytes.map { byte in
            guard let string = String(data: Data([byte]), encoding: encoding),
                  let character = string.first else {
                return "."
            }
            return printableCharacter(for: character)
        }
    }

    private static func utf8CharactersAligned(to bytes: [UInt8]) -> [Character] {
        var result = Array(repeating: Character(" "), count: bytes.count)
        var byteIndex = 0
        let string = utf8String(for: bytes)
        for character in string {
            guard byteIndex < bytes.count else { break }
            result[byteIndex] = printableCharacter(for: character)
            byteIndex += character.utf8.count
        }
        return result
    }

    private static func utf16CharactersAligned(to bytes: [UInt8], littleEndian: Bool) -> [Character] {
        var result = Array(repeating: Character(" "), count: bytes.count)
        let stringEncoding: String.Encoding = littleEndian ? .utf16LittleEndian : .utf16BigEndian
        guard let string = String(data: Data(bytes), encoding: stringEncoding) else {
            return bytes.map { _ in "." }
        }

        var byteIndex = 0
        for character in string {
            guard byteIndex < bytes.count else { break }
            result[byteIndex] = printableCharacter(for: character)
            byteIndex += character.utf16.count * 2
        }

        if byteIndex < bytes.count {
            for index in byteIndex..<bytes.count {
                result[index] = "."
            }
        }

        return result
    }
}

private extension String {
    nonisolated func leftPadded(to length: Int, with character: Character) -> String {
        if count >= length { return self }
        return String(repeating: character, count: length - count) + self
    }
}
