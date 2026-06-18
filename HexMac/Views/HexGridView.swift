//
//  HexGridView.swift
//  HexMac
//

import SwiftUI

struct HexGridView: View {
    let rowCount: Int
    let fileSize: Int
    let bytesPerRow: Int
    let dataRevision: Int
    let selection: HexSelection?
    let editingOffset: Int?
    let scrollTargetOffset: Int?
    @Binding var editingHexText: String
    var focusedEditOffset: FocusState<Int?>.Binding
    let textEncoding: TextEncodingMode
    let highlightColor: (Int) -> HighlightColor?
    let rowBytes: (Int) -> [UInt8]
    let onFinishEditing: () -> Void
    let onBeginSelection: (Int, Bool) -> Void
    let onUpdateSelection: (Int) -> Void
    let onEndSelection: (Int) -> Void
    let onBeginEdit: (Int) -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onAddHighlight: (HighlightColor) -> Void
    let onRemoveHighlight: (Int) -> Void
    let onCopySelection: () -> Void
    let onClearSelection: () -> Void
    let onCalculateCRC: () -> Void
    let onScrollTargetHandled: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HexGridHeaderView(bytesPerRow: bytesPerRow)

                    Divider()

                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<rowCount, id: \.self) { rowIndex in
                                    HexRowView(
                                        rowIndex: rowIndex,
                                        bytes: rowBytes(rowIndex),
                                        fileSize: fileSize,
                                        bytesPerRow: bytesPerRow,
                                        selection: selection,
                                        editingOffset: editingOffset,
                                        editingHexText: $editingHexText,
                                        focusedEditOffset: focusedEditOffset,
                                        textEncoding: textEncoding,
                                        highlightColor: highlightColor,
                                        onCommitEdit: onCommitEdit,
                                        onCancelEdit: onCancelEdit
                                    )
                                    .id(rowIndex)
                                }
                            }
                            .overlay {
                                HexSelectionHandlingView(
                                    rowCount: rowCount,
                                    fileSize: fileSize,
                                    bytesPerRow: bytesPerRow,
                                    editingOffset: editingOffset,
                                    selection: selection,
                                    onFinishEditing: onFinishEditing,
                                    onBeginSelection: onBeginSelection,
                                    onUpdateSelection: onUpdateSelection,
                                    onEndSelection: onEndSelection,
                                    onBeginEdit: onBeginEdit,
                                    onAddHighlight: onAddHighlight,
                                    onRemoveHighlight: onRemoveHighlight,
                                    onCopySelection: onCopySelection,
                                    onClearSelection: onClearSelection,
                                    onCalculateCRC: onCalculateCRC,
                                    highlightColor: highlightColor
                                )
                            }
                        }
                        .frame(height: verticalScrollHeight(in: geometry))
                        .onChange(of: scrollTargetOffset) { _, target in
                            guard let target, bytesPerRow > 0 else { return }
                            let rowIndex = target / bytesPerRow
                            withAnimation {
                                proxy.scrollTo(rowIndex, anchor: .center)
                            }
                            onScrollTargetHandled()
                        }
                    }
                }
                .padding(HexGridLayout.contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func verticalScrollHeight(in geometry: GeometryProxy) -> CGFloat {
        let usedHeight = HexGridLayout.headerContentHeight
            + HexGridLayout.headerBottomPadding
            + HexGridLayout.dividerWidth
            + HexGridLayout.contentPadding * 2
        return max(0, geometry.size.height - usedHeight)
    }
}
