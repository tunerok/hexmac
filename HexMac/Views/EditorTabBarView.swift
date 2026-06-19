//
//  EditorTabBarView.swift
//  HexMac
//

import SwiftUI

struct EditorTabBarView: View {
    @Bindable var workspace: WorkspaceViewModel
    let group: EditorTabGroup

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(group.panes) { pane in
                        tabItem(for: pane)
                    }
                }
            }

            Button {
                workspace.openFileInNewTab(inGroup: group.id)
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .accessibilityLabel(String(localized: "Open File…"))
            .help(String(localized: "Open File…"))
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let paneID = UUID(uuidString: idString) else {
                return false
            }
            workspace.movePane(paneID, toGroupID: group.id)
            return true
        }
    }

    private func tabItem(for pane: DocumentPaneViewModel) -> some View {
        let isActive = workspace.activePaneID == pane.id

        return HStack(spacing: 6) {
            Text(pane.displayTitle)
                .lineLimit(1)
                .font(.callout)

            Button {
                workspace.requestClosePane(id: pane.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.activatePane(id: pane.id)
        }
        .contextMenu {
            Button(String(localized: "Split Right")) {
                workspace.splitPane(id: pane.id, axis: .horizontal)
            }
            .disabled(!pane.isDocumentOpen)

            Button(String(localized: "Split Down")) {
                workspace.splitPane(id: pane.id, axis: .vertical)
            }
            .disabled(!pane.isDocumentOpen)

            Divider()

            Button(String(localized: "Close Tab")) {
                workspace.requestClosePane(id: pane.id)
            }

            Button(String(localized: "Close Other Tabs")) {
                workspace.requestCloseOtherTabs(inGroup: group.id, except: pane.id)
            }
            .disabled(group.panes.count <= 1)

            Button(String(localized: "Close All Tabs")) {
                workspace.requestCloseAllTabs(inGroup: group.id)
            }
        }
        .draggable(pane.id.uuidString)
    }
}
