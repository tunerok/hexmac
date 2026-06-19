//
//  DocumentPaneViewModel.swift
//  HexMac
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
    var hashTitle = ""
    var hashFileName = ""
    var histogramCounts: [Int] = Array(repeating: 0, count: 256)
    var histogramTitle = ""
    var histogramFileName = ""
    var histogramByteCount = 0
    var terminalHistory: [TerminalLine] = []
    var editingOffset: Int?
    var editingHexText = ""
    @ObservationIgnored private var editingAppendedByte = false
    var errorMessage: String?
    var showError = false
    private(set) var dataRevision = 0
    private(set) var comparisonDiffIndex: CompareDiffIndex?
    private(set) var isDiffMapLoading = false
    private(set) var isComparisonExporting = false
    @ObservationIgnored private var comparisonDiffMapGeneration = 0

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
            return String(localized: "HexMac")
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
            terminalHistory = []
            findSession = nil
            editingOffset = nil
            editingHexText = ""
            editingAppendedByte = false
            undoManager.removeAllActions()
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
            comparisonLeftSelection = fileSize > 0 ? .single(at: 0) : nil
            comparisonRightSelection = fileSize > 0 ? .single(at: 0) : nil
            comparisonActiveSide = .left
            highlights = []
            scrollTargetOffset = nil
            terminalHistory = []
            findSession = nil
            editingOffset = nil
            editingHexText = ""
            editingAppendedByte = false
            undoManager.removeAllActions()
            bumpDataRevision()
            rebuildComparisonDiffIndex()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func rebuildComparisonDiffIndex(bucketCount: Int = ByteCompareService.defaultBucketCount) {
        guard case .comparison(let left, let right) = paneMode else {
            comparisonDiffIndex = nil
            isDiffMapLoading = false
            return
        }

        comparisonDiffMapGeneration &+= 1
        let generation = comparisonDiffMapGeneration
        isDiffMapLoading = true
        comparisonDiffIndex = nil

        let leftFile = left.mappedFile
        let rightFile = right.mappedFile
        let leftSize = left.fileSize
        let rightSize = right.fileSize

        Task.detached {
            let index = ByteCompareService.buildDiffIndex(
                leftSize: leftSize,
                rightSize: rightSize,
                leftByte: { offset in try? leftFile.byte(at: offset) },
                rightByte: { offset in try? rightFile.byte(at: offset) },
                bucketCount: bucketCount
            )

            await MainActor.run {
                guard generation == self.comparisonDiffMapGeneration,
                      case .comparison = self.paneMode else { return }
                self.comparisonDiffIndex = index
                self.isDiffMapLoading = false
            }
        }
    }

    func exportComparisonDiff(format: CompareDiffExportFormat) {
        guard case .comparison(let left, let right) = paneMode else { return }
        guard !isComparisonExporting else { return }

        let leftBase = (left.displayName as NSString).deletingPathExtension
        let rightBase = (right.displayName as NSString).deletingPathExtension
        let suggestedName = "comparison_\(leftBase)_vs_\(rightBase).\(format.fileExtension)"

        guard let url = FileAccessService.saveFilePanel(
            suggestedName: suggestedName,
            fileExtension: format.fileExtension
        ) else { return }

        let diffIndex = comparisonDiffIndex
        let leftFile = left.mappedFile
        let rightFile = right.mappedFile
        let leftSize = left.fileSize
        let rightSize = right.fileSize
        let leftName = left.displayName
        let rightName = right.displayName

        isComparisonExporting = true

        Task.detached {
            let entries: [DiffEntry]
            if let diffIndex {
                entries = ByteCompareService.collectDiffEntries(
                    from: diffIndex,
                    leftSize: leftSize,
                    rightSize: rightSize,
                    leftByte: { offset in try? leftFile.byte(at: offset) },
                    rightByte: { offset in try? rightFile.byte(at: offset) }
                )
            } else {
                entries = ByteCompareService.collectDiffEntries(
                    leftSize: leftSize,
                    rightSize: rightSize,
                    leftByte: { offset in try? leftFile.byte(at: offset) },
                    rightByte: { offset in try? rightFile.byte(at: offset) }
                )
            }

            let content: String
            switch format {
            case .text:
                content = ByteCompareService.formatTextReport(
                    entries: entries,
                    leftName: leftName,
                    rightName: rightName
                )
            case .csv:
                content = ByteCompareService.formatCSV(entries: entries)
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                await MainActor.run {
                    self.isComparisonExporting = false
                }
            } catch {
                await MainActor.run {
                    self.isComparisonExporting = false
                    self.presentError(error.localizedDescription)
                }
            }
        }
    }

    func close() {
        resetComparisonMode()
        document?.close()
        document = nil
        paneMode = .document
        selection = nil
        highlights = []
        scrollTargetOffset = nil
        showCRCSheet = false
        showHashSheet = false
        showFillDialog = false
        showHistogramSheet = false
        showBinarySheet = false
        showFindSheet = false
        findSession = nil
        binarySelectionStart = 0
        binarySelectionEnd = 0
        binarySelectionByteCount = 0
        crcInputBytes = []
        hashInputBytes = []
        hashTitle = ""
        hashFileName = ""
        histogramCounts = Array(repeating: 0, count: 256)
        histogramTitle = ""
        histogramFileName = ""
        histogramByteCount = 0
        terminalHistory = []
        editingOffset = nil
        editingHexText = ""
        editingAppendedByte = false
        undoManager.removeAllActions()
    }

    func setBytesPerRow(_ setting: BytesPerRowSetting) {
        guard bytesPerRow != setting else { return }
        bytesPerRow = setting
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
        comparisonDiffIndex?.highlight(at: offset, side: side)
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

    func comparisonRowContext(for rowIndex: Int) -> CompareRowContext {
        let bytesPerRowValue = bytesPerRow.rawValue
        let offset = HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRowValue)
        let count = HexFormatter.byteCount(
            forRow: rowIndex,
            fileSize: fileSize,
            bytesPerRow: bytesPerRowValue
        )

        let leftBytes = comparisonRowBytes(for: rowIndex, side: .left)
        let rightBytes = comparisonRowBytes(for: rowIndex, side: .right)

        guard count > 0, let index = comparisonDiffIndex else {
            let empty = Array<HighlightColor?>(repeating: nil, count: count)
            return CompareRowContext(
                leftBytes: leftBytes,
                rightBytes: rightBytes,
                leftHighlights: empty,
                rightHighlights: empty
            )
        }

        let range = offset..<(offset + count)
        return CompareRowContext(
            leftBytes: leftBytes,
            rightBytes: rightBytes,
            leftHighlights: index.highlights(in: range, side: .left),
            rightHighlights: index.highlights(in: range, side: .right)
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
        return (try? doc.mappedFile.bytes(in: offset..<clampedEnd)) ?? []
    }

    func comparisonBytes(in range: Range<Int>, side: CompareSide) -> [UInt8] {
        guard case .comparison(let left, let right) = paneMode else { return [] }
        let doc = side == .left ? left : right
        let clamped = max(0, range.lowerBound)..<min(range.upperBound, doc.fileSize)
        guard clamped.lowerBound < clamped.upperBound else { return [] }
        return (try? doc.mappedFile.bytes(in: clamped)) ?? []
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

        do {
            let oldValues = try document.mappedFile.replaceBytes(in: range, with: value)
            document.markDirty()
            registerRangeUndo(range: range, oldValues: oldValues, newValue: value)
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func openCRCSheet() {
        guard let selection else { return }
        crcInputBytes = bytes(in: selection.start..<(selection.end + 1))
        showCRCSheet = true
    }

    func openHashForAll() {
        guard fileSize > 0 else { return }
        hashInputBytes = bytes(in: 0..<fileSize)
        hashFileName = document?.displayName ?? String(localized: "Untitled")
        hashTitle = String(localized: "Entire file")
        showHashSheet = true
    }

    func openHashForSelection() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        guard !data.isEmpty else { return }
        hashInputBytes = data
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
        guard fileSize > 0 else { return }
        let data = bytes(in: 0..<fileSize)
        histogramCounts = HistogramBuilder.build(from: data)
        histogramByteCount = data.count
        histogramFileName = document?.displayName ?? String(localized: "Untitled")
        histogramTitle = String(localized: "Entire file")
        showHistogramSheet = true
    }

    func openHistogramForSelection() {
        guard let selection else { return }
        let data = bytes(in: selection.start..<(selection.end + 1))
        guard !data.isEmpty else { return }
        histogramCounts = HistogramBuilder.build(from: data)
        histogramByteCount = data.count
        histogramFileName = document?.displayName ?? String(localized: "Untitled")
        histogramTitle = String(
            localized: "Selection: 0x\(HexFormatter.offsetString(for: selection.start)) – 0x\(HexFormatter.offsetString(for: selection.end))"
        )
        showHistogramSheet = true
    }

    func openFindSheet() {
        showFindSheet = true
    }

    func closeFindSheet() {
        showFindSheet = false
        findSession = nil
    }

    func performFind(
        input: String,
        mode: FindPatternMode,
        entireFile: Bool,
        direction: FindDirection
    ) -> FindResult {
        switch BytePatternSearch.pattern(from: input, mode: mode) {
        case .failure:
            return .notFound
        case .success(let pattern):
            let cursor = selectedOffset ?? 0
            let matches = BytePatternSearch.search(
                pattern: pattern,
                fileSize: fileSize,
                bytesProvider: { [weak self] range in
                    self?.bytes(in: range) ?? []
                },
                entireFile: entireFile,
                direction: direction,
                cursor: cursor
            )

            guard let first = matches.first else {
                findSession = FindSession(
                    pattern: pattern,
                    mode: mode,
                    entireFile: entireFile,
                    direction: direction,
                    matches: [],
                    currentIndex: -1
                )
                return .notFound
            }

            var session = FindSession(
                pattern: pattern,
                mode: mode,
                entireFile: entireFile,
                direction: direction,
                matches: matches,
                currentIndex: 0
            )
            findSession = session
            navigateToFindOffset(first)
            return .found(session)
        }
    }

    @discardableResult
    func findNext() -> FindResult {
        guard var session = findSession else { return .notFound }

        let afterOffset = session.currentMatch ?? selectedOffset ?? 0
        guard let nextOffset = BytePatternSearch.findNext(
            pattern: session.pattern,
            fileSize: fileSize,
            bytesProvider: { [weak self] range in
                self?.bytes(in: range) ?? []
            },
            entireFile: session.entireFile,
            direction: session.direction,
            afterOffset: afterOffset
        ) else {
            return .notFound
        }

        if let existingIndex = session.matches.firstIndex(of: nextOffset) {
            session.currentIndex = existingIndex
        } else {
            session.matches.append(nextOffset)
            session.currentIndex = session.matches.count - 1
        }

        findSession = session
        navigateToFindOffset(nextOffset)
        return .found(session)
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

    func executeTerminalCommand(_ input: String) {
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
        return try? document.mappedFile.byte(at: offset)
    }

    func bytes(in range: Range<Int>) -> [UInt8] {
        guard let document else { return [] }
        let clamped = max(0, range.lowerBound)..<min(range.upperBound, document.fileSize)
        guard clamped.lowerBound < clamped.upperBound else { return [] }
        return (try? document.mappedFile.bytes(in: clamped)) ?? []
    }

    func rowBytes(for rowIndex: Int) -> [UInt8] {
        let offset = HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow.rawValue)
        let count = HexFormatter.byteCount(
            forRow: rowIndex,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow.rawValue
        )
        guard count > 0 else { return [] }
        return bytes(in: offset..<(offset + count))
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

        commitByte(at: offset, value: newValue, wasAppended: editingAppendedByte)

        editingHexText = ""
        editingAppendedByte = false
        let nextOffset = offset + 1
        editingOffset = nextOffset
        if nextOffset < fileSize {
            selection = .single(at: nextOffset)
        } else if offset < fileSize {
            selection = .single(at: offset)
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
            try document.mappedFile.sync()
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
            let data = buildFullData()
            try data.write(to: url, options: .atomic)
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

    private func commitByte(at offset: Int, value: UInt8, wasAppended: Bool) {
        guard let document else { return }

        do {
            if wasAppended {
                let oldValue = byte(at: offset) ?? 0
                if value != oldValue {
                    try document.mappedFile.replaceByte(at: offset, with: value)
                }
                document.markDirty()
                registerAppendUndo(at: offset, value: value)
                bumpDataRevision()
            } else {
                guard let oldValue = byte(at: offset) else { return }
                guard value != oldValue else { return }
                try document.mappedFile.replaceByte(at: offset, with: value)
                document.markDirty()
                registerUndo(at: offset, oldValue: oldValue, newValue: value)
                bumpDataRevision()
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func appendByte(_ value: UInt8) {
        guard let document else { return }

        do {
            try document.mappedFile.appendByte(value)
            document.markDirty()
            registerAppendUndo(at: fileSize - 1, value: value)
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    @discardableResult
    private func appendPlaceholderByte() -> Bool {
        guard let document else { return false }

        do {
            try document.mappedFile.appendByte(0)
            document.markDirty()
            bumpDataRevision()
            return true
        } catch {
            presentError(error.localizedDescription)
            return false
        }
    }

    private func discardUncommittedPlaceholder() {
        guard editingAppendedByte, let offset = editingOffset else { return }
        editingAppendedByte = false

        guard let document else { return }
        do {
            try document.mappedFile.resize(to: offset)
            document.markDirty()
            bumpDataRevision()
            if fileSize > 0 {
                selection = .single(at: min(offset, fileSize - 1))
            } else {
                selection = nil
            }
        } catch {
            presentError(error.localizedDescription)
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
        do {
            try document.mappedFile.resize(to: offset)
            document.markDirty()
            cancelEditing()
            if fileSize > 0 {
                selection = .single(at: min(offset, fileSize - 1))
            } else {
                selection = nil
            }
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
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
            do {
                _ = try document.mappedFile.replaceBytes(in: range, with: newValue)
                document.markDirty()
                target.bumpDataRevision()
                target.registerRangeUndo(range: range, oldValues: oldValues, newValue: newValue)
            } catch {
                target.presentError(error.localizedDescription)
            }
        }
    }

    private func restoreRange(range: Range<Int>, values: [UInt8]) {
        guard let document, values.count == range.count else { return }
        do {
            for (index, offset) in range.enumerated() {
                try document.mappedFile.replaceByte(at: offset, with: values[index])
            }
            document.markDirty()
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func applyByteChange(at offset: Int, from oldValue: UInt8, to newValue: UInt8) {
        guard let document else { return }
        do {
            try document.mappedFile.replaceByte(at: offset, with: newValue)
            document.markDirty()
            selection = .single(at: offset)
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func buildFullData() -> Data {
        guard let document else { return Data() }
        var data = Data(count: document.fileSize)
        for offset in 0..<document.fileSize {
            if let byte = byte(at: offset) {
                data[offset] = byte
            }
        }
        return data
    }

    private func resetComparisonMode() {
        if case .comparison(let left, let right) = paneMode {
            left.close()
            right.close()
        }
        comparisonLeftSelection = nil
        comparisonRightSelection = nil
        comparisonActiveSide = .left
        comparisonDiffIndex = nil
        isDiffMapLoading = false
        isComparisonExporting = false
        comparisonDiffMapGeneration &+= 1
    }

    private func bumpDataRevision() {
        dataRevision &+= 1
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
