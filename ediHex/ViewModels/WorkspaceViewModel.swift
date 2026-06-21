//
//  WorkspaceViewModel.swift
//  ediHex
//

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceViewModel {
    var rootGroup: EditorGroupNode?
    var activePaneID: UUID?
    var activeGroupID: UUID?

    var pendingClosePaneID: UUID?
    var showClosePaneConfirmation = false

    var pendingClosePaneIDs: [UUID] = []
    var pendingClosePaneGroupID: UUID?
    var showClosePanesConfirmation = false

    var pendingCloseGroupID: UUID?
    var showCloseGroupConfirmation = false

    var errorMessage: String?
    var showError = false

    var showComparePicker = false
    var comparePickerPresetLeftPaneID: UUID?

    var showHelp = false

    var hasOpenPanes: Bool {
        !allPanes().isEmpty
    }

    var activePane: DocumentPaneViewModel? {
        guard let activePaneID else { return allPanes().first }
        return findPane(id: activePaneID) ?? allPanes().first
    }

    var isDocumentOpen: Bool {
        activePane?.isDocumentOpen ?? false
    }

    var isComparisonPane: Bool {
        activePane?.isComparisonPane ?? false
    }

    var canNavigateNextDiff: Bool {
        activePane?.canNavigateNextDiff ?? false
    }

    var canNavigatePreviousDiff: Bool {
        activePane?.canNavigatePreviousDiff ?? false
    }

    var canSave: Bool {
        activePane?.canSave ?? false
    }

    var hasSelection: Bool {
        activePane?.hasSelection ?? false
    }

    var fileSize: Int {
        activePane?.fileSize ?? 0
    }

    var windowTitle: String {
        activePane?.windowTitle ?? String(localized: "ediHex")
    }

    var bytesPerRow: BytesPerRowSetting {
        activePane?.bytesPerRow ?? .sixteen
    }

    var textEncoding: TextEncodingMode {
        activePane?.textEncoding ?? .ascii
    }

    // MARK: - Open

    func newFile() {
        do {
            guard let url = try FileAccessService.createNewFile() else { return }
            openFile(from: url)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func openFilePanel() {
        guard let url = FileAccessService.openFilePanel() else { return }
        openFile(from: url)
    }

    func openFile(from url: URL) {
        guard let pane = makePane(from: url) else { return }
        addPane(pane, activate: true)
    }

    func openFileInNewTab(inGroup groupID: UUID? = nil) {
        if let groupID {
            activateGroup(id: groupID)
        }
        openFilePanel()
    }

    private func makePane(from url: URL) -> DocumentPaneViewModel? {
        let pane = DocumentPaneViewModel()
        pane.loadFile(from: url)
        guard pane.isDocumentOpen else { return nil }
        return pane
    }

    private func addPane(_ pane: DocumentPaneViewModel, activate: Bool) {
        if rootGroup == nil {
            let group = EditorTabGroup(panes: [pane], activePaneID: pane.id)
            rootGroup = .leaf(group)
            activeGroupID = group.id
        } else if let groupID = targetGroupID() {
            updateLeaf(id: groupID) { group in
                group.panes.append(pane)
                group.activePaneID = pane.id
            }
        } else {
            let group = EditorTabGroup(panes: [pane], activePaneID: pane.id)
            rootGroup = .leaf(group)
            activeGroupID = group.id
        }

        if activate {
            activatePane(id: pane.id)
        }
    }

    private func targetGroupID() -> UUID? {
        if let activeGroupID, findTabGroup(id: activeGroupID) != nil {
            return activeGroupID
        }
        if let activePaneID, let groupID = findGroupID(containing: activePaneID) {
            return groupID
        }
        return firstLeafGroupID()
    }

    // MARK: - Activation

    func activatePane(id: UUID) {
        activePaneID = id
        if let groupID = findGroupID(containing: id) {
            activeGroupID = groupID
            updateLeaf(id: groupID) { group in
                group.activePaneID = id
            }
        }
        findPane(id: id)?.requestEditorFocus()
    }

    func activateGroup(id: UUID) {
        activeGroupID = id
        if let group = findTabGroup(id: id), let paneID = group.activePaneID ?? group.panes.first?.id {
            activePaneID = paneID
        }
    }

    // MARK: - Close

    func closeActivePane() {
        guard let paneID = activePaneID else { return }
        requestClosePane(id: paneID)
    }

    func requestClosePane(id: UUID) {
        guard let pane = findPane(id: id) else { return }
        if pane.isDirty {
            pendingClosePaneID = id
            showClosePaneConfirmation = true
            return
        }
        removePane(id: id)
    }

    func confirmClosePane(save: Bool) {
        guard let paneID = pendingClosePaneID else { return }
        defer {
            pendingClosePaneID = nil
            showClosePaneConfirmation = false
        }
        if save, let pane = findPane(id: paneID) {
            pane.save()
        }
        removePane(id: paneID)
    }

    func cancelClosePane() {
        pendingClosePaneID = nil
        showClosePaneConfirmation = false
    }

    func requestCloseAllTabs(inGroup groupID: UUID) {
        let paneIDs = panesInGroup(id: groupID).map(\.id)
        requestClosePanes(paneIDs, inGroup: groupID)
    }

    func requestCloseOtherTabs(inGroup groupID: UUID, except paneID: UUID) {
        activatePane(id: paneID)
        let paneIDs = panesInGroup(id: groupID).filter { $0.id != paneID }.map(\.id)
        requestClosePanes(paneIDs, inGroup: groupID)
    }

    func confirmClosePanes(save: Bool) {
        let paneIDs = pendingClosePaneIDs
        let groupID = pendingClosePaneGroupID
        defer {
            pendingClosePaneIDs = []
            pendingClosePaneGroupID = nil
            showClosePanesConfirmation = false
        }
        guard let groupID, !paneIDs.isEmpty else { return }
        if save {
            for id in paneIDs {
                findPane(id: id)?.save()
            }
        }
        removePanes(ids: paneIDs, fromGroup: groupID)
    }

    func cancelClosePanes() {
        pendingClosePaneIDs = []
        pendingClosePaneGroupID = nil
        showClosePanesConfirmation = false
    }

    private func requestClosePanes(_ paneIDs: [UUID], inGroup groupID: UUID) {
        guard !paneIDs.isEmpty else { return }
        let panes = paneIDs.compactMap { findPane(id: $0) }
        guard !panes.isEmpty else { return }

        if panes.contains(where: \.isDirty) {
            pendingClosePaneIDs = paneIDs
            pendingClosePaneGroupID = groupID
            showClosePanesConfirmation = true
            return
        }
        removePanes(ids: paneIDs, fromGroup: groupID)
    }

    func closeActiveGroup() {
        guard let paneID = activePaneID,
              let groupID = activeGroupID ?? findGroupID(containing: paneID) else { return }
        let panes = panesInGroup(id: groupID)
        if panes.contains(where: { $0.isDirty }) {
            pendingCloseGroupID = groupID
            showCloseGroupConfirmation = true
            return
        }
        removeGroup(id: groupID)
    }

    func confirmCloseGroup(save: Bool) {
        guard let groupID = pendingCloseGroupID else { return }
        defer {
            pendingCloseGroupID = nil
            showCloseGroupConfirmation = false
        }
        let panes = panesInGroup(id: groupID)
        if save {
            for pane in panes where pane.isDirty {
                pane.save()
            }
        }
        for pane in panes {
            pane.close()
        }
        removeGroup(id: groupID)
    }

    func cancelCloseGroup() {
        pendingCloseGroupID = nil
        showCloseGroupConfirmation = false
    }

    private func removePane(id: UUID) {
        guard let groupID = findGroupID(containing: id) else { return }
        guard let pane = findPane(id: id) else { return }

        var nextActivePaneID: UUID?
        updateLeaf(id: groupID) { group in
            group.panes.removeAll { $0.id == id }
            if group.activePaneID == id {
                group.activePaneID = group.panes.last?.id
            }
            nextActivePaneID = group.activePaneID
        }

        pane.close()

        rootGroup = collapse(node: rootGroup)

        if let nextActivePaneID, findPane(id: nextActivePaneID) != nil {
            activatePane(id: nextActivePaneID)
        } else if let first = allPanes().first {
            activatePane(id: first.id)
        } else {
            activePaneID = nil
            activeGroupID = nil
        }
    }

    private func removePanes(ids: [UUID], fromGroup groupID: UUID) {
        let idsToRemove = Set(ids)
        guard !idsToRemove.isEmpty else { return }

        for id in idsToRemove {
            findPane(id: id)?.close()
        }

        var nextActivePaneID: UUID?
        updateLeaf(id: groupID) { group in
            if let activePaneID = group.activePaneID, !idsToRemove.contains(activePaneID) {
                nextActivePaneID = activePaneID
            } else {
                nextActivePaneID = group.panes.first { !idsToRemove.contains($0.id) }?.id
            }
            group.panes.removeAll { idsToRemove.contains($0.id) }
            group.activePaneID = nextActivePaneID
        }

        rootGroup = collapse(node: rootGroup)

        if let nextActivePaneID, findPane(id: nextActivePaneID) != nil {
            activatePane(id: nextActivePaneID)
        } else if let first = allPanes().first {
            activatePane(id: first.id)
        } else {
            activePaneID = nil
            activeGroupID = nil
        }
    }

    private func removeGroup(id: UUID) {
        for pane in panesInGroup(id: id) {
            pane.close()
        }
        rootGroup = removeLeaf(id: id, from: rootGroup)
        rootGroup = collapse(node: rootGroup)

        if let first = allPanes().first {
            activatePane(id: first.id)
        } else {
            activePaneID = nil
            activeGroupID = nil
        }
    }

    // MARK: - Tabs

    func selectNextTab() {
        guard let paneID = activePaneID,
              let groupID = activeGroupID ?? findGroupID(containing: paneID),
              let group = findTabGroup(id: groupID),
              !group.panes.isEmpty else { return }

        let currentIndex: Int
        if let activePaneID, let index = group.panes.firstIndex(where: { $0.id == activePaneID }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let nextIndex = (currentIndex + 1) % group.panes.count
        activatePane(id: group.panes[nextIndex].id)
    }

    func selectPreviousTab() {
        guard let paneID = activePaneID,
              let groupID = activeGroupID ?? findGroupID(containing: paneID),
              let group = findTabGroup(id: groupID),
              !group.panes.isEmpty else { return }

        let currentIndex: Int
        if let activePaneID, let index = group.panes.firstIndex(where: { $0.id == activePaneID }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let previousIndex = (currentIndex - 1 + group.panes.count) % group.panes.count
        activatePane(id: group.panes[previousIndex].id)
    }

    func movePane(_ paneID: UUID, toGroupID targetGroupID: UUID) {
        guard let sourceGroupID = findGroupID(containing: paneID),
              sourceGroupID != targetGroupID,
              let pane = findPane(id: paneID) else {
            return
        }

        updateLeaf(id: sourceGroupID) { group in
            group.panes.removeAll { $0.id == paneID }
            if group.activePaneID == paneID {
                group.activePaneID = group.panes.last?.id
            }
        }

        updateLeaf(id: targetGroupID) { group in
            group.panes.append(pane)
            group.activePaneID = paneID
        }

        rootGroup = collapse(node: rootGroup)
        activatePane(id: paneID)
        activeGroupID = targetGroupID
    }

    // MARK: - Split

    func splitActive(axis: SplitAxis) {
        guard let pane = activePane,
              let groupID = findGroupID(containing: pane.id),
              let url = pane.document?.url,
              let newPane = makePane(from: url) else { return }
        let newGroup = EditorTabGroup(panes: [newPane], activePaneID: newPane.id)

        rootGroup = replaceLeaf(id: groupID, in: rootGroup) { group in
            .split(
                id: UUID(),
                axis: axis,
                ratio: 0.5,
                first: .leaf(group),
                second: .leaf(newGroup)
            )
        }

        activeGroupID = groupID
    }

    func splitPane(id: UUID, axis: SplitAxis) {
        activatePane(id: id)
        splitActive(axis: axis)
    }

    // MARK: - Active pane delegation

    func setBytesPerRow(_ setting: BytesPerRowSetting) {
        activePane?.setBytesPerRow(setting)
    }

    func setTextEncoding(_ mode: TextEncodingMode) {
        activePane?.textEncoding = mode
    }

    func save() {
        activePane?.save()
    }

    func saveAs() {
        activePane?.saveAs()
    }

    func undo() {
        activePane?.undo()
    }

    func redo() {
        activePane?.redo()
    }

    func copySelectionHex() {
        activePane?.copySelectionHex()
    }

    func openBinarySheet() {
        activePane?.openBinarySheet()
    }

    func requestFillSelection() {
        activePane?.requestFillSelection()
    }

    func openHistogramForAll() {
        activePane?.openHistogramForAll()
    }

    func openHistogramForSelection() {
        activePane?.openHistogramForSelection()
    }

    func openCRCSheet() {
        activePane?.openCRCSheet()
    }

    func openHashForAll() {
        activePane?.openHashForAll()
    }

    func openHashForSelection() {
        activePane?.openHashForSelection()
    }

    func openHashSheet() {
        activePane?.openHashSheet()
    }

    func openFindSheet() {
        activePane?.openFindSheet()
    }

    func navigateToNextDiff() {
        _ = activePane?.navigateToNextDiff()
    }

    func navigateToPreviousDiff() {
        _ = activePane?.navigateToPreviousDiff()
    }

    // MARK: - Compare

    func startCompare() {
        pickTwoFilesForCompare()
    }

    func compareWithActiveFile() {
        guard let pane = activePane,
              pane.isDocumentOpen,
              !pane.isComparisonPane,
              let leftURL = pane.document?.url else { return }
        pickSecondFileAndCompare(left: leftURL)
    }

    func beginCompare(with sourcePaneID: UUID) {
        guard let sourcePane = findPane(id: sourcePaneID),
              sourcePane.document?.url != nil else { return }

        let others = openDocumentPanes().filter { $0.id != sourcePaneID }
        if others.isEmpty {
            guard let leftURL = sourcePane.document?.url else { return }
            pickSecondFileAndCompare(left: leftURL)
        } else {
            comparePickerPresetLeftPaneID = sourcePaneID
            showComparePicker = true
        }
    }

    func openDocumentPanes() -> [DocumentPaneViewModel] {
        allPanes().filter { $0.isDocumentOpen && !$0.isComparisonPane }
    }

    func confirmCompare(leftPaneID: UUID, rightPaneID: UUID) {
        guard leftPaneID != rightPaneID else {
            presentError(String(localized: "Cannot compare a file with itself."))
            return
        }
        guard let leftURL = findPane(id: leftPaneID)?.document?.url,
              let rightURL = findPane(id: rightPaneID)?.document?.url else { return }
        cancelComparePicker()
        openComparison(left: leftURL, right: rightURL)
    }

    func cancelComparePicker() {
        showComparePicker = false
        comparePickerPresetLeftPaneID = nil
    }

    func openComparison(left: URL, right: URL) {
        let normalizedLeft = left.standardizedFileURL
        let normalizedRight = right.standardizedFileURL
        guard normalizedLeft != normalizedRight else {
            presentError(String(localized: "Cannot compare a file with itself."))
            return
        }

        let pane = DocumentPaneViewModel()
        pane.loadComparison(left: normalizedLeft, right: normalizedRight)
        guard pane.isComparisonPane else {
            if let errorMessage = pane.errorMessage {
                presentError(errorMessage)
            }
            return
        }
        addPane(pane, activate: true)
    }

    private func pickTwoFilesForCompare() {
        guard let firstURL = FileAccessService.openFilePanel() else { return }
        guard let secondURL = FileAccessService.openFilePanel() else { return }
        openComparison(left: firstURL, right: secondURL)
    }

    private func pickSecondFileAndCompare(left: URL) {
        guard let rightURL = FileAccessService.openFilePanel() else { return }
        openComparison(left: left, right: rightURL)
    }

    func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Tree helpers

    func allPanes() -> [DocumentPaneViewModel] {
        collectPanes(from: rootGroup)
    }

    func findPane(id: UUID) -> DocumentPaneViewModel? {
        allPanes().first { $0.id == id }
    }

    func findTabGroup(id: UUID) -> EditorTabGroup? {
        findLeaf(id: id, in: rootGroup)
    }

    func findGroupID(containing paneID: UUID) -> UUID? {
        findGroupID(containing: paneID, in: rootGroup)
    }

    func panesInGroup(id: UUID) -> [DocumentPaneViewModel] {
        findTabGroup(id: id)?.panes ?? []
    }

    func pendingClosePaneTitle() -> String {
        guard let id = pendingClosePaneID, let pane = findPane(id: id) else {
            return ""
        }
        return pane.document?.displayName ?? String(localized: "Untitled")
    }

    private func collectPanes(from node: EditorGroupNode?) -> [DocumentPaneViewModel] {
        guard let node else { return [] }
        switch node {
        case .leaf(let group):
            return group.panes
        case .split(_, _, _, let first, let second):
            return collectPanes(from: first) + collectPanes(from: second)
        }
    }

    private func findLeaf(id: UUID, in node: EditorGroupNode?) -> EditorTabGroup? {
        guard let node else { return nil }
        switch node {
        case .leaf(let group) where group.id == id:
            return group
        case .leaf:
            return nil
        case .split(_, _, _, let first, let second):
            return findLeaf(id: id, in: first) ?? findLeaf(id: id, in: second)
        }
    }

    private func findGroupID(containing paneID: UUID, in node: EditorGroupNode?) -> UUID? {
        guard let node else { return nil }
        switch node {
        case .leaf(let group):
            return group.panes.contains { $0.id == paneID } ? group.id : nil
        case .split(_, _, _, let first, let second):
            return findGroupID(containing: paneID, in: first)
                ?? findGroupID(containing: paneID, in: second)
        }
    }

    private func firstLeafGroupID() -> UUID? {
        guard let rootGroup else { return nil }
        switch rootGroup {
        case .leaf(let group):
            return group.id
        case .split(_, _, _, let first, _):
            return firstLeafGroupID(in: first)
        }
    }

    private func firstLeafGroupID(in node: EditorGroupNode) -> UUID? {
        switch node {
        case .leaf(let group):
            return group.id
        case .split(_, _, _, let first, _):
            return firstLeafGroupID(in: first)
        }
    }

    private func updateLeaf(id: UUID, _ transform: (inout EditorTabGroup) -> Void) {
        rootGroup = updateLeaf(id: id, in: rootGroup, transform: transform)
    }

    private func updateLeaf(
        id: UUID,
        in node: EditorGroupNode?,
        transform: (inout EditorTabGroup) -> Void
    ) -> EditorGroupNode? {
        guard let node else { return nil }
        switch node {
        case .leaf(var group) where group.id == id:
            transform(&group)
            return .leaf(group)
        case .leaf:
            return node
        case .split(let splitID, let axis, let ratio, let first, let second):
            return .split(
                id: splitID,
                axis: axis,
                ratio: ratio,
                first: updateLeaf(id: id, in: first, transform: transform) ?? first,
                second: updateLeaf(id: id, in: second, transform: transform) ?? second
            )
        }
    }

    private func replaceLeaf(
        id: UUID,
        in node: EditorGroupNode?,
        transform: (EditorTabGroup) -> EditorGroupNode
    ) -> EditorGroupNode? {
        guard let node else { return nil }
        switch node {
        case .leaf(let group) where group.id == id:
            return transform(group)
        case .leaf:
            return node
        case .split(let splitID, let axis, let ratio, let first, let second):
            return .split(
                id: splitID,
                axis: axis,
                ratio: ratio,
                first: replaceLeaf(id: id, in: first, transform: transform) ?? first,
                second: replaceLeaf(id: id, in: second, transform: transform) ?? second
            )
        }
    }

    private func removeLeaf(id: UUID, from node: EditorGroupNode?) -> EditorGroupNode? {
        guard let node else { return nil }
        switch node {
        case .leaf(let group) where group.id == id:
            return nil
        case .leaf:
            return node
        case .split(let splitID, let axis, let ratio, let first, let second):
            let newFirst = removeLeaf(id: id, from: first)
            let newSecond = removeLeaf(id: id, from: second)
            switch (newFirst, newSecond) {
            case (nil, nil):
                return nil
            case (let value?, nil):
                return value
            case (nil, let value?):
                return value
            case (let first?, let second?):
                return .split(id: splitID, axis: axis, ratio: ratio, first: first, second: second)
            }
        }
    }

    private func collapse(node: EditorGroupNode?) -> EditorGroupNode? {
        guard let node else { return nil }
        switch node {
        case .leaf(let group):
            return group.panes.isEmpty ? nil : node
        case .split(let id, let axis, let ratio, let first, let second):
            let collapsedFirst = collapse(node: first)
            let collapsedSecond = collapse(node: second)
            switch (collapsedFirst, collapsedSecond) {
            case (nil, nil):
                return nil
            case (let value?, nil):
                return value
            case (nil, let value?):
                return value
            case (let first?, let second?):
                return .split(id: id, axis: axis, ratio: ratio, first: first, second: second)
            }
        }
    }
}
