//
//  BytesPerRowSetting.swift
//  HexMac
//

import Foundation

enum BytesPerRowSetting: Int, CaseIterable, Identifiable {
    case eight = 8
    case sixteen = 16
    case twentyFour = 24
    case thirtyTwo = 32

    var id: Int { rawValue }

    var label: String {
        "\(rawValue)"
    }
}
