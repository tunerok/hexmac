//
//  TerminalPanelView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct TerminalPanelView: View {
    var pane: DocumentPaneViewModel?

    var body: some View {
        if let pane {
            TerminalPanelBoundView(pane: pane)
        } else {
            TerminalPanelEmptyView()
        }
    }
}

private struct TerminalPanelBoundView: View {
    @Bindable var pane: DocumentPaneViewModel
    @State private var commandInput = ""

    private var isTerminalEnabled: Bool {
        !pane.isComparisonPane
    }

    var body: some View {
        TerminalPanelContent(
            history: pane.terminalHistory,
            commandInput: $commandInput,
            isEnabled: isTerminalEnabled,
            onSubmit: {
                guard isTerminalEnabled else { return }
                let command = commandInput
                commandInput = ""
                guard !command.isEmpty else { return }
                pane.executeTerminalCommand(command)
            }
        )
        .id("\(pane.id)-\(pane.isComparisonPane)")
        .onChange(of: pane.isComparisonPane) { _, isComparison in
            if isComparison {
                commandInput = ""
            }
        }
    }
}

private struct TerminalPanelEmptyView: View {
    @State private var commandInput = ""

    var body: some View {
        TerminalPanelContent(
            history: [],
            commandInput: $commandInput,
            isEnabled: false,
            onSubmit: {}
        )
    }
}

private struct TerminalCommandHistoryNavigator {
    private(set) var browseIndex: Int?
    private var savedDraft = ""

    mutating func reset() {
        browseIndex = nil
        savedDraft = ""
    }

    mutating func navigate(
        up: Bool,
        commands: [String],
        currentInput: String
    ) -> String? {
        guard !commands.isEmpty else { return nil }

        if browseIndex == nil {
            savedDraft = currentInput
            browseIndex = commands.count - 1
            return commands[browseIndex!]
        }

        if up {
            guard let index = browseIndex, index > 0 else { return nil }
            browseIndex = index - 1
            return commands[browseIndex!]
        }

        guard let index = browseIndex else { return nil }
        if index < commands.count - 1 {
            browseIndex = index + 1
            return commands[browseIndex!]
        }

        browseIndex = nil
        return savedDraft
    }
}

private struct TerminalPanelContent: View {
    let history: [TerminalLine]
    @Binding var commandInput: String
    let isEnabled: Bool
    let onSubmit: () -> Void

    @State private var historyNavigator = TerminalCommandHistoryNavigator()

    private var commandHistory: [String] {
        history.compactMap { line in
            line.kind == .input ? line.text : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "Terminal"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(history) { line in
                            terminalLineView(line)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                .scrollIndicators(.visible)
                .onChange(of: history.count) { _, _ in
                    if let last = history.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("›")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)

                TerminalCommandTextField(
                    text: $commandInput,
                    isEnabled: isEnabled,
                    placeholder: String(localized: "Enter command"),
                    onSubmit: submitCommand,
                    onHistoryUp: { navigateHistory(up: true) },
                    onHistoryDown: { navigateHistory(up: false) }
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary)
    }

    private func submitCommand() {
        guard isEnabled else { return }
        historyNavigator.reset()
        onSubmit()
    }

    private func navigateHistory(up: Bool) {
        guard let nextInput = historyNavigator.navigate(
            up: up,
            commands: commandHistory,
            currentInput: commandInput
        ) else {
            return
        }
        commandInput = nextInput
    }

    @ViewBuilder
    private func terminalLineView(_ line: TerminalLine) -> some View {
        switch line.kind {
        case .input:
            Text("› \(line.text)")
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
        case .output:
            Text(line.text)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .error:
            Text(line.text)
                .font(.caption.monospaced())
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}

private struct TerminalCommandTextField: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool
    var placeholder: String
    var onSubmit: () -> Void
    var onHistoryUp: () -> Void
    var onHistoryDown: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.isEnabled = isEnabled
        field.isEditable = isEnabled
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self

        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.isEnabled = isEnabled
        field.isEditable = isEnabled

        if !isEnabled, field.window?.firstResponder === field.currentEditor() || field.window?.firstResponder === field {
            field.window?.makeFirstResponder(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TerminalCommandTextField

        init(parent: TerminalCommandTextField) {
            self.parent = parent
        }

        @objc func submit(_ sender: NSTextField) {
            guard parent.isEnabled else { return }
            parent.onSubmit()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            guard parent.isEnabled else {
                field.stringValue = parent.text
                return
            }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard parent.isEnabled else { return false }

            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onHistoryUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onHistoryDown()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }
}

#Preview {
    TerminalPanelView(pane: DocumentPaneViewModel())
        .frame(width: 520, height: 92)
}
