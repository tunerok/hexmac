//
//  TextEncodingMode.swift
//  HexMac
//

import Foundation

enum TextEncodingMode: String, CaseIterable, Identifiable {
    case ascii
    case utf8

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascii:
            String(localized: "ASCII")
        case .utf8:
            String(localized: "UTF-8")
        }
    }
}
