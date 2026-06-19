//
//  HexGridView.swift
//  HexMac
//

import SwiftUI

struct HexGridView: View {
    private static let scrollbarColumnWidth: CGFloat = 16

    let rowCount: Int
    let fileSize: Int
    let bytesPerRow: Int
    let dataRevision: Int
    let documentRowRevision: Int
    let selection: HexSelection?
    let editingOffset: Int?
    let scrollTargetOffset: Int?
    let editingHexText: String
    let textEncoding: TextEncodingMode
    let isReadOnly: Bool
    let highlights: [HexHighlight]
    let linkedScrollRow: Binding<Int?>?
    let onVisibleRowChanged: ((Int) -> Void)?
    let highlightColor: (Int) -> HighlightColor?
    let rowBytes: (Int) -> [UInt8]
    let onPrefetchRows: (Range<Int>) -> Void
    let onEnsureVisibleRowsLoaded: (Range<Int>) -> Void
    let onBeginSelection: (Int, Bool) -> Void
    let onUpdateSelection: (Int) -> Void
    let onEndSelection: (Int) -> Void
    let onHexDigit: (Character) -> Void
    let onBackspace: () -> Void
    let onCancelEdit: () -> Void
    let onAddHighlight: (HighlightColor) -> Void
    let onRemoveHighlight: (Int) -> Void
    let onCopySelection: () -> Void
    let onClearSelection: () -> Void
    let onCalculateCRC: () -> Void
    let onCalculateHash: () -> Void
    let onShowBinary: () -> Void
    let onSaveSelectionAsBinary: () -> Void
    let onSaveSelectionAsHex: () -> Void
    let onScrollTargetHandled: () -> Void

    @State private var firstVisibleRow = 0

    private var scrollTargetRow: Int? {
        guard let scrollTargetOffset, bytesPerRow > 0 else { return nil }
        return scrollTargetOffset / bytesPerRow
    }

    init(
        rowCount: Int,
        fileSize: Int,
        bytesPerRow: Int,
        dataRevision: Int,
        documentRowRevision: Int,
        selection: HexSelection?,
        editingOffset: Int?,
        scrollTargetOffset: Int?,
        editingHexText: String,
        textEncoding: TextEncodingMode,
        isReadOnly: Bool = false,
        highlights: [HexHighlight] = [],
        linkedScrollRow: Binding<Int?>? = nil,
        onVisibleRowChanged: ((Int) -> Void)? = nil,
        highlightColor: @escaping (Int) -> HighlightColor?,
        rowBytes: @escaping (Int) -> [UInt8],
        onPrefetchRows: @escaping (Range<Int>) -> Void,
        onEnsureVisibleRowsLoaded: @escaping (Range<Int>) -> Void,
        onBeginSelection: @escaping (Int, Bool) -> Void,
        onUpdateSelection: @escaping (Int) -> Void,
        onEndSelection: @escaping (Int) -> Void,
        onHexDigit: @escaping (Character) -> Void,
        onBackspace: @escaping () -> Void,
        onCancelEdit: @escaping () -> Void,
        onAddHighlight: @escaping (HighlightColor) -> Void,
        onRemoveHighlight: @escaping (Int) -> Void,
        onCopySelection: @escaping () -> Void,
        onClearSelection: @escaping () -> Void,
        onCalculateCRC: @escaping () -> Void,
        onCalculateHash: @escaping () -> Void,
        onShowBinary: @escaping () -> Void,
        onSaveSelectionAsBinary: @escaping () -> Void,
        onSaveSelectionAsHex: @escaping () -> Void,
        onScrollTargetHandled: @escaping () -> Void
    ) {
        self.rowCount = rowCount
        self.fileSize = fileSize
        self.bytesPerRow = bytesPerRow
        self.dataRevision = dataRevision
        self.documentRowRevision = documentRowRevision
        self.selection = selection
        self.editingOffset = editingOffset
        self.scrollTargetOffset = scrollTargetOffset
        self.editingHexText = editingHexText
        self.textEncoding = textEncoding
        self.isReadOnly = isReadOnly
        self.highlights = highlights
        self.linkedScrollRow = linkedScrollRow
        self.onVisibleRowChanged = onVisibleRowChanged
        self.highlightColor = highlightColor
        self.rowBytes = rowBytes
        self.onPrefetchRows = onPrefetchRows
        self.onEnsureVisibleRowsLoaded = onEnsureVisibleRowsLoaded
        self.onBeginSelection = onBeginSelection
        self.onUpdateSelection = onUpdateSelection
        self.onEndSelection = onEndSelection
        self.onHexDigit = onHexDigit
        self.onBackspace = onBackspace
        self.onCancelEdit = onCancelEdit
        self.onAddHighlight = onAddHighlight
        self.onRemoveHighlight = onRemoveHighlight
        self.onCopySelection = onCopySelection
        self.onClearSelection = onClearSelection
        self.onCalculateCRC = onCalculateCRC
        self.onCalculateHash = onCalculateHash
        self.onShowBinary = onShowBinary
        self.onSaveSelectionAsBinary = onSaveSelectionAsBinary
        self.onSaveSelectionAsHex = onSaveSelectionAsHex
        self.onScrollTargetHandled = onScrollTargetHandled
    }

