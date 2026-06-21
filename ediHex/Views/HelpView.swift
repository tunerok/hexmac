//
//  HelpView.swift
//  ediHex
//

import SwiftUI

struct HelpView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "ediHex Help"))
                    .font(.title2)
                Spacer()
                Button(String(localized: "Done")) {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introSection
                    editorSection
                    workspaceSection
                    toolsSection
                    terminalSection
                    shortcutsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Divider()

            VStack(spacing: 2) {
                Text(
                    String(
                        localized: "Version \(AppInfo.version)",
                        comment: "Help footer version label"
                    )
                )
                Text(
                    String(
                        localized: "© \(AppInfo.copyrightYear) \(AppInfo.author)",
                        comment: "Help footer copyright line"
                    )
                )
                Link(destination: AppInfo.repositoryURL) {
                    Text(AppInfo.repositoryURL.absoluteString)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .frame(width: 560, height: 620)
    }

    private var introSection: some View {
        HelpSection(title: String(localized: "Getting Started")) {
            HelpBullet(String(localized: "Open a file with File → Open… (⌘O) or drag a file into the window."))
            HelpBullet(String(localized: "Edit bytes directly in the hex grid. Changes are tracked with undo/redo."))
            HelpBullet(String(localized: "Use the Inspector panel for offset details, highlights, and integer interpretations."))
        }
    }

    private var editorSection: some View {
        HelpSection(title: String(localized: "Hex Editor")) {
            HelpBullet(String(localized: "View → Bytes per Row — choose 8, 16, 24, or 32 bytes per line."))
            HelpBullet(String(localized: "View → Text Encoding — ASCII, UTF-8, UTF-16 LE/BE, Latin-1, Windows-1252, Mac Roman."))
            HelpBullet(String(localized: "Edit → Copy copies the selection as hex."))
            HelpBullet(String(localized: "Edit → Show as Binary… displays the selected bytes in binary."))
            HelpBullet(String(localized: "Edit → Clear… fills the selection with a chosen byte value."))
        }
    }

    private var workspaceSection: some View {
        HelpSection(title: String(localized: "Workspace")) {
            HelpBullet(String(localized: "View → Split Right (⌘\\) or Split Down (⇧⌘\\) to open a second editor group."))
            HelpBullet(String(localized: "Use tabs to switch between open files. ⇧⌘] and ⇧⌘[ move to the next or previous tab."))
            HelpBullet(String(localized: "Tools → Compare… opens a side-by-side diff with a minimap."))
            HelpBullet(String(localized: "Right-click a tab and choose Compare with… to diff against another open file."))
            HelpBullet(String(localized: "In compare mode, use F3 and ⇧F3 to jump to the next or previous difference. The Inspector shows diff navigation controls."))
        }
    }

    private var toolsSection: some View {
        HelpSection(title: String(localized: "Analysis Tools")) {
            HelpBullet(String(localized: "Edit → Find… (⌘F) — search by hex pattern or ASCII text."))
            HelpBullet(String(localized: "Inspector → Find Results — navigate previous matches after closing Find."))
            HelpBullet(String(localized: "Tools → Hash — MD5, SHA family, SHA3 (entire file or selection)."))
            HelpBullet(String(localized: "Tools → Calculate CRC… — CRC-8/16/32 with industry presets or custom parameters."))
            HelpBullet(String(localized: "Tools → Byte Histogram — byte frequency for the file or selection."))
        }
    }

    private var terminalSection: some View {
        HelpSection(title: String(localized: "Built-in Terminal")) {
            Text(String(localized: "Each document pane has a terminal for scripted analysis. Type help for the full command reference."))
                .fixedSize(horizontal: false, vertical: true)
            HelpBullet(String(localized: "goto, hex, bin, ascii — navigation and dumps"))
            HelpBullet(String(localized: "sum, xor, avg, min, max, len, count — byte math over ranges"))
            HelpBullet(String(localized: "find, cmp, crc, hash — search, compare, checksums"))
            HelpBullet(String(localized: "help ranges | help filters | help crc — detailed syntax"))
        }
    }

    private var shortcutsSection: some View {
        HelpSection(title: String(localized: "Keyboard Shortcuts")) {
            HelpShortcut("⌘O", String(localized: "Open file"))
            HelpShortcut("⌘S / ⇧⌘S", String(localized: "Save / Save As"))
            HelpShortcut("⌘Z / ⇧⌘Z", String(localized: "Undo / Redo"))
            HelpShortcut("⌘C", String(localized: "Copy selection (hex)"))
            HelpShortcut("⌘F", String(localized: "Find"))
            HelpShortcut("⌘\\ / ⇧⌘\\", String(localized: "Split right / down"))
            HelpShortcut("⇧⌘] / ⇧⌘[", String(localized: "Next / previous tab"))
            HelpShortcut("⌘W / ⇧⌘W", String(localized: "Close tab / editor group"))
            HelpShortcut("⌘?", String(localized: "Open this help"))
        }
    }
}

private struct HelpSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct HelpBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HelpShortcut: View {
    let keys: String
    let action: String

    init(_ keys: String, _ action: String) {
        self.keys = keys
        self.action = action
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(keys)
                .font(.body.monospaced())
                .frame(width: 100, alignment: .leading)
            Text(action)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HelpView(onClose: {})
}
