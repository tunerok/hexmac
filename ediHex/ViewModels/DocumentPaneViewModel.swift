//
//  DocumentPaneViewModel.swift
//  ediHex
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DocumentPaneViewModel: Identifiable {
    let id = UUID()

    private(set) var document: HexDocument?
    private(set) var paneMode: PaneMode = .document
    var selection: HexSelection?
    var comparisonLeftSelection: HexSelection?
    var comparisonRightSelection: HexSelection?
    private(set) var comparisonActiveSide: CompareSide = .left
    var textEncoding: TextEncodingMode = .ascii
    var bytesPerRow: BytesPerRowSetting = .sixteen
    var highlights: [HexHighlight] = []
    var scrollTargetOffset: Int?
    var scrollRevealOffset: Int?
    var showCRCSheet = false
    var showHashSheet = false
    var showFillDialog = false
    var showHistogramSheet = false
    var showBinarySheet = false
    var showFindSheet = false
    private(set) var findSession: FindSession?
    var binarySelectionStart = 0
    var binarySelectionEnd = 0
    var binarySelectionByteCount = 0
    var crcInputBytes: [UInt8] = []
    var hashInputBytes: [UInt8] = []
    var hashInputRange: Range<Int>?
    var hashTitle = ""
    var hashFileName = ""
    var histogramCounts: [Int] = Array(repeating: 0, count: 256)
    var histogramTitle = ""
    var histogramFileName = ""
    var histogramByteCount = 0
    var histogramUniqueValueCount = 0
    var histogramTopEntries: [(byte: Int, count: Int)] = []
    var terminalHistory: [TerminalLine] = []
    var editingOffset: Int?
    var editingHexText = ""
    @ObservationIgnored private var editingAppendedByte = false
    var errorMessage: String?
    var showError = false
    private(set) var dataRevision = 0
    private(set) var comparisonDiffMap: CompareDiffMap?
    private(set) var comparisonDiffChunkIndex: CompareDiffChunkIndex?
    private(set) var comparisonDiffRegions: [DiffRegion] = []
    private(set) var comparisonCurrentDiffOffset: Int?
    private(set) var canNavigatePreviousDiff = false
    private(set) var canNavigateNextDiff = false
    private(set) var isDiffMapLoading = false
    private(set) var diffMapProgress: Double = 0
    private(set) var diffMapScanFraction: Double = 0
    private(set) var comparisonRowRevision = 0
    @ObservationIgnored private var comparisonDiffMapGeneration = 0
    @ObservationIgnored private var comparisonNavGeneration = 0
    private(set) var isHistogramLoading = false
    private(set) var histogramProgress: Double = 0
    @ObservationIgnored private var histogramGeneration = 0
    private(set) var isFindLoading = false
    private(set) var findProgress: Double = 0
    @ObservationIgnored private var findGeneration = 0
    @ObservationIgnored private var findSearchTask: Task<Void, Never>?
    @ObservationIgnored private var compareRowCache = CompareRowCache()
    @ObservationIgnored private var compareRowCacheGeneration = 0
    @ObservationIgnored private var documentRowCache = DocumentRowCache()
    @ObservationIgnored private var documentRowCacheGeneration = 0
    @ObservationIgnored private var documentRowLoadTask: Task<Void, Never>?
    @ObservationIgnored private var documentRowLoadGeneration = 0
    private(set) var documentRowRevision = 0
    private(set) var scrollSessionID = 0
    @ObservationIgnored private var comparisonRowLoadTask: Task<Void, Never>?
    @ObservationIgnored private var comparisonRowLoadGeneration = 0

    private let undoManager = UndoManager()

    var isDocumentOpen: Bool {
        document != nil
    }

    var isComparisonPane: Bool {
        if case .comparison = paneMode { return true }
        return false
    }

    var fileSize: Int {
        switch paneMode {
        case .document:
            return document?.fileSize ?? 0
        case .comparison(let left, let right):
            return max(left.fileSize, right.fileSize)
        }
    }

    var rowCount: Int {
        HexFormatter.rowCount(for: fileSize, bytesPerRow: bytesPerRow.rawValue)
    }

    var isDirty: Bool {
        document?.isDirty ?? false
    }

    var displayTitle: String {
        if isComparisonPane {
            return String(localized: "Comparison")
        }
        guard let document else {
            return String(localized: "Untitled")
        }
        if document.isDirty {
            return "\(document.displayName) •"
        }
        return document.displayName
    }

    var windowTitle: String {
        if isComparisonPane {
            return String(localized: "Comparison")
        }
        guard let document else {
            return String(localized: "ediHex")
        }
        if document.isDirty {
            return "\(document.displayName) — \(String(localized: "Edited"))"
        }
        return document.displayName
    }

    var comparisonLeftName: String {
        guard case .comparison(let left, _) = paneMode else { return "" }
        return left.displayName
    }

    var comparisonRightName: String {
        guard case .comparison(_, let right) = paneMode else { return "" }
        return right.displayName
    }

    var comparisonDiffCount: Int {
        comparisonDiffRegions.count
    }

    var comparisonHasDifferences: Bool {
        !comparisonDiffRegions.isEmpty
    }

    var comparisonCurrentDiffRegionIndex: Int? {
        guard let offset = comparisonCurrentDiffOffset else { return nil }
        return ByteCompareService.diffRegionIndex(for: offset, in: comparisonDiffRegions)
    }

    var selectedOffset: Int? {
        if isComparisonPane {
            return comparisonSelection(for: comparisonActiveSide)?.active
        }
        return selection?.active
    }

    var canSave: Bool {
        isDocumentOpen && isDirty
    }

    var hasSelection: Bool {
        selection != nil
    }

    func loadFile(from url: URL) {
        do {
            resetComparisonMode()
            document?.close()
            document = try HexDocument.open(url: url, readOnly: false)
            paneMode = .document
            selection = fileSize > 0 ? .single(at: 0) : nil
            highlights = []
            scrollTargetOffset = nil
            scrollRevealOffset = nil
            terminalHistory = []
            findSession = nil
            editingOffset = nil
            editingHexText = ""
            editingAppendedByte = false
            undoManager.removeAllActions()
            scrollSessionID &+= 1
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func loadComparison(left leftURL: URL, right rightURL: URL) {
        do {
            resetComparisonMode()
            document?.close()
            document = nil
            let left = try HexDocument.open(url: leftURL, readOnly: true)
            let right = try HexDocument.open(url: rightURL, readOnly: true)
            paneMode = .comparison(left: left, right: right)
            selection = nil
            comparisonLeftSelection = nil
            comparisonRightSelection = nil
            comparisonActiveSide = .left
            highlights = []
            scrollTargetOffset = nil
            scrollRevealOffset = nil
            terminalHistory = []
            findSession = nil
            editingOffset = nil
            editingHexText = ""
            editingAppendedByte = false
            undoManager.removeAllActions()
            scrollSessionID &+= 1
            bumpDataRevision()
            rebuildComparisonDiffMap()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func rebuildComparisonDiffMap(bucketCount: Int = ByteCompareService.defaultBucketCount) {
        guard case .comparison(let left, let right) = paneMode else {
            comparisonDiffMap = nil
            comparisonDiffChunkIndex = nil
            comparisonDiffRegions = []
            comparisonCurrentDiffOffset = nil
            isDiffMapLoading = false
            diffMapProgress = 0
            diffMapScanFraction = 0
            return
        }

        comparisonDiffMapGeneration &+= 1
        let generation = comparisonDiffMapGeneration
        isDiffMapLoading = true
        diffMapProgress = 0
        diffMapScanFraction = 0
        comparisonDiffMap = nil
        comparisonDiffChunkIndex = nil
        comparisonDiffRegions = []
        comparisonCurrentDiffOffset = nil

        let leftArray = left.byteArray
        let rightArray = right.byteArray
        let leftSize = left.fileSize
        let rightSize = right.fileSize
        let total = max(leftSize, rightSize)
        let usePreciseMap = total <= ByteCompareService.largeFileThreshold

        Task.detached {
            var lastUIUpdate = ContinuousClock.now
            let uiInterval: Duration = .milliseconds(100)

            let leftBytes: (Range<Int>) -> [UInt8] = { range in
                leftArray.bytes(in: UInt64(range.lowerBound)..<UInt64(range.upperBound))
            }
            let rightBytes: (Range<Int>) -> [UInt8] = { range in
                rightArray.bytes(in: UInt64(range.lowerBound)..<UInt64(range.upperBound))
            }

            let chunkIndex = ByteCompareService.buildDiffChunkIndexIncremental(
                leftSize: leftSize,
                rightSize: rightSize,
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                bucketCount: bucketCount
            ) { partialIndex, progress in
                let now = ContinuousClock.now
                guard progress >= 1.0 || now - lastUIUpdate >= uiInterval else { return }
                lastUIUpdate = now

                Task { @MainActor in
                    guard generation == self.comparisonDiffMapGeneration,
                          case .comparison = self.paneMode else { return }
                    self.comparisonDiffChunkIndex = partialIndex
                    self.comparisonDiffMap = partialIndex.map
                    self.diffMapScanFraction = progress
                    self.diffMapProgress = progress * 0.5
                }
            }

            let regions = ByteCompareService.buildDiffRegionsIncremental(
                leftSize: leftSize,
                rightSize: rightSize,
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                chunkSize: chunkIndex.chunkSize
            ) { partialRegions, progress in
                let now = ContinuousClock.now
                guard progress >= 1.0 || now - lastUIUpdate >= uiInterval else { return }
                lastUIUpdate = now

                Task { @MainActor in
                    guard generation == self.comparisonDiffMapGeneration,
                          case .comparison = self.paneMode else { return }
                    self.comparisonDiffRegions = partialRegions
                    self.diffMapScanFraction = progress
                    self.diffMapProgress = 0.5 + progress * 0.5
                }
            }

            let finalIndex: CompareDiffChunkIndex
            if usePreciseMap {
                await MainActor.run {
                    guard generation == self.comparisonDiffMapGeneration,
                          case .comparison = self.paneMode else { return }
                    self.diffMapProgress = 0.95
                    self.diffMapScanFraction = 1
                }

                let preciseMap = ByteCompareService.buildDiffMapIncremental(
                    leftSize: leftSize,
                    rightSize: rightSize,
                    leftBytes: leftBytes,
                    rightBytes: rightBytes,
                    bucketCount: bucketCount,
                    strideOverride: 1
                )
                finalIndex = CompareDiffChunkIndex(
                    chunkSize: chunkIndex.chunkSize,
                    totalBytes: chunkIndex.totalBytes,
                    diffChunkStarts: chunkIndex.diffChunkStarts,
                    map: preciseMap
                )
            } else {
                finalIndex = chunkIndex
            }

            await MainActor.run {
                guard generation == self.comparisonDiffMapGeneration,
                      case .comparison = self.paneMode else { return }
                self.comparisonDiffChunkIndex = finalIndex
                self.comparisonDiffMap = finalIndex.map
                self.comparisonDiffRegions = regions
                self.isDiffMapLoading = false
                self.diffMapProgress = 1
                self.diffMapScanFraction = 1
                self.refreshDiffNavigationState()
                Task {
                    await self.loadComparisonRows(
                        around: 0,
                        radius: HexScrollWindow.prefetchMargin,
                        cancelPrevious: false
                    )
                }
            }
        }
    }

    func navigateToNextDiff() -> Bool {
        guard case .comparison(let left, let right) = paneMode,
              comparisonDiffChunkIndex != nil else { return false }

        let after = comparisonCurrentDiffOffset ?? selectedOffset ?? -1
        let offset: Int?
        if !comparisonDiffRegions.isEmpty {
            offset = ByteCompareService.findNextDiffRegionStartWrapping(
                after: after,
                in: comparisonDiffRegions
            )
        } else {
            offset = ByteCompareService.findNextDiffOffsetWrapping(
                after: after,
                chunkIndex: comparisonDiffChunkIndex!,
                leftSize: left.fileSize,
                rightSize: right.fileSize,
                leftBytes: comparisonBytesProvider(side: .left),
                rightBytes: comparisonBytesProvider(side: .right)
            )
        }
        guard let offset else { return false }

        navigateToDiff(at: offset)
        refreshDiffNavigationState()
        return true
    }

    func navigateToPreviousDiff() -> Bool {
        guard case .comparison(let left, let right) = paneMode,
              comparisonDiffChunkIndex != nil else { return false }

        let before = comparisonCurrentDiffOffset ?? selectedOffset ?? fileSize
        let offset: Int?
        if !comparisonDiffRegions.isEmpty {
            offset = ByteCompareService.findPreviousDiffRegionStartWrapping(
                before: before,
                in: comparisonDiffRegions
            )
        } else {
            offset = ByteCompareService.findPreviousDiffOffsetWrapping(
                before: before,
                chunkIndex: comparisonDiffChunkIndex!,
                leftSize: left.fileSize,
                rightSize: right.fileSize,
                leftBytes: comparisonBytesProvider(side: .left),
                rightBytes: comparisonBytesProvider(side: .right)
            )
        }
        guard let offset else { return false }

        navigateToDiff(at: offset)
        refreshDiffNavigationState()
        return true
    }

    func navigateToDiff(at offset: Int) {
        guard offset >= 0, offset < fileSize else { return }
        comparisonNavGeneration &+= 1
        let generation = comparisonNavGeneration
        comparisonCurrentDiffOffset = offset
        let selection = HexSelection.single(at: offset)
        comparisonLeftSelection = selection
        comparisonRightSelection = selection
        comparisonActiveSide = .left
        scrollTargetOffset = offset
        scrollRevealOffset = offset
        let row = offset / bytesPerRow.rawValue
        Task {
            await loadComparisonRows(
                around: row,
                radius: HexScrollWindow.prefetchMargin,
                cancelPrevious: true
            )
            guard generation == self.comparisonNavGeneration else { return }
        }
    }

    private func comparisonBytesProvider(side: CompareSide) -> (Range<Int>) -> [UInt8] {
        guard case .comparison(let left, let right) = paneMode else {
            return { _ in [] }
        }
        let array = side == .left ? left.byteArray : right.byteArray
        return { range in
            array.bytes(in: UInt64(range.lowerBound)..<UInt64(range.upperBound))
        }
    }

    private func refreshDiffNavigationState() {
        let hasDifferences = !comparisonDiffRegions.isEmpty
            || (comparisonDiffChunkIndex?.hasDifferences ?? false)
        guard hasDifferences else {
            canNavigatePreviousDiff = false
            canNavigateNextDiff = false
            return
        }

        canNavigateNextDiff = true
        canNavigatePreviousDiff = true
    }

    func close() {
        resetComparisonMode()
        document?.close()
        document = nil
        paneMode = .document
        selection = nil
        highlights = []
        scrollTargetOffset = nil
        scrollRevealOffset = nil
        scrollSessionID &+= 1
        showCRCSheet = false
        showHashSheet = false
        showFillDialog = false
        showHistogramSheet = false
        showBinarySheet = false
        showFindSheet = false
        cancelFindSearch()
        findSession = nil
        binarySelectionStart = 0
        binarySelectionEnd = 0
        binarySelectionByteCount = 0
        crcInputBytes = []
        hashInputBytes = []
        hashInputRange = nil
        hashTitle = ""
        hashFileName = ""
        histogramCounts = Array(repeating: 0, count: 256)
        histogramTitle = ""
        histogramFileName = ""
        histogramByteCount = 0
        histogramUniqueValueCount = 0
        histogramTopEntries = []
        isHistogramLoading = false
        histogramProgress = 0
        histogramGeneration &+= 1
        isHistogramLoading = false
        histogramProgress = 0
        histogramGeneration &+= 1
        terminalHistory = []
        editingOffset = nil
        editingHexText = ""
        editingAppendedByte = false
        undoManager.removeAllActions()
    }

    func setBytesPerRow(_ setting: BytesPerRowSetting) {
        guard bytesPerRow != setting else { return }
        bytesPerRow = setting
        if isComparisonPane {
            compareRowCache.invalidate()
            compareRowCacheGeneration &+= 1
            comparisonRowRevision &+= 1
            comparisonRowLoadTask?.cancel()
            comparisonRowLoadTask = nil
            comparisonRowLoadGeneration &+= 1

            if let offset = comparisonCurrentDiffOffset ?? selectedOffset {
                scrollRevealOffset = offset
            }
        }
        bumpDataRevision()
    }

    func beginSelection(at offset: Int, extending: Bool = false) {
        guard offset >= 0, offset < fileSize else { return }

        if extending, let current = selection {
            selection = HexSelection(anchor: current.anchor, active: offset)
        } else {
            selection = .single(at: offset)
        }
    }

    func updateSelection(to offset: Int) {
        guard offset >= 0, offset < fileSize else { return }
        guard let current = selection else {
            selection = .single(at: offset)
            return
        }
        selection = HexSelection(anchor: current.anchor, active: offset)
    }

    func endSelection(at offset: Int) {
        updateSelection(to: offset)
    }

    func highlight(at offset: Int) -> HighlightColor? {
        highlights.first { $0.contains(offset) }?.color
    }

    func diffHighlight(at offset: Int, side: CompareSide) -> HighlightColor? {
        guard case .comparison(let left, let right) = paneMode else { return nil }
        let leftByte = offset < left.fileSize ? left.byte(at: offset) : nil
        let rightByte = offset < right.fileSize ? right.byte(at: offset) : nil
        return ByteCompareService.highlightColor(
            at: offset,
            side: side,
            leftSize: left.fileSize,
            rightSize: right.fileSize,
            leftByte: leftByte,
            rightByte: rightByte
        )
    }

    func comparisonSelection(for side: CompareSide) -> HexSelection? {
        switch side {
        case .left:
            comparisonLeftSelection
        case .right:
            comparisonRightSelection
        }
    }

    func beginComparisonSelection(at offset: Int, side: CompareSide, extending: Bool = false) {
        guard offset >= 0, offset < fileSize else { return }
        comparisonActiveSide = side

        let current = comparisonSelection(for: side)
        let newSelection: HexSelection
        if extending, let current {
            newSelection = HexSelection(anchor: current.anchor, active: offset)
        } else {
            newSelection = .single(at: offset)
        }
        setComparisonSelection(newSelection, for: side)
    }

    func updateComparisonSelection(to offset: Int, side: CompareSide) {
        guard offset >= 0, offset < fileSize else { return }
        comparisonActiveSide = side

        guard let current = comparisonSelection(for: side) else {
            setComparisonSelection(.single(at: offset), for: side)
            return
        }
        setComparisonSelection(HexSelection(anchor: current.anchor, active: offset), for: side)
    }

    func endComparisonSelection(at offset: Int, side: CompareSide) {
        updateComparisonSelection(to: offset, side: side)
    }

    func moveSelection(direction: SelectionMoveDirection, extending: Bool) {
        guard fileSize > 0 else { return }
        if editingOffset != nil {
            cancelEditing()
        }

        let delta = direction.byteDelta(bytesPerRow: bytesPerRow.rawValue)
        let currentOffset = selection?.active ?? 0
        let newOffset = max(0, min(fileSize - 1, currentOffset + delta))
        guard newOffset != currentOffset || selection != nil else { return }

        if extending {
            if let current = selection {
                selection = HexSelection(anchor: current.anchor, active: newOffset)
            } else {
                selection = HexSelection(anchor: currentOffset, active: newOffset)
            }
        } else {
            selection = .single(at: newOffset)
        }
        scrollRevealOffset = newOffset
    }

    func moveComparisonSelection(direction: SelectionMoveDirection, extending: Bool, side: CompareSide) {
        guard fileSize > 0 else { return }
        comparisonActiveSide = side

        let delta = direction.byteDelta(bytesPerRow: bytesPerRow.rawValue)
        let current = comparisonSelection(for: side)
        let currentOffset = current?.active ?? 0
        let newOffset = max(0, min(fileSize - 1, currentOffset + delta))
        guard newOffset != currentOffset || current != nil else { return }

        let newSelection: HexSelection
        if extending {
            if let current {
                newSelection = HexSelection(anchor: current.anchor, active: newOffset)
            } else {
                newSelection = HexSelection(anchor: currentOffset, active: newOffset)
            }
        } else {
            newSelection = .single(at: newOffset)
        }
        setComparisonSelection(newSelection, for: side)
        scrollRevealOffset = newOffset
    }

    func comparisonRowContext(for rowIndex: Int) -> CompareRowContext {
        if let cached = compareRowCache.context(for: rowIndex) {
            return cached
        }

        scheduleComparisonRowLoad(around: rowIndex)
        return emptyCompareRowContext(for: rowIndex)
    }

    func compareRowRevision(for rowIndex: Int) -> Int {
        compareRowCache.revision(for: rowIndex)
    }

    func navigateComparison(to row: Int) {
        guard row >= 0, row < rowCount else { return }
        let offset = row * bytesPerRow.rawValue
        scrollTargetOffset = offset
        scrollRevealOffset = offset
        Task {
            await loadComparisonRows(around: row, radius: 64, cancelPrevious: true)
        }
    }

    func loadComparisonRows(
        around row: Int,
        radius: Int = 64,
        cancelPrevious: Bool = true,
        force: Bool = false
    ) async {
        guard case .comparison(let left, let right) = paneMode else { return }

        let startRow = max(0, row - radius)
        let endRow = min(rowCount, row + radius + 1)
        guard startRow < endRow else { return }

        let rowRange = startRow..<endRow
        func rowsNeedLoad() -> Bool {
            force || rowRange.contains { compareRowCache.context(for: $0) == nil }
        }

        #if DEBUG
        print(
            "[compare-row-load] request row=\(row) radius=\(radius) force=\(force) " +
            "cancelPrevious=\(cancelPrevious) bpr=\(bytesPerRow.rawValue) rowRange=\(rowRange) " +
            "needsLoad=\(rowsNeedLoad()) cacheGeneration=\(compareRowCacheGeneration) " +
            "rowCount=\(rowCount)"
        )
        #endif
        guard rowsNeedLoad() else {
            #if DEBUG
            print("[compare-row-load] skipped: needsLoad=false")
            #endif
            return
        }

        if comparisonRowLoadTask != nil {
            await comparisonRowLoadTask?.value
            guard rowsNeedLoad() else {
                #if DEBUG
                print("[compare-row-load] skipped: satisfied by in-flight load")
                #endif
                return
            }
        }

        comparisonRowLoadGeneration &+= 1
        let loadGeneration = comparisonRowLoadGeneration

        let cacheGeneration = compareRowCacheGeneration
        let leftArray = left.byteArray
        let rightArray = right.byteArray
        let leftSize = left.fileSize
        let rightSize = right.fileSize
        let bytesPerRowValue = bytesPerRow.rawValue
        let fileSizeSnapshot = fileSize

        let task = Task.detached(priority: .userInitiated) {
            let batch = CompareRowLoader.buildContexts(
                for: rowRange,
                bytesPerRow: bytesPerRowValue,
                fileSize: fileSizeSnapshot,
                leftArray: leftArray,
                rightArray: rightArray,
                leftSize: leftSize,
                rightSize: rightSize
            )

            #if DEBUG
            let batchSummary = batch.map { row, context in
                let span = context.leftDiffSpans?.first
                return "row=\(row) left=\(context.leftBytes.count) right=\(context.rightBytes.count) spanCol=\(span?.startColumn ?? -1)"
            }.joined(separator: "; ")
            print(
                "[compare-row-load] built batch rows=\(rowRange) bpr=\(bytesPerRowValue) " +
                "fileSize=\(fileSizeSnapshot) leftSize=\(leftSize) rightSize=\(rightSize) " +
                "batchCount=\(batch.count) {\(batchSummary)} loadGeneration=\(loadGeneration)"
            )
            #endif

            await MainActor.run {
                if cacheGeneration != self.compareRowCacheGeneration {
                    #if DEBUG
                    print(
                        "[compare-row-load] skipped store: cache generation mismatch " +
                        "captured=\(cacheGeneration) current=\(self.compareRowCacheGeneration)"
                    )
                    #endif
                    return
                }
                if loadGeneration != self.comparisonRowLoadGeneration {
                    #if DEBUG
                    print(
                        "[compare-row-load] skipped store: load generation mismatch " +
                        "captured=\(loadGeneration) current=\(self.comparisonRowLoadGeneration)"
                    )
                    #endif
                    return
                }
                guard case .comparison = self.paneMode else {
                    #if DEBUG
                    print("[compare-row-load] skipped store: pane is not in comparison mode")
                    #endif
                    return
                }
                if batch.isEmpty {
                    #if DEBUG
                    print("[compare-row-load] skipped store: batch is empty")
                    #endif
                    return
                }
                let storedRows = self.compareRowCache.storeBatch(batch)
                self.comparisonRowRevision &+= 1
                #if DEBUG
                print(
                    "[compare-row-load] stored rows=\(storedRows) " +
                    "comparisonRowRevision=\(self.comparisonRowRevision)"
                )
                #endif
            }
        }

        comparisonRowLoadTask = task
        await task.value
        if loadGeneration == comparisonRowLoadGeneration {
            comparisonRowLoadTask = nil
        }
    }

    func awaitComparisonRowLoad() async {
        await comparisonRowLoadTask?.value
    }

    private func scheduleComparisonRowLoad(around row: Int) {
        Task {
            await loadComparisonRows(around: row, radius: 48)
        }
    }

    private func emptyCompareRowContext(for rowIndex: Int) -> CompareRowContext {
        CompareRowContext(
            leftBytes: [],
            rightBytes: [],
            leftDiffSpans: nil,
            rightDiffSpans: nil
        )
    }

    func comparisonRowBytes(for rowIndex: Int, side: CompareSide) -> [UInt8] {
        guard case .comparison(let left, let right) = paneMode else { return [] }
        let doc = side == .left ? left : right
        let offset = HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow.rawValue)
        let count = HexFormatter.byteCount(
            forRow: rowIndex,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow.rawValue
        )
        guard count > 0 else { return [] }
        let clampedEnd = min(offset + count, doc.fileSize)
        guard offset < clampedEnd else { return [] }
        return doc.bytes(in: offset..<clampedEnd)
    }

    func comparisonBytes(in range: Range<Int>, side: CompareSide) -> [UInt8] {
        guard case .comparison(let left, let right) = paneMode else { return [] }
        let doc = side == .left ? left : right
        let clamped = max(0, range.lowerBound)..<min(range.upperBound, doc.fileSize)
        guard clamped.lowerBound < clamped.upperBound else { return [] }
        return doc.bytes(in: clamped)
    }

    func copyComparisonSelection(side: CompareSide) {
        guard let selection = comparisonSelection(for: side) else { return }
        let bytes = comparisonBytes(in: selection.start..<(selection.end + 1), side: side)
        guard !bytes.isEmpty else { return }
        let hex = bytes.map { HexFormatter.hexPair(for: $0) }.joined(separator: " ")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }

    private func setComparisonSelection(_ selection: HexSelection, for side: CompareSide) {
        switch side {
        case .left:
            comparisonLeftSelection = selection
        case .right:
            comparisonRightSelection = selection
        }
        comparisonCurrentDiffOffset = selection.active
    }

    func addHighlight(color: HighlightColor) {
        guard let selection else { return }
        let start = selection.start
        let end = selection.end
        highlights.removeAll { $0.overlaps(rangeStart: start, rangeEnd: end) }
        highlights.append(HexHighlight(start: start, end: end, color: color))
        self.selection = nil
    }

    func removeHighlights(containing offset: Int) {
        highlights.removeAll { $0.contains(offset) }
    }

    func removeHighlight(id: UUID) {
        highlights.removeAll { $0.id == id }
    }

    func navigateToHighlight(_ highlight: HexHighlight) {
        selection = HexSelection(anchor: highlight.start, active: highlight.end)
        scrollTargetOffset = highlight.start
    }

    func clearScrollTarget() {
        scrollTargetOffset = nil
    }

    func clearScrollReveal() {
        scrollRevealOffset = nil
    }

    func copySelectionHex() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        let text = HexFormatter.hexString(for: data)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func saveSelectionAsBinary() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        guard !data.isEmpty else { return }

        let suggestedName = selectionExportSuggestedName(fileExtension: "bin")
        guard let url = FileAccessService.saveFilePanel(
            suggestedName: suggestedName,
            fileExtension: "bin"
        ) else {
            return
        }

        do {
            try Data(data).write(to: url, options: .atomic)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func saveSelectionAsHex() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        guard !data.isEmpty else { return }

        let suggestedName = selectionExportSuggestedName(fileExtension: "hex")
        guard let url = FileAccessService.saveFilePanel(
            suggestedName: suggestedName,
            fileExtension: "hex"
        ) else {
            return
        }

        let text = data.map { HexFormatter.hexPair(for: $0) }.joined()
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func requestFillSelection() {
        guard selection != nil else { return }
        showFillDialog = true
    }

    func fillSelection(with value: UInt8) {
        guard let selection, let document else { return }
        let range = selection.start..<(selection.end + 1)
        guard !range.isEmpty else { return }

        let oldValues = document.replaceBytes(in: range, with: value)
        document.markDirty()
        registerRangeUndo(range: range, oldValues: oldValues, newValue: value)
        bumpDataRevision()
    }

    func openCRCSheet() {
        guard let selection else { return }
        crcInputBytes = bytes(in: selection.start..<(selection.end + 1))
        showCRCSheet = true
    }

    func openHashForAll() {
        guard fileSize > 0 else { return }
        hashInputBytes = []
        hashInputRange = 0..<fileSize
        hashFileName = document?.displayName ?? String(localized: "Untitled")
        hashTitle = String(localized: "Entire file")
        showHashSheet = true
    }

    func openHashForSelection() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        guard !data.isEmpty else { return }
        hashInputBytes = data
        hashInputRange = nil
        hashFileName = document?.displayName ?? String(localized: "Untitled")
        hashTitle = String(
            localized: "Selection: 0x\(HexFormatter.offsetString(for: selection.start)) – 0x\(HexFormatter.offsetString(for: selection.end))"
        )
        showHashSheet = true
    }

    func openHashSheet() {
        openHashForSelection()
    }

    func openBinarySheet() {
        guard let selection else { return }
        let byteCount = selection.length
        guard byteCount > 0 else { return }

        binarySelectionStart = selection.start
        binarySelectionEnd = selection.end
        binarySelectionByteCount = byteCount
        showBinarySheet = true
    }

    func openHistogramForAll() {
        guard fileSize > 0, let document else { return }

        histogramGeneration &+= 1
        let generation = histogramGeneration
        let byteArray = document.byteArray
        let fileSizeSnapshot = fileSize

        resetHistogramPresentation(byteCount: fileSizeSnapshot)
        histogramFileName = document.displayName
        histogramTitle = String(localized: "Entire file")
        isHistogramLoading = true
        histogramProgress = 0
        showHistogramSheet = true

        Task.detached {
            var lastUIUpdate = ContinuousClock.now
            let uiInterval: Duration = .milliseconds(50)
            var chunkIndex = 0

            let counts = await HistogramBuilder.buildIncremental(
                in: 0..<fileSizeSnapshot,
                bytesProvider: { range in
                    byteArray.bytes(in: UInt64(range.lowerBound)..<UInt64(range.upperBound))
                },
                chunkSize: HistogramBuilder.progressChunkSize,
                onChunk: { counts, progress in
                    chunkIndex += 1
                    let now = ContinuousClock.now
                    let shouldPublish = progress >= 1.0
                        || chunkIndex == 1
                        || now - lastUIUpdate >= uiInterval
                    guard shouldPublish else { return }
                    lastUIUpdate = now

                    let countsSnapshot = counts
                    let updateTopEntries = progress >= 1.0 || chunkIndex % 4 == 0
                    await MainActor.run {
                        guard generation == self.histogramGeneration else { return }
                        self.applyHistogramChunk(
                            counts: countsSnapshot,
                            progress: progress,
                            updateTopEntries: updateTopEntries
                        )
                    }
                }
            )

            await MainActor.run {
                guard generation == self.histogramGeneration else { return }
                self.applyHistogramResults(counts)
            }
        }
    }

    func openHistogramForSelection() {
        guard let selection else { return }
        let selectionStart = selection.start
        let selectionEnd = selection.end
        let byteCount = selection.length
        guard byteCount > 0 else { return }

        histogramGeneration &+= 1
        let generation = histogramGeneration
        guard let document else { return }
        let byteArray = document.byteArray

        resetHistogramPresentation(byteCount: byteCount)
        histogramFileName = document.displayName
        histogramTitle = String(
            localized: "Selection: 0x\(HexFormatter.offsetString(for: selectionStart)) – 0x\(HexFormatter.offsetString(for: selectionEnd))"
        )
        isHistogramLoading = true
        histogramProgress = 0
        showHistogramSheet = true

        let range = selectionStart..<(selectionEnd + 1)

        Task.detached {
            var lastUIUpdate = ContinuousClock.now
            let uiInterval: Duration = .milliseconds(50)
            var chunkIndex = 0

            let counts = await HistogramBuilder.buildIncremental(
                in: range,
                bytesProvider: { subrange in
                    byteArray.bytes(in: UInt64(subrange.lowerBound)..<UInt64(subrange.upperBound))
                },
                chunkSize: HistogramBuilder.progressChunkSize,
                onChunk: { counts, progress in
                    chunkIndex += 1
                    let now = ContinuousClock.now
                    let shouldPublish = progress >= 1.0
                        || chunkIndex == 1
                        || now - lastUIUpdate >= uiInterval
                    guard shouldPublish else { return }
                    lastUIUpdate = now

                    let countsSnapshot = counts
                    let updateTopEntries = progress >= 1.0 || chunkIndex % 4 == 0
                    await MainActor.run {
                        guard generation == self.histogramGeneration else { return }
                        self.applyHistogramChunk(
                            counts: countsSnapshot,
                            progress: progress,
                            updateTopEntries: updateTopEntries
                        )
                    }
                }
            )

            await MainActor.run {
                guard generation == self.histogramGeneration else { return }
                self.applyHistogramResults(counts)
            }
        }
    }

    func openFindSheet() {
        showFindSheet = true
    }

    func closeFindSheet() {
        cancelFindSearch()
        if var session = findSession, !session.isScanningComplete {
            session.isScanningComplete = true
            findSession = session
        }
        showFindSheet = false
    }

    func clearFindResults() {
        cancelFindSearch()
        findSession = nil
    }

    var canFindPrevious: Bool {
        guard let session = findSession, session.hasMatches else { return false }
        return session.currentIndex > 0
    }

    var canFindNext: Bool {
        guard let session = findSession, session.hasMatches else { return false }
        return session.currentIndex + 1 < session.matches.count
    }

    func startFind(
        input: String,
        mode: FindPatternMode,
        entireFile: Bool,
        direction: FindDirection
    ) {
        switch BytePatternSearch.pattern(from: input, mode: mode) {
        case .failure:
            cancelFindSearch()
            findSession = nil
        case .success(let pattern):
            beginFindSearch()

            let queryText = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let generation = findGeneration
            let cursor = selectedOffset ?? 0
            let fileSizeSnapshot = fileSize
            guard let document else {
                finishFindSearch(generation: generation)
                return
            }

            let byteArray = document.byteArray
            let range = BytePatternSearch.searchRange(
                fileSize: fileSizeSnapshot,
                entireFile: entireFile,
                direction: direction,
                cursor: cursor
            )
            let shouldReverse = !entireFile && direction == .up
            let navigateOnFirstMatch = entireFile || direction == .down

            let bytesProvider = Self.makeFindBytesProvider(byteArray: byteArray)

            findSearchTask = Task.detached(priority: .userInitiated) {
                var lastUIUpdate = ContinuousClock.now
                let uiInterval: Duration = .milliseconds(50)
                var didNavigate = false

                let matches = await BytePatternSearch.findAllIncremental(
                    pattern: pattern,
                    in: range,
                    bytesProvider: bytesProvider,
                    onProgress: { progress in
                        let now = ContinuousClock.now
                        guard progress >= 1.0 || now - lastUIUpdate >= uiInterval else { return }
                        lastUIUpdate = now

                        await MainActor.run {
                            guard generation == self.findGeneration else { return }
                            self.findProgress = progress
                        }
                    },
                    onMatch: { offset in
                        await MainActor.run {
                            guard generation == self.findGeneration else { return }

                            if var session = self.findSession,
                               session.queryText == queryText,
                               session.pattern == pattern,
                               session.mode == mode,
                               session.entireFile == entireFile,
                               session.direction == direction {
                                if !session.matches.contains(offset) {
                                    session.matches.append(offset)
                                }
                                session.isScanningComplete = false
                                self.findSession = session
                            } else {
                                self.findSession = FindSession(
                                    queryText: queryText,
                                    pattern: pattern,
                                    mode: mode,
                                    entireFile: entireFile,
                                    direction: direction,
                                    matches: [offset],
                                    currentIndex: 0,
                                    isScanningComplete: false
                                )
                            }

                            if navigateOnFirstMatch, !didNavigate {
                                didNavigate = true
                                self.navigateToFindOffset(offset)
                            }
                        }
                    }
                )

                let finalMatches = shouldReverse ? Array(matches.reversed()) : matches

                await MainActor.run {
                    guard !Task.isCancelled, generation == self.findGeneration else { return }
                    self.finishFindSearch(generation: generation)

                    if finalMatches.isEmpty {
                        self.findSession = FindSession(
                            queryText: queryText,
                            pattern: pattern,
                            mode: mode,
                            entireFile: entireFile,
                            direction: direction,
                            matches: [],
                            currentIndex: -1,
                            isScanningComplete: true
                        )
                        return
                    }

                    self.findSession = FindSession(
                        queryText: queryText,
                        pattern: pattern,
                        mode: mode,
                        entireFile: entireFile,
                        direction: direction,
                        matches: finalMatches,
                        currentIndex: 0,
                        isScanningComplete: true
                    )

                    if !navigateOnFirstMatch {
                        self.navigateToFindOffset(finalMatches[0])
                    }
                }
            }
        }
    }

    func startFindNext() {
        guard let session = findSession else { return }

        beginFindSearch()
        let generation = findGeneration
        let afterOffset = session.currentMatch ?? selectedOffset ?? 0

        guard let document else {
            finishFindSearch(generation: generation)
            return
        }

        let byteArray = document.byteArray
        let fileSizeSnapshot = fileSize
        let pattern = session.pattern
        let entireFile = session.entireFile
        let direction = session.direction

        let bytesProvider = Self.makeFindBytesProvider(byteArray: byteArray)

        findSearchTask = Task.detached(priority: .userInitiated) {
            let nextOffset = BytePatternSearch.findNext(
                pattern: pattern,
                fileSize: fileSizeSnapshot,
                bytesProvider: bytesProvider,
                entireFile: entireFile,
                direction: direction,
                afterOffset: afterOffset
            )

            await MainActor.run {
                guard !Task.isCancelled, generation == self.findGeneration else { return }
                self.finishFindSearch(generation: generation)

                guard var updatedSession = self.findSession else { return }

                guard let nextOffset else { return }

                if let existingIndex = updatedSession.matches.firstIndex(of: nextOffset) {
                    updatedSession.currentIndex = existingIndex
                } else {
                    updatedSession.matches.append(nextOffset)
                    if updatedSession.entireFile || updatedSession.direction == .down {
                        updatedSession.matches.sort()
                    } else {
                        updatedSession.matches.sort(by: >)
                    }
                    updatedSession.currentIndex = updatedSession.matches.firstIndex(of: nextOffset) ?? 0
                }

                updatedSession.isScanningComplete = true
                self.findSession = updatedSession
                self.navigateToFindOffset(nextOffset)
            }
        }
    }

    @discardableResult
    func findPreviousMatch() -> FindResult {
        guard var session = findSession, session.hasMatches else { return .notFound }
        guard session.currentIndex > 0 else { return .notFound }

        session.currentIndex -= 1
        findSession = session
        if let offset = session.currentMatch {
            navigateToFindOffset(offset)
            return .found(session)
        }
        return .notFound
    }

    @discardableResult
    func findNextMatch() -> FindResult {
        guard var session = findSession, session.hasMatches else { return .notFound }
        guard session.currentIndex + 1 < session.matches.count else { return .notFound }

        session.currentIndex += 1
        findSession = session
        if let offset = session.currentMatch {
            navigateToFindOffset(offset)
            return .found(session)
        }
        return .notFound
    }

    private func navigateToFindOffset(_ offset: Int) {
        selection = .single(at: offset)
        scrollTargetOffset = offset
    }

    nonisolated private static func makeFindBytesProvider(byteArray: BTreeByteArray) -> (Range<Int>) -> [UInt8] {
        { range in
            guard !Task.isCancelled else { return [] }
            return byteArray.bytes(in: UInt64(range.lowerBound)..<UInt64(range.upperBound))
        }
    }

    private func beginFindSearch() {
        findSearchTask?.cancel()
        findGeneration &+= 1
        isFindLoading = true
        findProgress = 0
    }

    private func cancelFindSearch() {
        findSearchTask?.cancel()
        findSearchTask = nil
        findGeneration &+= 1
        isFindLoading = false
        findProgress = 0
    }

    func stopFind() {
        cancelFindSearch()
        if var session = findSession {
            session.isScanningComplete = true
            findSession = session
        }
    }

    private func finishFindSearch(generation: Int) {
        guard generation == findGeneration else { return }
        isFindLoading = false
        findProgress = 1
    }

    func executeTerminalCommand(_ input: String) {
        guard !isComparisonPane else { return }

        terminalHistory.append(TerminalLine(kind: .input, text: input))

        let result = TerminalCommandParser.execute(
            input,
            fileSize: fileSize,
            bytesProvider: { [weak self] range in
                self?.bytes(in: range) ?? []
            }
        )

        switch result {
        case .output(let text):
            terminalHistory.append(TerminalLine(kind: .output, text: text))
        case .navigate(let offset):
            selection = .single(at: offset)
            scrollTargetOffset = offset
            terminalHistory.append(
                TerminalLine(
                    kind: .output,
                    text: "→ 0x\(HexFormatter.offsetString(for: offset))"
                )
            )
        case .error(let message):
            terminalHistory.append(TerminalLine(kind: .error, text: message))
        }
    }

    func byte(at offset: Int) -> UInt8? {
        guard let document, offset >= 0, offset < document.fileSize else { return nil }
        return document.byte(at: offset)
    }

    func bytes(in range: Range<Int>) -> [UInt8] {
        guard let document else { return [] }
        let clamped = max(0, range.lowerBound)..<min(range.upperBound, document.fileSize)
        guard clamped.lowerBound < clamped.upperBound else { return [] }
        return document.bytes(in: clamped)
    }

    func rowBytes(for rowIndex: Int) -> [UInt8] {
        if let cached = documentRowCache.bytes(for: rowIndex) {
            return cached
        }
        return loadRowBytesSynchronously(for: rowIndex)
    }

    func ensureDocumentRowsLoadedSynchronously(for range: Range<Int>) {
        guard let document, case .document = paneMode, !range.isEmpty else { return }

        var didLoad = false
        for row in range {
            guard row >= 0, row < rowCount else { continue }
            if documentRowCache.bytes(for: row) == nil {
                _ = loadRowBytesSynchronously(for: row)
                didLoad = true
            }
        }

        if didLoad {
            documentRowRevision &+= 1
        }
    }

    func ensureComparisonRowsLoadedSynchronously(for range: Range<Int>) {
        // Compare mode uses async prefetch only to keep scrolling off the main thread.
    }

    func prefetchDocumentRows(for range: Range<Int>) {
        guard let document, case .document = paneMode else { return }
        guard !range.isEmpty else { return }
        guard documentRowCache.missingRows(in: range) else { return }

        documentRowLoadTask?.cancel()
        documentRowLoadGeneration &+= 1
        let loadGeneration = documentRowLoadGeneration
        let cacheGeneration = documentRowCacheGeneration
        let byteArray = document.byteArray
        let bytesPerRowValue = bytesPerRow.rawValue
        let fileSizeSnapshot = fileSize

        let task = Task.detached(priority: .userInitiated) {
            let batch = DocumentRowLoader.loadRows(
                for: range,
                bytesPerRow: bytesPerRowValue,
                fileSize: fileSizeSnapshot,
                byteArray: byteArray
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled,
                      loadGeneration == self.documentRowLoadGeneration,
                      cacheGeneration == self.documentRowCacheGeneration,
                      case .document = self.paneMode else { return }
                self.documentRowCache.storeBatch(batch)
                self.documentRowRevision &+= 1
            }
        }

        documentRowLoadTask = task
    }

    func typeHexDigit(_ character: Character) {
        guard isDocumentOpen, character.isHexDigit else { return }

        if editingHexText.isEmpty {
            guard let offset = editingOffset ?? selection?.start,
                  offset >= 0, offset <= fileSize else { return }

            if offset >= fileSize {
                guard appendPlaceholderByte() else { return }
                editingOffset = fileSize - 1
                editingAppendedByte = true
            } else {
                editingOffset = offset
                editingAppendedByte = false
            }

            editingHexText = String(character).uppercased()
            if let editingOffset {
                selection = .single(at: editingOffset)
            }
            return
        }

        guard let offset = editingOffset,
              let newValue = UInt8(editingHexText + String(character), radix: 16) else {
            return
        }

        let didCommit = commitByte(at: offset, value: newValue, wasAppended: editingAppendedByte)

        editingHexText = ""
        editingAppendedByte = false
        guard didCommit else {
            editingOffset = offset
            selection = .single(at: offset)
            return
        }

        let nextOffset = offset + 1
        if nextOffset < fileSize {
            editingOffset = nextOffset
            selection = .single(at: nextOffset)
        } else {
            editingOffset = fileSize - 1
            selection = .single(at: fileSize - 1)
        }
    }

    func backspaceEditing() {
        discardUncommittedPlaceholder()
        editingHexText = ""
        editingOffset = nil
    }

    func cancelEditing() {
        discardUncommittedPlaceholder()
        editingOffset = nil
        editingHexText = ""
    }

    func save() {
        guard let document else { return }
        do {
            try ByteArrayWriter.write(document.byteArray, to: document.url)
            document.collapseToFileBacking()
            document.markClean()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func saveAs() {
        guard let document else { return }
        guard let url = FileAccessService.saveFilePanel(suggestedName: document.displayName) else {
            return
        }

        do {
            try ByteArrayWriter.write(document.byteArray, to: url)
            loadFile(from: url)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func undo() {
        undoManager.undo()
    }

    func redo() {
        undoManager.redo()
    }

    @discardableResult
    private func commitByte(at offset: Int, value: UInt8, wasAppended: Bool) -> Bool {
        guard let document else { return false }

        if wasAppended {
            let oldValue = byte(at: offset) ?? 0
            if value != oldValue {
                guard document.replaceByte(at: offset, with: value) != nil else { return false }
            }
            document.markDirty()
            registerAppendUndo(at: offset, value: value)
            bumpDataRevisionAfterEdit(at: offset)
            return true
        }

        guard let oldValue = byte(at: offset) else { return false }
        guard value != oldValue else { return false }
        guard document.replaceByte(at: offset, with: value) != nil else { return false }
        document.markDirty()
        registerUndo(at: offset, oldValue: oldValue, newValue: value)
        bumpDataRevisionAfterEdit(at: offset)
        return true
    }

    private func appendByte(_ value: UInt8) {
        guard let document else { return }

        document.appendByte(value)
        document.markDirty()
        registerAppendUndo(at: fileSize - 1, value: value)
        bumpDataRevisionAfterEdit(at: fileSize - 1)
    }

    @discardableResult
    private func appendPlaceholderByte() -> Bool {
        guard let document else { return false }

        document.appendByte(0)
        document.markDirty()
        bumpDataRevisionAfterEdit(at: fileSize - 1)
        return true
    }

    private func discardUncommittedPlaceholder() {
        guard editingAppendedByte, let offset = editingOffset else { return }
        editingAppendedByte = false

        guard let document else { return }
        document.truncate(to: offset)
        document.markDirty()
        bumpDataRevision()
        if fileSize > 0 {
            selection = .single(at: min(offset, fileSize - 1))
        } else {
            selection = nil
        }
    }

    private func registerUndo(at offset: Int, oldValue: UInt8, newValue: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            target.applyByteChange(at: offset, from: newValue, to: oldValue)
            target.registerUndo(at: offset, oldValue: newValue, newValue: oldValue)
        }
    }

    private func registerAppendUndo(at offset: Int, value: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            target.undoAppend(at: offset)
            target.registerAppendRedo(at: offset, value: value)
        }
    }

    private func registerAppendRedo(at offset: Int, value: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            target.appendByte(value)
        }
    }

    private func undoAppend(at offset: Int) {
        guard let document, offset >= 0 else { return }
        document.truncate(to: offset)
        document.markDirty()
        cancelEditing()
        if fileSize > 0 {
            selection = .single(at: min(offset, fileSize - 1))
        } else {
            selection = nil
        }
        bumpDataRevision()
    }

    private func registerRangeUndo(range: Range<Int>, oldValues: [UInt8], newValue: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreRange(range: range, values: oldValues)
            target.registerRangeFillRedo(range: range, oldValues: oldValues, newValue: newValue)
        }
    }

    private func registerRangeFillRedo(range: Range<Int>, oldValues: [UInt8], newValue: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            guard let document = target.document else { return }
            _ = document.replaceBytes(in: range, with: newValue)
            document.markDirty()
            target.bumpDataRevision()
            target.registerRangeUndo(range: range, oldValues: oldValues, newValue: newValue)
        }
    }

    private func restoreRange(range: Range<Int>, values: [UInt8]) {
        guard let document, values.count == range.count else { return }
        for (index, offset) in range.enumerated() {
            _ = document.replaceByte(at: offset, with: values[index])
        }
        document.markDirty()
        bumpDataRevision()
    }

    private func applyByteChange(at offset: Int, from oldValue: UInt8, to newValue: UInt8) {
        guard let document else { return }
        _ = document.replaceByte(at: offset, with: newValue)
        document.markDirty()
        selection = .single(at: offset)
        bumpDataRevisionAfterEdit(at: offset)
    }

    private func resetComparisonMode() {
        if case .comparison(let left, let right) = paneMode {
            left.close()
            right.close()
        }
        comparisonLeftSelection = nil
        comparisonRightSelection = nil
        comparisonActiveSide = .left
        comparisonDiffMap = nil
        comparisonDiffChunkIndex = nil
        comparisonDiffRegions = []
        comparisonCurrentDiffOffset = nil
        canNavigatePreviousDiff = false
        canNavigateNextDiff = false
        isDiffMapLoading = false
        diffMapProgress = 0
        diffMapScanFraction = 0
        comparisonDiffMapGeneration &+= 1
        comparisonRowLoadTask?.cancel()
        comparisonRowLoadTask = nil
        comparisonRowLoadGeneration &+= 1
        compareRowCache.invalidate()
        compareRowCacheGeneration &+= 1
        comparisonRowRevision &+= 1
        histogramGeneration &+= 1
        isHistogramLoading = false
        histogramProgress = 0
    }

    private func resetHistogramPresentation(byteCount: Int) {
        histogramCounts = Array(repeating: 0, count: 256)
        histogramByteCount = byteCount
        histogramUniqueValueCount = 0
        histogramTopEntries = []
    }

    private func applyHistogramChunk(
        counts: [Int],
        progress: Double,
        updateTopEntries: Bool = true
    ) {
        histogramCounts = counts
        histogramProgress = progress

        guard updateTopEntries else { return }
        let entries = HistogramBuilder.nonZeroEntries(in: counts)
        histogramUniqueValueCount = entries.count
        histogramTopEntries = Array(entries.prefix(16))
    }

    private func applyHistogramResults(_ counts: [Int]) {
        applyHistogramChunk(counts: counts, progress: 1, updateTopEntries: true)
        isHistogramLoading = false
    }

    private func bumpDataRevision(fullInvalidate: Bool = true) {
        dataRevision &+= 1
        guard fullInvalidate else { return }
        documentRowCache.invalidate()
        documentRowCacheGeneration &+= 1
        documentRowLoadTask?.cancel()
        documentRowLoadTask = nil
        documentRowLoadGeneration &+= 1
    }

    private func bumpDataRevisionAfterEdit(at offset: Int) {
        patchRowCache(forOffset: offset)
        bumpDataRevision(fullInvalidate: false)
    }

    private func patchRowCache(forOffset offset: Int) {
        let bytesPerRowValue = bytesPerRow.rawValue
        guard bytesPerRowValue > 0 else { return }
        patchRowCache(forRow: offset / bytesPerRowValue)
    }

    private func patchRowCache(forRow row: Int) {
        guard let document else { return }
        let bytesPerRowValue = bytesPerRow.rawValue
        let offset = HexFormatter.rowOffset(for: row, bytesPerRow: bytesPerRowValue)
        let count = HexFormatter.byteCount(
            forRow: row,
            fileSize: fileSize,
            bytesPerRow: bytesPerRowValue
        )
        guard count > 0 else { return }
        let bytes = document.bytes(in: offset..<(offset + count))
        documentRowCache.patch(bytes, for: row)
    }

    private func loadRowBytesSynchronously(for rowIndex: Int) -> [UInt8] {
        guard let document else { return [] }
        let bytesPerRowValue = bytesPerRow.rawValue
        let offset = HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRowValue)
        let count = HexFormatter.byteCount(
            forRow: rowIndex,
            fileSize: fileSize,
            bytesPerRow: bytesPerRowValue
        )
        guard count > 0 else { return [] }
        let bytes = document.bytes(in: offset..<(offset + count))
        documentRowCache.patch(bytes, for: rowIndex)
        return bytes
    }

    private func selectionExportSuggestedName(fileExtension: String) -> String {
        let baseName = document?.displayName ?? String(localized: "selection")
        let nameWithoutExtension = (baseName as NSString).deletingPathExtension
        guard let selection else {
            return "\(nameWithoutExtension).\(fileExtension)"
        }
        let start = HexFormatter.offsetString(for: selection.start)
        let end = HexFormatter.offsetString(for: selection.end)
        return "\(nameWithoutExtension)_\(start)-\(end).\(fileExtension)"
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
