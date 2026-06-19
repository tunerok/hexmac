//
//  CompareHexGridView.swift
//  HexMac
//

import SwiftUI

struct CompareHexGridView: View {
    private static let scrollbarColumnWidth: CGFloat = 16

    @Bindable var pane: DocumentPaneViewModel
    @Binding var visibleRowRange: ClosedRange<Int>
    let onActivate: () -> Void

    @State private var firstVisibleRow = 0

    private var scrollTargetRow: Int? {
        guard let target = pane.scrollTargetOffset, pane.bytesPerRow.rawValue > 0 else { return nil }
        return target / pane.bytesPerRow.rawValue
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
                        pairedHeaders
                        Divider()
                        HexViewportScrollView(
                            firstVisibleRow: $firstVisibleRow,
                            rowCount: pane.rowCount,
                            bytesPerRow: pane.bytesPerRow.rawValue,
                            visibleRowCount: visibleRowCount,
                            scrollTargetRow: scrollTargetRow,
                            scrollAnchor: .top,
                            linkedScrollRow: nil,
                            onVisibleRowChanged: nil,
                            onVisibleRowRangeChanged: { range in
                                guard range != visibleRowRange else { return }
                                visibleRowRange = range
                                pane.preloadComparisonRows(for: range)
                            },
                            onPrefetchRange: { range in
                                guard !range.isEmpty else { return }
                                let midpoint = (range.lowerBound + range.upperBound) / 2
                                Task {
                                    await pane.loadComparisonRows(
                                        around: midpoint,
                                        radius: HexScrollWindow.prefetchMargin,
                                        cancelPrevious: false
                                    )
                                }
                            },
                            onEnsureVisibleRowsLoaded: { range in
                                pane.ensureComparisonRowsLoadedSynchronously(for: range)
                            },
                            onScrollTargetHandled: {
                                pane.clearScrollTarget()
                            },
                            rowContent: { rowIndex in
                                pairedRow(rowIndex: rowIndex)
                            },
                            overlay: { firstVisibleRow in
                                selectionOverlay(firstVisibleRow: firstVisibleRow)
                            }
                        )
                        .frame(height: gridHeight)
                    }
                    .padding(.leading, HexGridLayout.contentPadding)
                    .padding(.trailing, HexGridLayout.contentPadding)
                }

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: HexGridLayout.headerTotalHeight)
                    HexVerticalScrollbar(
                        firstVisibleRow: $firstVisibleRow,
                        rowCount: pane.rowCount,
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
        .id("\(rowIndex)-\(pane.comparisonRowRevision)")
    }

    private func selectionOverlay(firstVisibleRow: Int) -> some View {
        let sideWidth = Self.sideContentWidth(bytesPerRow: pane.bytesPerRow.rawValue)

        return HStack(spacing: 0) {
            selectionHandlingView(
                side: .left,
                selection: pane.comparisonLeftSelection,
                width: sideWidth,
                firstVisibleRow: firstVisibleRow
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
                width: sideWidth,
                firstVisibleRow: firstVisibleRow
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
        firstVisibleRow: Int,
        onBegin: @escaping (Int, Bool) -> Void,
        onUpdate: @escaping (Int) -> Void,
        onEnd: @escaping (Int) -> Void,
        onCopy: @escaping () -> Void
    ) -> some View {
        HexSelectionHandlingView(
            rowCount: pane.rowCount,
            fileSize: pane.fileSize,
            bytesPerRow: pane.bytesPerRow.rawValue,
            firstVisibleRow: firstVisibleRow,
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
        return max(0, geometry.size.height - usedHeight)
    }

    static func sideContentWidth(bytesPerRow: Int) -> CGFloat {
        HexGridLayout.offsetColumnWidth
            + HexGridLayout.hexColumnLeadingPadding
            + HexFormatter.hexColumnWidth(for: bytesPerRow)
            + HexGridLayout.dividerSectionWidth
            + HexFormatter.textColumnWidth(for: bytesPerRow)
    }
}
