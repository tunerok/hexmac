//
//  HexMacApp.swift
//  HexMac
//

import AppKit
import SwiftUI

@main
struct HexMacApp: App {
    @State private var workspace = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
        }
        Settings {
            SettingsView()
        }
        .commands {
            appMenuCommands
            fileMenuCommands
            editMenuCommands
            viewMenuCommands
            toolsMenuCommands
        }
    }

    @CommandsBuilder
    private var appMenuCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "About HexMac")) {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [NSApplication.AboutPanelOptionKey.credits: NSAttributedString()]
                )
            }
        }
    }

    @CommandsBuilder
    private var fileMenuCommands: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .newItem) {
            Button(String(localized: "Open…")) {
                workspace.openFilePanel()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button(String(localized: "Close Tab")) {
                workspace.closeActivePane()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!workspace.hasOpenPanes)

            Button(String(localized: "Close Editor Group")) {
                workspace.closeActiveGroup()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
            .disabled(!workspace.hasOpenPanes)
        }

        CommandGroup(replacing: .saveItem) {
            Button(String(localized: "Save")) {
                workspace.save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!workspace.canSave)

            Button(String(localized: "Save As…")) {
                workspace.saveAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!workspace.isDocumentOpen)
        }
    }

    @CommandsBuilder
    private var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(String(localized: "Undo")) {
                workspace.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!workspace.isDocumentOpen)

            Button(String(localized: "Redo")) {
                workspace.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!workspace.isDocumentOpen)
        }

        CommandGroup(replacing: .pasteboard) {
            Button(String(localized: "Copy")) {
                workspace.copySelectionHex()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!workspace.hasSelection)

            Button(String(localized: "Show as Binary…")) {
                workspace.openBinarySheet()
            }
            .disabled(!workspace.hasSelection)

            Button(String(localized: "Clear…")) {
                workspace.requestFillSelection()
            }
            .disabled(!workspace.hasSelection)
        }
    }

    @CommandsBuilder
    private var viewMenuCommands: some Commands {
        CommandGroup(after: .toolbar) {
            Button(String(localized: "Split Right")) {
                workspace.splitActive(axis: .horizontal)
            }
            .keyboardShortcut("\\", modifiers: .command)
            .disabled(!workspace.isDocumentOpen)

            Button(String(localized: "Split Down")) {
                workspace.splitActive(axis: .vertical)
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])
            .disabled(!workspace.isDocumentOpen)

            Divider()

            Button(String(localized: "Next Tab")) {
                workspace.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
            .disabled(!workspace.hasOpenPanes)

            Button(String(localized: "Previous Tab")) {
                workspace.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            .disabled(!workspace.hasOpenPanes)

            Divider()

            Menu(String(localized: "Bytes per Row")) {
                ForEach(BytesPerRowSetting.allCases) { setting in
                    Button {
                        workspace.setBytesPerRow(setting)
                    } label: {
                        if workspace.bytesPerRow == setting {
                            Text("✓ \(setting.label)")
                        } else {
                            Text(setting.label)
                        }
                    }
                    .disabled(!workspace.isDocumentOpen)
                }
            }

            Menu(String(localized: "Text Encoding")) {
                ForEach(TextEncodingMode.allCases) { mode in
                    Button {
                        workspace.setTextEncoding(mode)
                    } label: {
                        if workspace.textEncoding == mode {
                            Text("✓ \(mode.label)")
                        } else {
                            Text(mode.label)
                        }
                    }
                }
            }
        }
    }

    @CommandsBuilder
    private var toolsMenuCommands: some Commands {
        CommandMenu(String(localized: "Tools")) {
            Button(String(localized: "Byte Histogram (Entire File)…")) {
                workspace.openHistogramForAll()
            }
            .disabled(!workspace.isDocumentOpen || workspace.fileSize == 0)

            Button(String(localized: "Byte Histogram (Selection)…")) {
                workspace.openHistogramForSelection()
            }
            .disabled(!workspace.hasSelection)

            Divider()

            Button(String(localized: "Hash (Entire File)…")) {
                workspace.openHashForAll()
            }
            .disabled(!workspace.isDocumentOpen || workspace.fileSize == 0)

            Button(String(localized: "Hash (Selection)…")) {
                workspace.openHashForSelection()
            }
            .disabled(!workspace.hasSelection)

            Divider()

            Button(String(localized: "Calculate CRC…")) {
                workspace.openCRCSheet()
            }
            .disabled(!workspace.hasSelection)
        }
    }
}
