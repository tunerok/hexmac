//
//  BytePatternSearch.swift
//  HexMac
//

import Foundation

enum FindPatternMode: Equatable {
    case hex
    case ascii
}

enum FindDirection: Equatable {
    case up
    case down
}

enum HexParseError: LocalizedError, Equatable {
    case empty
    case invalidToken(String)
    case oddDigitCount

    var errorDescription: String? {
        switch self {
        case .empty:
            return String(localized: "Pattern is empty")
        case .invalidToken(let token):
            return String(localized: "Invalid hex: \(token)")
        case .oddDigitCount:
            return String(localized: "Hex digit count must be even")
        }
    }
}

struct BytePatternParseResult: Equatable {
    let pattern: [UInt8]
    let rangeTokens: [String]
}

enum BytePatternSearch {
    static func pattern(from input: String, mode: FindPatternMode) -> Result<[UInt8], HexParseError> {
        switch mode {
        case .hex:
            return parseHex(input)
        case .ascii:
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .failure(.empty) }
            return .success(Array(trimmed.utf8))
        }
    }

    static func parseHex(_ input: String) -> Result<[UInt8], HexParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        return parseHexTokens(tokens).map(\.pattern)
    }

    static func parseHexTokens(_ tokens: [String]) -> Result<BytePatternParseResult, HexParseError> {
        guard !tokens.isEmpty else { return .failure(.empty) }

        var pattern: [UInt8] = []
        var rangeStartIndex: Int?

        for (index, token) in tokens.enumerated() {
            if let byte = TerminalOffsetParser.parseByte(token) {
                pattern.append(byte)
                continue
            }

            let hexOnly = token.uppercased().filter(\.isHexDigit)
            if hexOnly.isEmpty {
                if pattern.isEmpty {
                    return .failure(.invalidToken(token))
                }
                rangeStartIndex = index
                break
            }

            guard hexOnly.count.isMultiple(of: 2), hexOnly.count >= 2 else {
                return .failure(hexOnly.count == 1 ? .invalidToken(token) : .oddDigitCount)
            }

            var position = hexOnly.startIndex
            while position < hexOnly.endIndex {
                let next = hexOnly.index(position, offsetBy: 2)
                guard let value = UInt8(hexOnly[position..<next], radix: 16) else {
                    return .failure(.invalidToken(token))
                }
                pattern.append(value)
                position = next
            }
        }

        guard !pattern.isEmpty else { return .failure(.empty) }

        let rangeTokens = rangeStartIndex.map { Array(tokens[$0...]) } ?? []
        return .success(BytePatternParseResult(pattern: pattern, rangeTokens: rangeTokens))
    }

    static func parseASCIITokens(_ tokens: [String]) -> BytePatternParseResult? {
        guard !tokens.isEmpty else { return nil }
        let pattern = Array(tokens.joined(separator: " ").utf8)
        guard !pattern.isEmpty else { return nil }
        return BytePatternParseResult(pattern: pattern, rangeTokens: [])
    }

    static func findAll(
        pattern: [UInt8],
        in range: Range<Int>,
        bytesProvider: (Range<Int>) -> [UInt8]
    ) -> [Int] {
        guard !pattern.isEmpty, range.lowerBound < range.upperBound else { return [] }

        let haystack = bytesProvider(range)
        guard haystack.count >= pattern.count else { return [] }

        var matches: [Int] = []
        let lastStart = haystack.count - pattern.count
        for start in 0...lastStart {
            if haystack[start..<(start + pattern.count)].elementsEqual(pattern) {
                matches.append(range.lowerBound + start)
            }
        }
        return matches
    }

    static func search(
        pattern: [UInt8],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        entireFile: Bool,
        direction: FindDirection,
        cursor: Int
    ) -> [Int] {
        guard !pattern.isEmpty, fileSize > 0 else { return [] }

        let range: Range<Int>
        if entireFile {
            range = 0..<fileSize
        } else {
            switch direction {
            case .down:
                range = min(max(0, cursor), fileSize)..<fileSize
            case .up:
                range = 0..<min(max(0, cursor), fileSize)
            }
        }

        let found = findAll(pattern: pattern, in: range, bytesProvider: bytesProvider)
        if entireFile || direction == .down {
            return found
        }
        return found.reversed()
    }

    static func findNext(
        pattern: [UInt8],
        fileSize: Int,
        bytesProvider: (Range<Int>) -> [UInt8],
        entireFile: Bool,
        direction: FindDirection,
        afterOffset: Int
    ) -> Int? {
        guard !pattern.isEmpty, fileSize > 0 else { return nil }

        if entireFile || direction == .down {
            let start = afterOffset + 1
            guard start < fileSize else { return nil }
            return findAll(pattern: pattern, in: start..<fileSize, bytesProvider: bytesProvider).first
        }

        let end = afterOffset
        guard end > 0 else { return nil }
        return findAll(pattern: pattern, in: 0..<end, bytesProvider: bytesProvider).last
    }

    static func formatMatches(_ matches: [Int]) -> String {
        guard !matches.isEmpty else {
            return String(localized: "Not found")
        }

        var lines = matches.map { offset in
            "0x\(HexFormatter.offsetString(for: offset)) (\(offset))"
        }
        let countLabel = String(localized: "\(matches.count) matches", comment: "Find result count")
        lines.append(countLabel)
        return lines.joined(separator: "\n")
    }
}
