//
//  TerminalRangeSpec.swift
//  HexMac
//

import Foundation

struct TerminalRangeSpec: Equatable {
    let segments: [Range<Int>]

    var totalRawByteCount: Int {
        segments.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
    }

    static func parse(positionalTokens: [String], fileSize: Int) -> Result<TerminalRangeSpec, TerminalParseError> {
        guard !positionalTokens.isEmpty else {
            return .failure(TerminalParseError(message: String(localized: "Invalid range. Type help ranges for syntax.")))
        }

        let joined = positionalTokens.joined(separator: " ")
        let segmentTexts = joined.split(separator: ",", omittingEmptySubsequences: true)
        guard !segmentTexts.isEmpty else {
            return .failure(TerminalParseError(message: String(localized: "Invalid range. Type help ranges for syntax.")))
        }

        var segments: [Range<Int>] = []
        for segmentText in segmentTexts {
            let offsets = segmentText
                .split(whereSeparator: \.isWhitespace)
                .map { String($0) }
            guard offsets.count == 2 else {
                return .failure(TerminalParseError(message: String(localized: "Invalid range. Type help ranges for syntax.")))
            }

            let startText = offsets[0]
            let endText = offsets[1]
            guard let start = TerminalOffsetParser.parse(startText, fileSize: fileSize) else {
                return .failure(TerminalParseError(message: String(localized: "Invalid offset: \(startText)")))
            }
            guard let end = TerminalOffsetParser.parse(endText, fileSize: fileSize) else {
                return .failure(TerminalParseError(message: String(localized: "Invalid offset: \(endText)")))
            }

            if let boundsError = TerminalOffsetParser.validateRangeInFile(
                start: start,
                endInclusive: end,
                startText: startText,
                endText: endText,
                fileSize: fileSize
            ) {
                return .failure(boundsError)
            }

            let lower = min(start, end)
            let upper = max(start, end) + 1
            guard lower < upper else {
                return .failure(TerminalParseError(message: String(localized: "Invalid range. Type help ranges for syntax.")))
            }
            segments.append(lower..<upper)
        }

        return .success(TerminalRangeSpec(segments: segments))
    }
}
