//
//  FindPanelView.swift
//  HexMac
//

import SwiftUI

struct FindPanelView: View {
    @Bindable var pane: DocumentPaneViewModel
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var isHexMode = true
    @State private var isASCIIMode = false
    @State private var searchEntireFile = true
    @State private var searchDown = true
    @State private var searchUp = false
    @State private var statusMessage = ""
    @State private var hexValidationError: HexParseError?

    private var patternMode: FindPatternMode {
        isHexMode ? .hex : .ascii
    }

    private var searchDirection: FindDirection {
        searchUp ? .up : .down
    }

    private var isInputValid: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if isHexMode {
            return hexValidationError == nil
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Find"))
                .font(.title2)

            TextField(String(localized: "Search pattern"), text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(isHexMode ? .body.monospaced() : .body)
                .onChange(of: searchText) { _, _ in
                    validateInput()
                }
                .onChange(of: isHexMode) { _, _ in
                    validateInput()
                }

            if let hexValidationError, isHexMode {
                Text(hexValidationError.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Form {
                Toggle(String(localized: "Hex"), isOn: $isHexMode)
                    .onChange(of: isHexMode) { _, newValue in
                        if newValue {
                            isASCIIMode = false
                        } else if !isASCIIMode {
                            isHexMode = true
                        }
                    }

                Toggle(String(localized: "ASCII"), isOn: $isASCIIMode)
                    .onChange(of: isASCIIMode) { _, newValue in
                        if newValue {
                            isHexMode = false
                        } else if !isHexMode {
                            isASCIIMode = true
                        }
                    }

                Toggle(String(localized: "Search entire file"), isOn: $searchEntireFile)

                Toggle(String(localized: "Search down"), isOn: $searchDown)
                    .disabled(searchEntireFile)
                    .onChange(of: searchDown) { _, newValue in
                        if newValue {
                            searchUp = false
                        } else if !searchUp, !searchEntireFile {
                            searchDown = true
                        }
                    }

                Toggle(String(localized: "Search up"), isOn: $searchUp)
                    .disabled(searchEntireFile)
                    .onChange(of: searchUp) { _, newValue in
                        if newValue {
                            searchDown = false
                        } else if !searchDown, !searchEntireFile {
                            searchUp = true
                        }
                    }
            }
            .formStyle(.grouped)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundStyle(pane.findSession?.hasMatches == true ? .primary : .secondary)
            }

            HStack {
                Button(String(localized: "Previous")) {
                    performPreviousMatch()
                }
                .disabled(pane.findSession?.currentIndex ?? 0 <= 0)

                Button(String(localized: "Next")) {
                    performNextMatch()
                }
                .disabled(
                    (pane.findSession?.currentIndex ?? -1) + 1 >= (pane.findSession?.matches.count ?? 0)
                )

                Spacer()

                Button(String(localized: "Close"), action: onClose)
                    .keyboardShortcut(.cancelAction)

                Button(String(localized: "Find Next")) {
                    performFindNext()
                }
                .disabled(!isInputValid)

                Button(String(localized: "Find")) {
                    performFind()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isInputValid)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            validateInput()
            updateStatusFromSession()
        }
        .onChange(of: pane.findSession) { _, _ in
            updateStatusFromSession()
        }
    }

    private func validateInput() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHexMode else {
            hexValidationError = trimmed.isEmpty ? .empty : nil
            return
        }

        if trimmed.isEmpty {
            hexValidationError = .empty
            return
        }

        switch BytePatternSearch.parseHex(trimmed) {
        case .success:
            hexValidationError = nil
        case .failure(let error):
            hexValidationError = error
        }
    }

    private func performFind() {
        let result = pane.performFind(
            input: searchText,
            mode: patternMode,
            entireFile: searchEntireFile,
            direction: searchDirection
        )
        updateStatus(for: result)
    }

    private func performFindNext() {
        if pane.findSession == nil {
            performFind()
            return
        }

        let result = pane.findNext()
        updateStatus(for: result)
    }

    private func performPreviousMatch() {
        let result = pane.findPreviousMatch()
        updateStatus(for: result, keepStatusOnFailure: true)
    }

    private func performNextMatch() {
        let result = pane.findNextMatch()
        updateStatus(for: result, keepStatusOnFailure: true)
    }

    private func updateStatus(for result: FindResult, keepStatusOnFailure: Bool = false) {
        switch result {
        case .found:
            updateStatusFromSession()
        case .notFound:
            if keepStatusOnFailure {
                updateStatusFromSession()
            } else {
                statusMessage = String(localized: "Not found")
            }
        }
    }

    private func updateStatusFromSession() {
        if let status = pane.findSession?.statusText {
            statusMessage = status
        } else if pane.findSession != nil {
            statusMessage = String(localized: "Not found")
        }
    }
}

#if DEBUG
#Preview {
    FindPanelView(pane: DocumentPaneViewModel()) {}
}
#endif
