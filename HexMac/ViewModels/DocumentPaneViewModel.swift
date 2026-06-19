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
    var selection: HexSelection?
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

    private let undoManager = UndoManager()

    var isDocumentOpen: Bool {
        document != nil
    }

    var fileSize: Int {
        document?.fileSize ?? 0
    }

    var rowCount: Int {
        HexFormatter.rowCount(for: fileSize, bytesPerRow: bytesPerRow.rawValue)
    }

    var isDirty: Bool {
        document?.isDirty ?? false
    }

    var displayTitle: String {
        guard let document else {
            return String(localized: "Untitled")
        }
        if document.isDirty {
            return "\(document.displayName) •"
        }
        return document.displayName
    }

    var windowTitle: String {
        guard let document else {
            return String(localized: "HexMac")
        }
        if document.isDirty {
            return "\(document.displayName) — \(String(localized: "Edited"))"
        }
        return document.displayName
    }

    var selectedOffset: Int? {
        selection?.active
    }

    var canSave: Bool {
        isDocumentOpen && isDirty
    }

    var hasSelection: Bool {
        selection != nil
    }

    func loadFile(from url: URL) {
        do {
            document?.close()
            document = try HexDocument.open(url: url, readOnly: false)
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

    func close() {
        document?.close()
        document = nil
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
