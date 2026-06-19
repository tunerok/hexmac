//
//  ByteArrayTypes.swift
//  HexMac
//

import Foundation

enum ByteArrayError: Error, LocalizedError {
    case openFailed
    case readFailed
    case writeFailed
    case outOfBounds
    case writeProtected
    case resizeFailed
    case lockedForSave
    case saveFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .openFailed:
            String(localized: "Failed to open file")
        case .readFailed:
            String(localized: "Failed to read file")
        case .writeFailed:
            String(localized: "Failed to write file")
        case .outOfBounds:
            String(localized: "Read out of bounds")
        case .writeProtected:
            String(localized: "File is read-only")
        case .resizeFailed:
            String(localized: "Failed to resize file")
        case .lockedForSave:
            String(localized: "Document is locked for saving")
        case .saveFailed:
            String(localized: "Failed to save file")
        case .fileTooLarge:
            String(localized: "File is too large for this operation")
        }
    }
}

enum UInt64ByteRange {
    static func clamp(_ range: Range<UInt64>, to length: UInt64) -> Range<UInt64> {
        let lower = min(max(range.lowerBound, 0), length)
        let upper = min(max(range.upperBound, 0), length)
        guard lower < upper else { return lower..<lower }
        return lower..<upper
    }

    static func clamp(_ range: Range<Int>, to length: UInt64) -> Range<UInt64> {
        let lower = UInt64(max(range.lowerBound, 0))
        let upper = UInt64(max(range.upperBound, 0))
        return clamp(lower..<upper, to: length)
    }

    static func intLength(_ value: UInt64) throws -> Int {
        guard value <= UInt64(Int.max) else { throw ByteArrayError.fileTooLarge }
        return Int(value)
    }

    static func intersects(_ a: Range<UInt64>, _ b: Range<UInt64>) -> Bool {
        a.lowerBound < b.upperBound && b.lowerBound < a.upperBound
    }
}
