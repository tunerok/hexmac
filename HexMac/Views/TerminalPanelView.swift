//
//  TerminalPanelView.swift
//  HexMac
//

import SwiftUI

struct TerminalPanelView: View {
    @Bindable var viewModel: HexEditorViewModel
    @State private var commandInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "Terminal"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.terminalHistory) { line in
                            terminalLineView(line)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .onChange(of: viewModel.terminalHistory.count) { _, _ in
                    if let last = viewModel.terminalHistory.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text("›")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)

                TextField(String(localized: "Enter command"), text: $commandInput)
                    .font(.body.monospaced())
                    .textFieldStyle(.plain)
                    .onSubmit(submitCommand)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minHeight: 80, idealHeight: 160)
        .background(.background.secondary)
    }

    @ViewBuilder
    private func terminalLineView(_ line: TerminalLine) -> some View {
        switch line.kind {
        case .input:
            Text("› \(line.text)")
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
        case .output:
            Text(line.text)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .error:
            Text(line.text)
                .font(.callout.monospaced())
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }

    private func submitCommand() {
        let command = commandInput
        commandInput = ""
        guard !command.isEmpty else { return }
        viewModel.executeTerminalCommand(command)
    }
}

#Preview {
    TerminalPanelView(viewModel: HexEditorViewModel())
        .frame(height: 180)
}
