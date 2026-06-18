//
//  HexSelection.swift
//  HexMac
//

import Foundation

struct HexSelection: Equatable {
    var anchor: Int
    var active: Int

    var start: Int {
        min(anchor, active)
    }

    var end: Int {
        max(anchor, active)
    }

    var length: Int {
        end - start + 1
    }

    var isEmpty: Bool {
        length <= 0
    }

    func contains(_ offset: Int) -> Bool {
        offset >= start && offset <= end
    }

    static func single(at offset: Int) -> HexSelection {
        HexSelection(anchor: offset, active: offset)
    }
}
