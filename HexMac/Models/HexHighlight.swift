//
//  HexHighlight.swift
//  HexMac
//

import SwiftUI

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case red
    case blue
    case purple
    case orange

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow:
            String(localized: "Yellow")
        case .green:
            String(localized: "Green")
        case .red:
            String(localized: "Red")
        case .blue:
            String(localized: "Blue")
        case .purple:
            String(localized: "Purple")
        case .orange:
            String(localized: "Orange")
        }
    }

    var color: Color {
        switch self {
        case .yellow:
            .yellow
        case .green:
            .green
        case .red:
            .red
        case .blue:
            .blue
        case .purple:
            .purple
        case .orange:
            .orange
        }
    }
}

struct HexHighlight: Identifiable, Equatable {
    let id: UUID
    var start: Int
    var end: Int
    var color: HighlightColor

    init(id: UUID = UUID(), start: Int, end: Int, color: HighlightColor) {
        self.id = id
        self.start = min(start, end)
        self.end = max(start, end)
        self.color = color
    }

    func contains(_ offset: Int) -> Bool {
        offset >= start && offset <= end
    }

    func overlaps(_ other: HexHighlight) -> Bool {
        start <= other.end && end >= other.start
    }

    func overlaps(rangeStart: Int, rangeEnd: Int) -> Bool {
        start <= rangeEnd && end >= rangeStart
    }
}
