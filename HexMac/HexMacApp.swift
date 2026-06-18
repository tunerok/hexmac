//
//  HexMacApp.swift
//  HexMac
//

import SwiftUI

@main
struct HexMacApp: App {
    @State private var viewModel = HexEditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .newItem) {
                Button(String(localized: "Open…")) {
                    viewModel.openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button(String(localized: "Save")) {
                    viewModel.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!viewModel.canSave)

                Button(String(localized: "Save As…")) {
                    viewModel.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!viewModel.isDocumentOpen)
            }

            CommandGroup(replacing: .undoRedo) {
                Button(String(localized: "Undo")) {
                    viewModel.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.isDocumentOpen)

                Button(String(localized: "Redo")) {
                    viewModel.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.isDocumentOpen)
            }
        }
    }
}
