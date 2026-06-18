//
//  HexEditorViewModel.swift
//  HexMac
//

import Foundation
import Observation

@MainActor
@Observable
final class HexEditorViewModel {
    private(set) var document: HexDocument?
    var selection: HexSelection?
    var textEncoding: TextEncodingMode = .ascii
    var bytesPerRow: BytesPerRowSetting = .sixteen
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
