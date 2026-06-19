//
//  TerminalOffsetParser.swift
//  HexMac
//

import Foundation

enum TerminalOffsetParser {
    static func parse(_ text: String, fileSize: Int? = nil) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "end" {
            guard let fileSize, fileSize > 0 else { return nil }
            return fileSize - 1
        }
        if trimmed.lowercased().hasPrefix("0x") {
            let hex = String(trimmed.dropFirst(2))
            return Int(hex, radix: 16)
        }
        return Int(trimmed)
    }

    static func parseByte(_ text: String) -> UInt8? {
        guard let value = parse(text), value >= 0, value <= 0xFF else { return nil }
        return UInt8(value)
    }

    static func parseUInt64(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            let hex = String(trimmed.dropFirst(2))
            return UInt64(hex, radix: 16)
        }
        return UInt64(trimmed)
    }

    static func boundsError(offset: Int, text: String, fileSize: Int) -> TerminalParseError {
        if offset < 0 {
            return TerminalParseError(message: String(localized: "Offset out of bounds: \(text)"))
        }
        return TerminalParseError(
            message: String(localized: "Offset out of bounds: \(text) (file size is \(fileSize))")
        )
    }

    static func validateInFile(offset: Int, text: String, fileSize: Int) -> TerminalParseError? {
        guard offset >= 0, offset < fileSize else {
            return boundsError(offset: offset, text: text, fileSize: fileSize)
        }
        return nil
    }

    static func validateRangeInFile(
        start: Int,
        endInclusive: Int,
        startText: String,
        endText: String,
        fileSize: Int
    ) -> TerminalParseError? {
        if start < 0 {
            return boundsError(offset: start, text: startText, fileSize: fileSize)
        }
        if endInclusive < 0 {
            return boundsError(offset: endInclusive, text: endText, fileSize: fileSize)
        }
        if start >= fileSize {
            return boundsError(offset: start, text: startText, fileSize: fileSize)
        }
        if endInclusive >= fileSize {
            return boundsError(offset: endInclusive, text: endText, fileSize: fileSize)
        }
        return nil
    }
}
