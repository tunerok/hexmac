//
//  TerminalCommandParser.swift
//  HexMac
//

import Foundation

struct TerminalLine: Identifiable, Equatable {
    enum Kind: Equatable {
        case input
        case output
        case error
    }

    let id = UUID()
    let kind: Kind
    let text: String
}

enum TerminalCommandResult {
    case output(String)
    case navigate(Int)
    case error(String)
}

enum TerminalCommandParser {
    static func execute(
        _ input: String,
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .error(String(localized: "Empty command"))
        }

        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let command = parts.first?.lowercased() else {
            return .error(String(localized: "Invalid command"))
        }

        switch command {
        case "help":
            return .output(helpText)
        case "goto":
            return runGoto(parts: parts, fileSize: fileSize)
        case "sum":
            return runAggregate(parts: parts, fileSize: fileSize, bytesProvider: bytesProvider, operation: .sum)
        case "xor":
            return runAggregate(parts: parts, fileSize: fileSize, bytesProvider: bytesProvider, operation: .xor)
        case "avg":
            return runAggregate(parts: parts, fileSize: fileSize, bytesProvider: bytesProvider, operation: .average)
        case "len":
            return runLength(parts: parts, fileSize: fileSize)
        case "crc":
            return runCRC(parts: parts, fileSize: fileSize, bytesProvider: bytesProvider)
        default:
            return .error(String(localized: "Unknown command. Type help for available commands."))
        }
    }

    private static let helpText = """
    help
    goto <offset>
    sum <start> <end>
    xor <start> <end>
    avg <start> <end>
    len <start> <end>
    crc <start> <end>
    """

    private enum AggregateOperation {
        case sum
        case xor
        case average
    }

    private static func runGoto(parts: [String], fileSize: Int) -> TerminalCommandResult {
        guard parts.count == 2, let offset = parseOffset(parts[1]) else {
            return .error(String(localized: "Usage: goto <offset>"))
        }
        guard offset >= 0, offset < fileSize else {
            return .error(String(localized: "Offset out of bounds"))
        }
        return .navigate(offset)
    }

    private static func runLength(parts: [String], fileSize: Int) -> TerminalCommandResult {
        guard let range = parseRange(parts: parts, fileSize: fileSize) else {
            return .error(String(localized: "Usage: len <start> <end>"))
        }
        let length = range.upperBound - range.lowerBound
        return .output("\(length) \(String(localized: "bytes"))")
    }

    private static func runAggregate(
        parts: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        operation: AggregateOperation
    ) -> TerminalCommandResult {
        guard let range = parseRange(parts: parts, fileSize: fileSize) else {
            return .error(String(localized: "Usage: \(parts.first ?? "command") <start> <end>"))
        }

        let bytes = bytesProvider(range)
        guard !bytes.isEmpty else {
            return .error(String(localized: "Empty range"))
        }

        switch operation {
        case .sum:
            let total = bytes.reduce(0) { $0 + UInt64($1) }
            return .output("0x\(String(total, radix: 16, uppercase: true)) (\(total))")
        case .xor:
            let value = bytes.reduce(0) { $0 ^ UInt64($1) }
            return .output("0x\(String(format: "%02X", value))")
        case .average:
            let total = bytes.reduce(0) { $0 + UInt64($1) }
            let average = Double(total) / Double(bytes.count)
            return .output(String(format: "%.2f", average))
        }
    }

    private static func runCRC(
        parts: [String],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> TerminalCommandResult {
        guard let range = parseRange(parts: parts, fileSize: fileSize) else {
            return .error(String(localized: "Usage: crc <start> <end>"))
        }

        let bytes = bytesProvider(range)
        let configuration = CRCPreset.crc32ISO.configuration
        let value = CRCService.calculate(data: bytes, configuration: configuration)
        let formatted = CRCService.formattedResult(value, configuration: configuration)
        return .output("\(CRCPreset.crc32ISO.label): \(formatted)")
    }

    private static func parseRange(parts: [String], fileSize: Int) -> Range<Int>? {
        guard parts.count == 3,
              let start = parseOffset(parts[1]),
              let end = parseOffset(parts[2]) else {
            return nil
        }

        let lower = min(start, end)
        let upper = max(start, end) + 1
        guard lower >= 0, upper <= fileSize, lower < upper else { return nil }
        return lower..<upper
    }

    private static func parseOffset(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            let hex = String(trimmed.dropFirst(2))
            return Int(hex, radix: 16)
        }
        return Int(trimmed)
    }
}
