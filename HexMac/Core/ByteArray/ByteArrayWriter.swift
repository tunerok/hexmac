//
//  ByteArrayWriter.swift
//  HexMac
//

import Foundation

enum ByteArrayWriteResult {
    case success
    case cancelled
    case failed(Error)
}

struct ByteArrayWriteProgress {
    var completed: UInt64 = 0
    var total: UInt64 = 0
    var isCancelled = false
}

final class ByteArrayWriter {
    fileprivate static let chunkSize = 1_048_576

    static func write(
        _ byteArray: BTreeByteArray,
        to url: URL,
        progress: ByteArrayWriteProgress? = nil
    ) throws {
        var tracker = progress ?? ByteArrayWriteProgress()
        let file = try FileReference.open(url: url, readOnly: false)
        defer { file.close() }

        byteArray.incrementChangeLock()
        defer { byteArray.decrementChangeLock() }

        let startLength = file.length
        let endLength = byteArray.length

        if endLength > startLength {
            try file.setLength(endLength)
        }

        let operations = classifyOperations(byteArray: byteArray, target: file)
        tracker.total = operations.reduce(0) { $0 + $1.cost }

        let internalOps = operations.compactMap { op -> InternalFileOperation? in
            if case .internalMove(let value) = op.kind { return value }
            return nil
        }

        let chains = try resolveInternalChains(internalOps)
        for chain in chains {
            if tracker.isCancelled { throw ByteArrayError.saveFailed }
            try chain.write(to: file, tracker: &tracker)
        }

        for op in operations {
            guard case .external(let external) = op.kind else { continue }
            if tracker.isCancelled { throw ByteArrayError.saveFailed }
            try external.write(to: file, tracker: &tracker)
        }

        if endLength < startLength {
            try file.setLength(endLength)
        }
    }

    // MARK: - Classification

    private struct ClassifiedOperation {
        enum Kind {
            case identity
            case external(ExternalFileOperation)
            case internalMove(InternalFileOperation)
        }

        let kind: Kind
        let targetRange: Range<UInt64>
        var cost: UInt64 {
            switch kind {
            case .identity:
                0
            case .external(let op):
                op.slice.length
            case .internalMove(let op):
                op.slice.length * 2
            }
        }
    }

    private static func classifyOperations(
        byteArray: BTreeByteArray,
        target: FileReference
    ) -> [ClassifiedOperation] {
        var result: [ClassifiedOperation] = []
        var currentOffset: UInt64 = 0

        for slice in byteArray.byteSlices {
            let sliceLength = slice.length
            let targetRange = currentOffset..<(currentOffset + sliceLength)
            if let sourceRange = slice.sourceRange(for: target), sourceRange == targetRange {
                result.append(ClassifiedOperation(kind: .identity, targetRange: targetRange))
            } else if let sourceRange = slice.sourceRange(for: target) {
                result.append(ClassifiedOperation(
                    kind: .internalMove(InternalFileOperation(
                        slice: slice,
                        sourceRange: sourceRange,
                        targetRange: targetRange
                    )),
                    targetRange: targetRange
                ))
            } else {
                result.append(ClassifiedOperation(
                    kind: .external(ExternalFileOperation(slice: slice, targetRange: targetRange)),
                    targetRange: targetRange
                ))
            }
            currentOffset += sliceLength
        }
        return result
    }

    // MARK: - Internal move resolution

    private static func resolveInternalChains(_ operations: [InternalFileOperation]) throws -> [InternalFileOperation] {
        guard !operations.isEmpty else { return [] }
        let sorted = operations.sorted { $0.targetRange.lowerBound < $1.targetRange.lowerBound }

        var graph: [Int: Set<Int>] = [:]
        for sourceIndex in sorted.indices {
            graph[sourceIndex] = []
            let source = sorted[sourceIndex]
            for targetIndex in sorted.indices where targetIndex != sourceIndex {
                let target = sorted[targetIndex]
                if UInt64ByteRange.intersects(source.sourceRange, target.targetRange) {
                    graph[sourceIndex, default: []].insert(targetIndex)
                }
            }
        }

        let components = stronglyConnectedComponents(nodeCount: sorted.count, graph: graph)
        var chains: [InternalFileOperation] = []

        for component in components {
            if component.count == 1, let index = component.first {
                chains.append(sorted[index])
                continue
            }

            let componentOps = component.map { sorted[$0] }
            let merged = InternalFileOperation.chained(operations: componentOps)
            chains.append(merged)
        }

        return topologicallySort(chains: chains, original: sorted, graph: graph)
    }

