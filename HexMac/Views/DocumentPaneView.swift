//
//  DocumentPaneView.swift
//  HexMac
//

import SwiftUI

struct DocumentPaneView: View {
    @Bindable var workspace: WorkspaceViewModel
    @Bindable var pane: DocumentPaneViewModel

    var body: some View {
        Group {
            if pane.isComparisonPane {
                ComparePaneView(workspace: workspace, pane: pane)
            } else if pane.rowCount == 0 {
                ContentUnavailableView(
                    String(localized: "Empty File"),
                    systemImage: "doc",
                    description: Text("This file contains no data")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                hexGrid
                    .id(pane.scrollSessionID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onTapGesture {
            workspace.activatePane(id: pane.id)
        }
    }

    private var hexGrid: some View {
        HexGridView(
            rowCount: pane.rowCount,
            fileSize: pane.fileSize,
            bytesPerRow: pane.bytesPerRow.rawValue,
            dataRevision: pane.dataRevision,
            documentRowRevision: pane.documentRowRevision,
            selection: pane.selection,
            editingOffset: pane.editingOffset,
            scrollTargetOffset: pane.scrollTargetOffset,
            editingHexText: pane.editingHexText,
            textEncoding: pane.textEncoding,
            highlights: pane.highlights,
            highlightColor: { pane.highlight(at: $0) },
            rowBytes: { pane.rowBytes(for: $0) },
            onPrefetchRows: { range in
                pane.prefetchDocumentRows(for: range)
            },
            onEnsureVisibleRowsLoaded: { range in
                pane.ensureDocumentRowsLoadedSynchronously(for: range)
            },
            onBeginSelection: { offset, extending in
                workspace.activatePane(id: pane.id)
                pane.beginSelection(at: offset, extending: extending)
            },
            onUpdateSelection: { offset in
                pane.updateSelection(to: offset)
            },
            onEndSelection: { offset in
                pane.endSelection(at: offset)
            },
            onHexDigit: { character in
                pane.typeHexDigit(character)
            },
            onBackspace: {
                pane.backspaceEditing()
            },
            onCancelEdit: {
                pane.cancelEditing()
            },
            onAddHighlight: { color in
                pane.addHighlight(color: color)
            },
            onRemoveHighlight: { offset in
                pane.removeHighlights(containing: offset)
            },
            onCopySelection: {
                pane.copySelectionHex()
            },
            onClearSelection: {
                pane.requestFillSelection()
            },
            onCalculateCRC: {
                pane.openCRCSheet()
            },
            onCalculateHash: {
                pane.openHashSheet()
            },
            onShowBinary: {
                pane.openBinarySheet()
            },
            onSaveSelectionAsBinary: {
                pane.saveSelectionAsBinary()
            },
            onSaveSelectionAsHex: {
                pane.saveSelectionAsHex()
            },
            onScrollTargetHandled: {
                pane.clearScrollTarget()
            }
        )
    }
}
