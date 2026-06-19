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

enum SelectionMoveDirection {
    case left
    case right
    case up
    case down

    init?(keyCode: UInt16) {
        switch keyCode {
        case 123:
            self = .left
        case 124:
            self = .right
        case 125:
            self = .down
        case 126:
            self = .up
        default:
            return nil
        }
    }

    func byteDelta(bytesPerRow: Int) -> Int {
        switch self {
        case .left:
            -1
        case .right:
            1
        case .up:
            -bytesPerRow
        case .down:
            bytesPerRow
        }
    }
}
