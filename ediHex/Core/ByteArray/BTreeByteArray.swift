//
//  BTreeByteArray.swift
//  ediHex
//

import Foundation

final class BTreeByteArray: @unchecked Sendable {
    private let tree = BPlusTree()
    private var changeLockCounter = 0
    private(set) var changeGeneration: UInt64 = 0

    nonisolated var length: UInt64 { tree.length }

    var byteSlices: [any ByteSlice] {
        tree.allEntries.map(\.slice)
    }

    func incrementChangeLock() {
        changeLockCounter += 1
    }

    func decrementChangeLock() {
        changeLockCounter = max(0, changeLockCounter - 1)
    }

    nonisolated func byte(at offset: UInt64) -> UInt8? {
        guard offset < length else { return nil }
        guard let (entry, beginning) = tree.entry(at: offset) else { return nil }
        return entry.slice.byte(at: offset - beginning)
    }

    nonisolated func bytes(in range: Range<UInt64>) -> [UInt8] {
        let clamped = UInt64ByteRange.clamp(range, to: length)
        guard !clamped.isEmpty else { return [] }
        let count = Int(clamped.upperBound - clamped.lowerBound)
        var result = [UInt8](repeating: 0, count: count)
        var destination = 0
        var remaining = clamped
        while !remaining.isEmpty {
            guard let (entry, beginning) = tree.entry(at: remaining.lowerBound) else { break }
            let offsetInSlice = remaining.lowerBound - beginning
            let available = entry.length - offsetInSlice
            let toCopy = min(available, remaining.upperBound - remaining.lowerBound)
            guard toCopy > 0 else { break }
            let copyCount = Int(toCopy)
            result.withUnsafeMutableBytes { buffer in
                guard let base = buffer.baseAddress else { return }
                entry.slice.copyBytes(
                    into: base.advanced(by: destination),
                    range: offsetInSlice..<(offsetInSlice + toCopy)
                )
            }
            destination += copyCount
            let next = remaining.lowerBound + toCopy
            guard next > remaining.lowerBound else { break }
            remaining = next..<remaining.upperBound
        }
        return result
    }

    func insert(slice: any ByteSlice, at offset: UInt64) {
        guardChangeAllowed()
        guard slice.length > 0 else { return }
        precondition(offset <= length)
        insertSlice(slice, at: offset)
        bumpGeneration()
    }

    func delete(range: Range<UInt64>) {
        guardChangeAllowed()
        let clamped = UInt64ByteRange.clamp(range, to: length)
        guard !clamped.isEmpty else { return }

        if clamped.lowerBound == 0, clamped.upperBound == length {
            tree.removeAll()
            bumpGeneration()
            return
        }

        var beforeSlice: (any ByteSlice)?
        var afterSlice: (any ByteSlice)?
        var rangeStart = clamped.lowerBound
        var remaining = clamped

        while !remaining.isEmpty {
            guard let (entry, beginning) = tree.entry(at: remaining.lowerBound) else { break }
            let offsetInSlice = remaining.lowerBound - beginning
            let sliceEnd = beginning + entry.length
            let deleteEnd = min(remaining.upperBound, sliceEnd)
            guard deleteEnd > remaining.lowerBound else { break }

            let leftLength = offsetInSlice
            let rightStart = deleteEnd - beginning
            let rightLength = entry.length - rightStart

            if leftLength > 0 {
                beforeSlice = entry.slice.subslice(range: 0..<leftLength)
                rangeStart = beginning
            }
            if rightLength > 0 {
                afterSlice = entry.slice.subslice(range: rightStart..<entry.length)
            }

            tree.remove(at: beginning)
            remaining = deleteEnd..<remaining.upperBound
        }

        if let afterSlice {
            insertSlice(afterSlice, at: rangeStart)
        }
        if let beforeSlice {
            insertSlice(beforeSlice, at: rangeStart)
        }
        bumpGeneration()
    }

