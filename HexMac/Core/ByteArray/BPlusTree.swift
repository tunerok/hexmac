//
//  BPlusTree.swift
//  HexMac
//

import Foundation

/// Ordered slice sequence with offset-based insert/remove.
/// Slice count stays small for typical edits, so a flat list is sufficient.
final class BPlusTree: @unchecked Sendable {
    private var entries: [SliceBox] = []

    var length: UInt64 {
        entries.reduce(0) { $0 + $1.length }
    }

    var allEntries: [SliceBox] {
        entries
    }

    func entry(at offset: UInt64) -> (SliceBox, UInt64)? {
        guard offset < length else { return nil }
        var current: UInt64 = 0
        for entry in entries {
            if offset < current + entry.length {
                return (entry, current)
            }
            current += entry.length
        }
        return nil
    }

    func insert(_ entry: SliceBox, at offset: UInt64) {
        precondition(offset <= length)
        guard entry.length > 0 else { return }

        if entries.isEmpty {
            entries = [entry]
            return
        }

        if offset == length {
            entries.append(entry)
            return
        }

        if offset == 0 {
            entries.insert(entry, at: 0)
            return
        }

        guard let (index, beginning) = entryIndex(at: offset) else {
            entries.append(entry)
            return
        }

        let existing = entries[index]
        let offsetInSlice = offset - beginning

        if offsetInSlice == 0 {
            entries.insert(entry, at: index)
            return
        }

        if offsetInSlice == existing.length {
            entries.insert(entry, at: index + 1)
            return
        }

        let left = SliceBox(existing.slice.subslice(range: 0..<offsetInSlice))
        let right = SliceBox(existing.slice.subslice(range: offsetInSlice..<existing.length))
        entries.remove(at: index)
        entries.insert(contentsOf: [left, entry, right], at: index)
    }

    func remove(at offset: UInt64) {
        guard let (index, _) = entryIndex(at: offset) else { return }
        entries.remove(at: index)
    }

    func removeAll() {
        entries.removeAll()
    }

    private func entryIndex(at offset: UInt64) -> (Int, UInt64)? {
        var current: UInt64 = 0
        for (index, entry) in entries.enumerated() {
            if offset < current + entry.length {
                return (index, current)
            }
            current += entry.length
        }
        return nil
    }
}
