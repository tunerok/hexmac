//
//  ComparePaneView.swift
//  HexMac
//

import SwiftUI

struct ComparePaneView: View {
    @Bindable var workspace: WorkspaceViewModel
    @Bindable var pane: DocumentPaneViewModel

    @State private var visibleRowRange: ClosedRange<Int> = 0...0

    var body: some View {
        Group {
            if pane.rowCount == 0 {
                ContentUnavailableView(
                    String(localized: "Empty Comparison"),
                    systemImage: "doc.on.doc",
                    description: Text("Both files are empty")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    compareToolbar

                    HStack(spacing: 0) {
                        CompareHexGridView(
                            pane: pane,
                            visibleRowRange: $visibleRowRange,
                            onActivate: {
                                workspace.activatePane(id: pane.id)
                            }
                        )
                        .id(pane.scrollSessionID)
                        .layoutPriority(1)

                        Divider()

                        CompareMinimapView(
                            diffMap: pane.comparisonDiffMap,
                            isLoading: pane.isDiffMapLoading,
                            progress: pane.isDiffMapLoading ? pane.diffMapProgress : nil,
                            visibleRowRange: visibleRowRange,
                            rowCount: pane.rowCount,
                            onNavigate: { row in
                                pane.navigateComparison(to: row)
                            }
                        )
                    }
                }
            }
        }
        .onTapGesture {
            workspace.activatePane(id: pane.id)
        }
    }

    private var compareToolbar: some View {
        HStack(spacing: 4) {
            Text(pane.comparisonLeftName)
                .lineLimit(1)
            Text("↔")
                .foregroundStyle(.tertiary)
            Text(pane.comparisonRightName)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.bar)
    }
}
