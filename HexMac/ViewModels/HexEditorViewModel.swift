//
//  HexEditorViewModel.swift
//  HexMac
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class HexEditorViewModel {
    private(set) var document: HexDocument?
    var selection: HexSelection?
    var textEncoding: TextEncodingMode = .ascii
    var bytesPerRow: BytesPerRowSetting = .sixteen
    var highlights: [HexHighlight] = []
    var scrollTargetOffset: Int?
    var showCRCSheet = false
    var showFillDialog = false
    var crcInputBytes: [UInt8] = []
    var terminalHistory: [TerminalLine] = []
    var editingOffset: Int?
    var editingHexText = ""
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

    func openFile(from url: URL) {
        closeDocument()

        do {
            document = try HexDocument.open(url: url, readOnly: false)
            selection = fileSize > 0 ? .single(at: 0) : nil
            bumpDataRevision()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func openFilePanel() {
        guard let url = FileAccessService.openFilePanel() else { return }
        openFile(from: url)
    }

    func closeDocument() {
        document?.close()
        document = nil
        selection = nil
        highlights = []
        scrollTargetOffset = nil
        showCRCSheet = false
        showFillDialog = false
        crcInputBytes = []
        terminalHistory = []
        editingOffset = nil
        editingHexText = ""
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

    func selectByte(at offset: Int, extending: Bool = false) {
        beginSelection(at: offset, extending: extending)
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

    func beginEditing(at offset: Int) {
        guard let value = byte(at: offset) else { return }
        editingOffset = offset
        editingHexText = HexFormatter.hexPair(for: value)
        selectByte(at: offset)
    }

    func cancelEditing() {
        editingOffset = nil
        editingHexText = ""
    }

    @discardableResult
    func commitEditing() -> Bool {
        guard let offset = editingOffset,
              let document,
              let normalized = HexFormatter.normalizedHexInput(editingHexText),
              let newValue = UInt8(normalized, radix: 16),
              let oldValue = byte(at: offset) else {
            if editingHexText.isEmpty {
                cancelEditing()
            }
            return false
        }

        editingHexText = normalized

        guard newValue != oldValue else {
            cancelEditing()
            return true
        }

        do {
            try document.mappedFile.replaceByte(at: offset, with: newValue)
            document.markDirty()
            registerUndo(at: offset, oldValue: oldValue, newValue: newValue)
            cancelEditing()
            bumpDataRevision()
            return true
        } catch {
            presentError(error.localizedDescription)
            return false
        }
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
            openFile(from: url)
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

    private func registerUndo(at offset: Int, oldValue: UInt8, newValue: UInt8) {
        undoManager.registerUndo(withTarget: self) { target in
            target.applyByteChange(at: offset, from: newValue, to: oldValue)
            target.registerUndo(at: offset, oldValue: newValue, newValue: oldValue)
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

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