    var body: some View {
        GeometryReader { geometry in
            let gridHeight = verticalScrollHeight(in: geometry)
            let visibleRowCount = max(
                1,
                Int((gridHeight - HexGridLayout.contentPadding) / HexGridLayout.rowHeight)
            )

            HStack(spacing: 0) {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        HexGridHeaderView(bytesPerRow: bytesPerRow)
                        Divider()
                        viewportGrid(visibleRowCount: visibleRowCount, height: gridHeight)
                    }
                    .padding(.leading, HexGridLayout.contentPadding)
                    .padding(.trailing, HexGridLayout.contentPadding)
                }

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: HexGridLayout.headerTotalHeight)
                    HexVerticalScrollbar(
                        firstVisibleRow: $firstVisibleRow,
                        rowCount: rowCount,
                        visibleRowCount: visibleRowCount
                    )
                    .frame(height: gridHeight)
                }
                .frame(width: Self.scrollbarColumnWidth)
                .padding(.trailing, HexGridLayout.contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func viewportGrid(visibleRowCount: Int, height: CGFloat) -> some View {
        HexViewportScrollView(
            firstVisibleRow: $firstVisibleRow,
            rowCount: rowCount,
            bytesPerRow: bytesPerRow,
            visibleRowCount: visibleRowCount,
            scrollTargetRow: scrollTargetRow,
            scrollAnchor: .top,
            linkedScrollRow: linkedScrollRow,
            onVisibleRowChanged: onVisibleRowChanged,
            onVisibleRowRangeChanged: nil,
            onPrefetchRange: onPrefetchRows,
            onEnsureVisibleRowsLoaded: onEnsureVisibleRowsLoaded,
            onScrollTargetHandled: onScrollTargetHandled,
            rowContent: { rowIndex in
                HexRowView(
                    rowIndex: rowIndex,
                    bytes: rowBytes(rowIndex),
                    fileSize: fileSize,
                    bytesPerRow: bytesPerRow,
                    selection: selection,
                    editingOffset: editingOffset,
                    editingHexText: editingHexText,
                    textEncoding: textEncoding,
                    highlightColor: highlightColor,
                    userHexSpans: HexHighlightSpans.spans(
                        for: rowIndex,
                        bytesPerRow: bytesPerRow,
                        fileSize: fileSize,
                        highlights: highlights
                    )
                )
                .equatable()
                .id(rowIdentity(for: rowIndex))
            },
            overlay: { firstVisibleRow in
                HexSelectionHandlingView(
                    rowCount: rowCount,
                    fileSize: fileSize,
                    bytesPerRow: bytesPerRow,
                    firstVisibleRow: firstVisibleRow,
                    editingOffset: editingOffset,
                    selection: selection,
                    isReadOnly: isReadOnly,
                    onBeginSelection: onBeginSelection,
                    onUpdateSelection: onUpdateSelection,
                    onEndSelection: onEndSelection,
                    onHexDigit: onHexDigit,
                    onBackspace: onBackspace,
                    onCancelEdit: onCancelEdit,
                    onAddHighlight: onAddHighlight,
                    onRemoveHighlight: onRemoveHighlight,
                    onCopySelection: onCopySelection,
                    onClearSelection: onClearSelection,
                    onCalculateCRC: onCalculateCRC,
                    onCalculateHash: onCalculateHash,
                    onShowBinary: onShowBinary,
                    onSaveSelectionAsBinary: onSaveSelectionAsBinary,
                    onSaveSelectionAsHex: onSaveSelectionAsHex,
                    highlightColor: highlightColor
                )
            }
        )
        .frame(height: height)
    }

    private func rowIdentity(for rowIndex: Int) -> String {
        let rowOffset = HexFormatter.rowOffset(for: rowIndex, bytesPerRow: bytesPerRow)
        let rowEnd = rowOffset + bytesPerRow - 1
        let isEditingRow = editingOffset.map { $0 >= rowOffset && $0 <= rowEnd } ?? false
        let editingTag = isEditingRow ? "\(editingOffset ?? -1)-\(editingHexText)" : "none"
        return "\(rowIndex)-\(dataRevision)-\(documentRowRevision)-\(editingTag)"
    }

    private func verticalScrollHeight(in geometry: GeometryProxy) -> CGFloat {
        let usedHeight = HexGridLayout.headerContentHeight
            + HexGridLayout.headerBottomPadding
            + HexGridLayout.dividerWidth
        return max(0, geometry.size.height - usedHeight)
    }
}
