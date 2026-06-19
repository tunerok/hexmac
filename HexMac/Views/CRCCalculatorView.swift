//
//  CRCCalculatorView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct CRCCalculatorView: View {
    let inputBytes: [UInt8]
    let onClose: () -> Void

    @State private var configuration = CRCConfiguration.defaultConfiguration
    @State private var selectedPreset: CRCPreset = .crc32IsoHdlc
    @State private var polynomialHex: String
    @State private var initialValueHex: String
    @State private var xorOutHex: String
    @State private var reverseByteOrder = false
    @State private var calculatedResult: String?

    init(inputBytes: [UInt8], onClose: @escaping () -> Void) {
        self.inputBytes = inputBytes
        self.onClose = onClose
        let defaultConfiguration = CRCConfiguration.defaultConfiguration
        _polynomialHex = State(initialValue: defaultConfiguration.polynomialHexString)
        _initialValueHex = State(initialValue: defaultConfiguration.initialValueHexString)
        _xorOutHex = State(initialValue: defaultConfiguration.xorOutHexString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "CRC Calculator"))
                .font(.title2)

            Text(
                String(
                    localized: "\(inputBytes.count) bytes selected",
                    comment: "CRC input byte count"
                )
            )
            .foregroundStyle(.secondary)

            Form {
                Toggle(
                    String(localized: "Reverse byte order"),
                    isOn: $reverseByteOrder
                )
                .onChange(of: reverseByteOrder) { _, _ in
                    calculatedResult = nil
                }

                Picker(String(localized: "Preset"), selection: $selectedPreset) {
                    ForEach(CRCPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .onChange(of: selectedPreset) { _, preset in
                    applyPreset(preset)
                }

                Picker(String(localized: "Algorithm"), selection: $configuration.algorithm) {
                    ForEach(CRCAlgorithm.allCases) { algorithm in
                        Text(algorithm.label).tag(algorithm)
                    }
                }
                .onChange(of: configuration.algorithm) { _, _ in
                    syncHexFieldsFromConfiguration()
                }

                TextField(String(localized: "Polynomial (hex)"), text: $polynomialHex)
                    .font(.body.monospaced())

                TextField(String(localized: "Initial value (hex)"), text: $initialValueHex)
                    .font(.body.monospaced())

                Toggle(String(localized: "RefIn"), isOn: $configuration.refin)
                Toggle(String(localized: "RefOut"), isOn: $configuration.refout)

                TextField(String(localized: "XorOut (hex)"), text: $xorOutHex)
                    .font(.body.monospaced())
            }
            .formStyle(.grouped)

            if let calculatedResult {
                HStack {
                    Text(calculatedResult)
                        .font(.title3.monospaced())
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
        .frame(width: 420)
    }

    private func applyPreset(_ preset: CRCPreset) {
        configuration = preset.configuration
        syncHexFieldsFromConfiguration()
        calculatedResult = nil
    }

    private func syncHexFieldsFromConfiguration() {
        polynomialHex = configuration.polynomialHexString
        initialValueHex = configuration.initialValueHexString
        xorOutHex = configuration.xorOutHexString
    }

    private func calculate() {
        var updatedConfiguration = configuration
        updatedConfiguration.setPolynomial(fromHex: polynomialHex)
        updatedConfiguration.setInitialValue(fromHex: initialValueHex)
        updatedConfiguration.setXorOut(fromHex: xorOutHex)
        configuration = updatedConfiguration

        let data = reverseByteOrder ? Array(inputBytes.reversed()) : inputBytes
        let value = CRCService.calculate(data: data, configuration: configuration)
        calculatedResult = CRCService.formattedResult(value, configuration: configuration)
    }
}

#Preview {
    CRCCalculatorView(inputBytes: [0x31, 0x32, 0x33, 0x34], onClose: {})
}
