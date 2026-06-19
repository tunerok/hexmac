//
//  FindSession.swift
//  HexMac
//

import Foundation

struct FindSession: Equatable {
    let pattern: [UInt8]
    let mode: FindPatternMode
    let entireFile: Bool
    let direction: FindDirection
    var matches: [Int]
    var currentIndex: Int

    var hasMatches: Bool {
        !matches.isEmpty
    }

    var currentMatch: Int? {
        guard currentIndex >= 0, currentIndex < matches.count else { return nil }
        return matches[currentIndex]
    }

    var statusText: String? {
        guard hasMatches else { return nil }
        return String(
            localized: "Match \(currentIndex + 1) of \(matches.count)",
            comment: "Find dialog status"
        )
    }
}

enum FindResult {
    case found(FindSession)
    case notFound
}
