//
//  ContentView.swift
//  HexMac
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var workspace: WorkspaceViewModel
    @AppStorage("textEncoding") private var storedEncoding = TextEncodingMode.ascii.rawValue

    var body: some View {
        Group {
            if workspace.hasOpenPanes {
                WorkspaceView(workspace: workspace)
            } else {
                EmptyStateView(onOpen: workspace.openFilePanel, onNew: workspace.newFile)
            }
        }
        .frame(minWidth: 792, minHeight: 480)
        .navigationTitle(workspace.windowTitle)
        .toolbarRole(.editor)
        .onAppear {
            syncEncodingFromStorage()
        }
        .onChange(of: storedEncoding) { _, _ in
            syncEncodingFromStorage()
        }
        .onChange(of: workspace.activePane?.textEncoding) { _, newValue in
            if let newValue {
                storedEncoding = newValue.rawValue
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .sheet(isPresented: $workspace.showHelp) {
            HelpView {
                workspace.showHelp = false
            }
        }
        .alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { workspace.showError },
                set: { workspace.showError = $0 }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    private func syncEncodingFromStorage() {
        let mode = TextEncodingMode(rawValue: storedEncoding) ?? .ascii
        if let pane = workspace.activePane, pane.textEncoding != mode {
            pane.textEncoding = mode
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            Task { @MainActor in
                workspace.openFile(from: url)
            }
        }
        return true
    }
}

#Preview {
    ContentView(workspace: WorkspaceViewModel())
}
