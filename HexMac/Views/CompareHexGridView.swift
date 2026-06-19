//
//  CompareHexGridView.swift
//  HexMac
//

import SwiftUI

struct CompareHexGridView: View {
    @Bindable var pane: DocumentPaneViewModel
    @Binding var visibleRowRange: ClosedRange<Int>
    @Binding var scrollToRow: Int?
    let onActivate: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    pairedHeaders

                    Divider()

                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<pane.rowCount, id: \.self) { rowIndex in
                                    pairedRow(rowIndex: rowIndex)
                                        .id(rowIndex)
                                }
                            }
                            .overlay {
                                selectionOverlay
                            }
                        }
                        .frame(height: verticalScrollHeight(in: geometry))
                        .onScrollGeometryChange(for: ClosedRange<Int>.self) { geometry in
                            visibleRowRange(from: geometry)
                        } action: { _, range in
                            guard range != visibleRowRange else { return }
                            visibleRowRange = range
                        }
                        .onChange(of: pane.scrollTargetOffset) { _, target in
                            guard let target, pane.bytesPerRow.rawValue > 0 else { return }
                            let rowIndex = target / pane.bytesPerRow.rawValue
                            proxy.scrollTo(rowIndex, anchor: .center)
                            pane.clearScrollTarget()
                        }
                        .onChange(of: scrollToRow) { _, row in
                            guard let row else { return }
                            proxy.scrollTo(row, anchor: .top)
                            scrollToRow = nil
                        }
                    }
                }
                .padding(HexGridLayout.contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var pairedHeaders: some View {
        HStack(spacing: 0) {
            HexGridHeaderView(bytesPerRow: pane.bytesPerRow.rawValue)
            panelSeparator
            HexGridHeaderView(bytesPerRow: pane.bytesPerRow.rawValue)
        }
    }

    private func pairedRow(rowIndex: Int) -> some View {
        let context = pane.comparisonRowContext(for: rowIndex)

        return HStack(spacing: 0) {
            HexRowView(
                rowIndex: rowIndex,
                bytes: context.leftBytes,
                fileSize: pane.fileSize,
                bytesPerRow: pane.bytesPerRow.rawValue,
                selection: pane.comparisonLeftSelection,
                editingOffset: nil,
                editingHexText: "",
                textEncoding: pane.textEncoding,
                highlightColor: { _ in nil },
                columnHighlights: context.leftHighlights
            )

            panelSeparator

            HexRowView(
                rowIndex: rowIndex,
                bytes: context.rightBytes,
                fileSize: pane.fileSize,
                bytesPerRow: pane.bytesPerRow.rawValue,
                selection: pane.comparisonRightSelection,
                editingOffset: nil,
                editingHexText: "",
                textEncoding: pane.textEncoding,
                highlightColor: { _ in nil },
                columnHighlights: context.rightHighlights
            )
        }
    }

    private var selectionOverlay: some View {
        let sideWidth = Self.sideContentWidth(bytesPerRow: pane.bytesPerRow.rawValue)

        return HStack(spacing: 0) {
            selectionHandlingView(
                side: .left,
                selection: pane.comparisonLeftSelection,
                width: sideWidth
            ) { offset, extending in
                onActivate()
                pane.beginComparisonSelection(at: offset, side: .left, extending: extending)
            } onUpdate: { offset in
                pane.updateComparisonSelection(to: offset, side: .left)
            } onEnd: { offset in
                pane.endComparisonSelection(at: offset, side: .left)
            } onCopy: {
                pane.copyComparisonSelection(side: .left)
            }

            panelSeparator

            selectionHandlingView(
                side: .right,
                selection: pane.comparisonRightSelection,
                width: sideWidth
            ) { offset, extending in
                onActivate()
                pane.beginComparisonSelection(at: offset, side: .right, extending: extending)
            } onUpdate: { offset in
                pane.updateComparisonSelection(to: offset, side: .right)
            } onEnd: { offset in
                pane.endComparisonSelection(at: offset, side: .right)
            } onCopy: {
                pane.copyComparisonSelection(side: .right)
            }
        }
    }

    private func selectionHandlingView(
        side: CompareSide,
        selection: HexSelection?,
        width: CGFloat,
        onBegin: @escaping (Int, Bool) -> Void,
        onUpdate: @escaping (Int) -> Void,
        onEnd: @escaping (Int) -> Void,
        onCopy: @escaping () -> Void
    ) -> some View {
        HexSelectionHandlingView(
            rowCount: pane.rowCount,
            fileSize: pane.fileSize,
            bytesPerRow: pane.bytesPerRow.rawValue,
            editingOffset: nil,
            selection: selection,
            isReadOnly: true,
            onBeginSelection: onBegin,
            onUpdateSelection: onUpdate,
            onEndSelection: onEnd,
            onHexDigit: { _ in },
            onBackspace: {},
            onCancelEdit: {},
            onAddHighlight: { _ in },
            onRemoveHighlight: { _ in },
            onCopySelection: onCopy,
            onClearSelection: {},
            onCalculateCRC: {},
            onCalculateHash: {},
            onShowBinary: {},
            onSaveSelectionAsBinary: {},
            onSaveSelectionAsHex: {},
            highlightColor: { pane.diffHighlight(at: $0, side: side) }
        )
        .frame(width: width, alignment: .leading)
        .clipped()
    }

    private var panelSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 1)
    }

    private func verticalScrollHeight(in geometry: GeometryProxy) -> CGFloat {
        let usedHeight = HexGridLayout.headerContentHeight
            + HexGridLayout.headerBottomPadding
            + HexGridLayout.dividerWidth
            + HexGridLayout.contentPadding * 2
        return max(0, geometry.size.height - usedHeight)
    }

    private func visibleRowRange(from geometry: ScrollGeometry) -> ClosedRange<Int> {
        let offsetY = geometry.contentOffset.y + geometry.contentInsets.top
        let viewportHeight = geometry.containerSize.height
        guard pane.rowCount > 0 else { return 0...0 }

        let startRow = min(pane.rowCount - 1, max(0, Int(offsetY / HexGridLayout.rowHeight)))
        let endRow = min(
            pane.rowCount - 1,
            max(startRow, Int((offsetY + viewportHeight) / HexGridLayout.rowHeight))
        )
        return startRow...endRow
    }

    static func sideContentWidth(bytesPerRow: Int) -> CGFloat {
        HexGridLayout.offsetColumnWidth
            + HexGridLayout.hexColumnLeadingPadding
            + HexFormatter.hexColumnWidth(for: bytesPerRow)
            + HexGridLayout.dividerSectionWidth
            + HexFormatter.textColumnWidth(for: bytesPerRow)
    }
}