    private static func topologicallySort(
        chains: [InternalFileOperation],
        original: [InternalFileOperation],
        graph: [Int: Set<Int>]
    ) -> [InternalFileOperation] {
        guard chains.count > 1 else { return chains }

        let chainForOperation: [ObjectIdentifier: InternalFileOperation] = Dictionary(
            uniqueKeysWithValues: chains.map { (ObjectIdentifier($0.slice as AnyObject), $0) }
        )

        var chainGraph: [ObjectIdentifier: Set<ObjectIdentifier>] = [:]
        for (sourceIndex, deps) in graph {
            let sourceChain = chainForOperation[ObjectIdentifier(original[sourceIndex].slice as AnyObject)]!
            for depIndex in deps {
                let depChain = chainForOperation[ObjectIdentifier(original[depIndex].slice as AnyObject)]!
                if sourceChain !== depChain {
                    chainGraph[ObjectIdentifier(depChain.slice as AnyObject), default: []]
                        .insert(ObjectIdentifier(sourceChain.slice as AnyObject))
                }
            }
        }

        var sorted: [InternalFileOperation] = []
        var visited: Set<ObjectIdentifier> = []
        var visiting: Set<ObjectIdentifier> = []

        func visit(_ chain: InternalFileOperation) {
            let id = ObjectIdentifier(chain.slice as AnyObject)
            if visited.contains(id) { return }
            if visiting.contains(id) { return }
            visiting.insert(id)
            for dep in chainGraph[id, default: []] {
                if let next = chains.first(where: { ObjectIdentifier($0.slice as AnyObject) == dep }) {
                    visit(next)
                }
            }
            visiting.remove(id)
            visited.insert(id)
            sorted.append(chain)
        }

        for chain in chains.sorted(by: { $0.targetRange.lowerBound < $1.targetRange.lowerBound }) {
            visit(chain)
        }
        return sorted
    }

    private static func stronglyConnectedComponents(
        nodeCount: Int,
        graph: [Int: Set<Int>]
    ) -> [[Int]] {
        var index = 0
        var stack: [Int] = []
        var indices = Array(repeating: -1, count: nodeCount)
        var lowlink = Array(repeating: -1, count: nodeCount)
        var onStack = Array(repeating: false, count: nodeCount)
        var components: [[Int]] = []

        func strongConnect(_ v: Int) {
            indices[v] = index
            lowlink[v] = index
            index += 1
            stack.append(v)
            onStack[v] = true

            for w in graph[v, default: []] {
                if indices[w] == -1 {
                    strongConnect(w)
                    lowlink[v] = min(lowlink[v], lowlink[w])
                } else if onStack[w] {
                    lowlink[v] = min(lowlink[v], indices[w])
                }
            }

            if lowlink[v] == indices[v] {
                var component: [Int] = []
                while true {
                    let w = stack.removeLast()
                    onStack[w] = false
                    component.append(w)
                    if w == v { break }
                }
                components.append(component)
            }
        }

        for v in 0..<nodeCount where indices[v] == -1 {
            strongConnect(v)
        }
        return components
    }
}

// MARK: - Operations

private struct ExternalFileOperation {
    let slice: any ByteSlice
    let targetRange: Range<UInt64>

    func write(to file: FileReference, tracker: inout ByteArrayWriteProgress) throws {
        var written: UInt64 = 0
        var buffer = [UInt8](repeating: 0, count: ByteArrayWriter.chunkSize)

        while written < slice.length {
            if tracker.isCancelled { return }
            let toWrite = Int(min(UInt64(ByteArrayWriter.chunkSize), slice.length - written))
            slice.copyBytes(
                into: buffer.withUnsafeMutableBytes { $0.baseAddress! },
                range: written..<(written + UInt64(toWrite))
            )
            try buffer.withUnsafeBytes { raw in
                try file.write(from: raw.baseAddress!, length: toWrite, to: targetRange.lowerBound + written)
            }
            written += UInt64(toWrite)
            tracker.completed += UInt64(toWrite)
        }
    }
}

private final class InternalFileOperation {
    let slice: any ByteSlice
    let sourceRange: Range<UInt64>
    let targetRange: Range<UInt64>
    private var remainingTargets: [Range<UInt64>]

    init(slice: any ByteSlice, sourceRange: Range<UInt64>, targetRange: Range<UInt64>) {
        self.slice = slice
        self.sourceRange = sourceRange
        self.targetRange = targetRange
        self.remainingTargets = [targetRange]
    }

    static func chained(operations: [InternalFileOperation]) -> InternalFileOperation {
        let first = operations[0]
        let op = InternalFileOperation(
            slice: first.slice,
            sourceRange: first.sourceRange,
            targetRange: first.targetRange
        )
        op.remainingTargets = operations.flatMap(\.remainingTargets).sorted { $0.lowerBound < $1.lowerBound }
        return op
    }

    func write(to file: FileReference, tracker: inout ByteArrayWriteProgress) throws {
        var buffer = [UInt8](repeating: 0, count: ByteArrayWriter.chunkSize)

        for target in remainingTargets {
            var written: UInt64 = 0
            let length = target.upperBound - target.lowerBound
            while written < length {
                if tracker.isCancelled { return }
                let toWrite = Int(min(UInt64(ByteArrayWriter.chunkSize), length - written))
                let sourceOffset = sourceRange.lowerBound + written
                slice.copyBytes(
                    into: buffer.withUnsafeMutableBytes { $0.baseAddress! },
                    range: sourceOffset..<(sourceOffset + UInt64(toWrite))
                )
                try buffer.withUnsafeBytes { raw in
                    try file.write(from: raw.baseAddress!, length: toWrite, to: target.lowerBound + written)
                }
                written += UInt64(toWrite)
                tracker.completed += UInt64(toWrite) * 2
            }
        }
    }
}

