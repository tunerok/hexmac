//
//  InspectorPanelView.swift
//  HexMac
//

import SwiftUI

struct InspectorPanelView: View {
    let selection: HexSelection?
    let bytes: [UInt8]
    let selectedOffset: Int?

    private var integerInterpretations: [IntegerInterpretation] {
        SelectionIntegerParser.interpretations(for: bytes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if let selection, !bytes.isEmpty {
                ScrollView {
                    Form {
                        Section(String(localized: "Selection")) {
                            InspectorRow(title: String(localized: "Offset (hex)")) {
                                Text("0x\(HexFormatter.offsetString(for: selection.start))")
                            }

                            InspectorRow(title: String(localized: "Offset (dec)")) {
                                Text("\(selection.start)")
                            }

                            InspectorRow(title: String(localized: "Hex")) {
                                Text(HexFormatter.hexString(for: bytes))
                            }

                            if bytes.count == 1, let byte = bytes.first {
                                InspectorRow(title: String(localized: "Binary")) {
                                    Text(HexFormatter.binaryString(for: byte))
                                }

                                InspectorRow(title: String(localized: "Character")) {
                                    Text(String(HexFormatter.asciiCharacter(for: byte)))
                                }
                            }

                            InspectorRow(title: String(localized: "Length")) {
                                Text("\(selection.length) \(String(localized: "bytes"))")
                            }
                        }

                        Section(String(localized: "Integer values")) {
                            ForEach(integerInterpretations) { interpretation in
                                if interpretation.littleEndian == interpretation.bigEndian {
                                    InspectorRow(title: interpretation.typeName) {
                                        Text(interpretation.littleEndian)
                                    }
                                } else {
                                    InspectorRow(title: "\(interpretation.typeName) LE") {
                                        Text(interpretation.littleEndian)
                                    }
                                    InspectorRow(title: "\(interpretation.typeName) BE") {
                                        Text(interpretation.bigEndian)
                                    }
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                }
            } else {
                ContentUnavailableView(
                    String(localized: "No Selection"),
                    systemImage: "cursorarrow",
                    description: Text("Select a byte to inspect")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 180, idealWidth: 260, maxWidth: 600)
        .background(.background.secondary)
    }
}

private struct InspectorRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        LabeledContent(title) {
            content
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}

#Preview {
    InspectorPanelView(
        selection: .single(at: 72),
        bytes: [0x48],
        selectedOffset: 72
    )
}
