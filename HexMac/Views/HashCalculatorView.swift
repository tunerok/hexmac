//
//  HashCalculatorView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct HashCalculatorView: View {
    let fileName: String
    let title: String
    let inputBytes: [UInt8]
    let onClose: () -> Void

    @State private var algorithm: HashAlgorithm = .sha256
    @State private var calculatedResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Hash Calculator"))
                .font(.title2)

            Text(fileName)
                .font(.title3)
                .textSelection(.enabled)

            Text(title)
                .font(.headline)

            Text(
                String(
                    localized: "\(inputBytes.count) bytes",
                    comment: "Hash input byte count"
                )
            )
            .foregroundStyle(.secondary)

            Form {
                Picker(String(localized: "Algorithm"), selection: $algorithm) {
                    ForEach(HashAlgorithm.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .onChange(of: algorithm) { _, _ in
                    calculatedResult = nil
                }
            }
            .formStyle(.grouped)

            if let calculatedResult {
                HStack {
                    Text(calculatedResult)
                        .font(.body.monospaced())
                        .textSelection(.enabled)

                    Spacer()

                    Button(String(localized: "Copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(calculatedResult, forType: .string)
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Spacer()

                Button(String(localized: "Close"), action: onClose)
                    .keyboardShortcut(.cancelAction)

                Button(String(localized: "Calculate"), action: calculate)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func calculate() {
        calculatedResult = HashAlgorithm.calculate(algorithm, data: inputBytes)
    }
}

#Preview {
    HashCalculatorView(
        fileName: "example.bin",
        title: "Entire file",
        inputBytes: [0x31, 0x32, 0x33, 0x34],
        onClose: {}
    )
}
