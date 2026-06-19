//
//  DocumentRowCache.swift
//  HexMac
//

import Foundation

struct DocumentRowCache {
    static let maxRows = 512

    private var rows: [Int: [UInt8]] = [:]
    private var order: [Int] = []

    mutating func invalidate() {
        rows.removeAll(keepingCapacity: false)
        order.removeAll(keepingCapacity: false)
    }

    func bytes(for row: Int) -> [UInt8]? {
        rows[row]
    }

    func contains(row: Int) -> Bool {
        rows[row] != nil
    }

    func missingRows(in range: Range<Int>) -> Bool {
        range.contains { rows[$0] == nil }
    }

    mutating func store(_ bytes: [UInt8], for row: Int) {
        if rows[row] != nil {
            order.removeAll { $0 == row }
        } else if order.count >= Self.maxRows, let evicted = order.first {
            order.removeFirst()
            rows.removeValue(forKey: evicted)
        }
        rows[row] = bytes
        order.append(row)
    }

    mutating func storeBatch(_ batch: [Int: [UInt8]]) {
        for row in batch.keys.sorted() {
            guard let bytes = batch[row] else { continue }
            store(bytes, for: row)
        }
    }

    mutating func patch(_ bytes: [UInt8], for row: Int) {
        store(bytes, for: row)
    }
}