    func replaceByte(at offset: UInt64, with value: UInt8) -> UInt8? {
        guardChangeAllowed()
        guard offset < length else { return nil }
        guard let (entry, beginning) = tree.entry(at: offset) else { return nil }
        let offsetInSlice = offset - beginning
        let oldValue = entry.slice.byte(at: offsetInSlice)

        if entry.length == 1 {
            tree.remove(at: beginning)
            tree.insert(SliceBox(MemoryByteSlice(singleByte: value)), at: beginning)
        } else if entry.length <= 4096 {
            var data = entry.slice.bytes(in: 0..<entry.length)
            data[Int(offsetInSlice)] = value
            tree.remove(at: beginning)
            tree.insert(SliceBox(MemoryByteSlice(data: Data(data))), at: beginning)
        } else {
            let left = entry.slice.subslice(range: 0..<offsetInSlice)
            let right = entry.slice.subslice(range: (offsetInSlice + 1)..<entry.length)
            let middle = MemoryByteSlice(singleByte: value)
            var replacements: [SliceBox] = []
            if left.length > 0 { replacements.append(SliceBox(left)) }
            replacements.append(SliceBox(middle))
            if right.length > 0 { replacements.append(SliceBox(right)) }
            tree.replaceEntry(at: beginning, with: replacements)
        }

        bumpGeneration()
        return oldValue
    }

    func replaceBytes(in range: Range<UInt64>, with value: UInt8) -> [UInt8] {
        guardChangeAllowed()
        let clamped = UInt64ByteRange.clamp(range, to: length)
        guard !clamped.isEmpty else { return [] }

        let oldValues = bytes(in: clamped)
        delete(range: clamped)
        insertSlice(MemoryByteSlice(data: Data(repeating: value, count: oldValues.count)), at: clamped.lowerBound)
        bumpGeneration()
        return oldValues
    }

    func appendByte(_ value: UInt8) {
        insert(slice: MemoryByteSlice(singleByte: value), at: length)
    }

    func truncate(to newLength: UInt64) {
        guard newLength < length else { return }
        delete(range: newLength..<length)
    }

    private func insertSlice(_ slice: any ByteSlice, at offset: UInt64) {
        guard slice.length > 0 else { return }

        if offset == 0 {
            tree.insert(SliceBox(slice), at: 0)
        } else if offset == length {
            if !fastPathAppend(slice: slice, at: offset) {
                tree.insert(SliceBox(slice), at: offset)
            }
        } else if let (_, beginning) = tree.entry(at: offset), beginning == offset {
            if !fastPathAppendToPrior(slice: slice, priorOffset: offset - 1) {
                tree.insert(SliceBox(slice), at: offset)
            }
        } else if let (existing, beginning) = tree.entry(at: offset) {
            let offsetInSlice = offset - beginning
            let left = existing.slice.subslice(range: 0..<offsetInSlice)
            let right = existing.slice.subslice(range: offsetInSlice..<existing.length)
            tree.remove(at: beginning)
            tree.insert(SliceBox(right), at: beginning)
            if let joined = left.coalesce(with: slice) {
                tree.insert(SliceBox(joined), at: beginning)
            } else {
                tree.insert(SliceBox(slice), at: beginning)
                tree.insert(SliceBox(left), at: beginning)
            }
        }
    }

    private func fastPathAppend(slice: any ByteSlice, at offset: UInt64) -> Bool {
        guard offset > 0 else { return false }
        guard let (prior, priorOffset) = tree.entry(at: offset - 1) else { return false }
        guard let appended = prior.slice.coalesce(with: slice) else { return false }
        tree.remove(at: priorOffset)
        tree.insert(SliceBox(appended), at: priorOffset)
        return true
    }

    private func fastPathAppendToPrior(slice: any ByteSlice, priorOffset: UInt64) -> Bool {
        guard let (prior, beginning) = tree.entry(at: priorOffset), beginning == priorOffset else { return false }
        guard let appended = prior.slice.coalesce(with: slice) else { return false }
        tree.remove(at: priorOffset)
        tree.insert(SliceBox(appended), at: priorOffset)
        return true
    }

    private func guardChangeAllowed() {
        guard changeLockCounter == 0 else {
            fatalError("Byte array is locked for save")
        }
    }

    private func bumpGeneration() {
        changeGeneration &+= 1
    }
}

extension BTreeByteArray {
    static func fromFile(_ file: FileReference) -> BTreeByteArray {
        let array = BTreeByteArray()
        guard file.length > 0 else { return array }
        array.insert(slice: FileByteSlice(file: file), at: 0)
        return array
    }
}
