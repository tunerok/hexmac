//
//  InspectorPanelView.swift
//  HexMac
//

import SwiftUI

struct InspectorPanelView: View {
    let selection: HexSelection?
    let bytes: [UInt8]
    let selectedOffset: Int?
    let highlights: [HexHighlight]
    let onAddHighlight: (HighlightColor) -> Void
    let onRemoveHighlight: (UUID) -> Void
    let onNavigateToHighlight: (HexHighlight) -> Void

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

                        Section(String(localized: "Highlights")) {
                            HighlightColorPicker(onSelect: onAddHighlight)

                            if highlights.isEmpty {
                                Text(String(localized: "No highlights"))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(highlights) { highlight in
                                    HighlightRow(
                                        highlight: highlight,
                                        onNavigate: { onNavigateToHighlight(highlight) },
                                        onRemove: { onRemoveHighlight(highlight.id) }
                                    )
                                }
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

private struct HighlightColorPicker: View {
    let onSelect: (HighlightColor) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28))], spacing: 8) {
            ForEach(HighlightColor.allCases) { color in
                Button {
                    onSelect(color)
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.color.opacity(0.6))
                        .frame(width: 28, height: 20)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help(color.label)
            }
        }
    }
}

private struct HighlightRow: View {
    let highlight: HexHighlight
    let onNavigate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Button(action: onNavigate) {
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(highlight.color.color.opacity(0.6))
                        .frame(width: 12, height: 12)

                    Text("0x\(HexFormatter.offsetString(for: highlight.start)) – 0x\(HexFormatter.offsetString(for: highlight.end))")
                        .font(.body.monospaced())
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
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
        selectedOffset: 72,
        highlights: [HexHighlight(start: 64, end: 80, color: .yellow)],
        onAddHighlight: { _ in },
        onRemoveHighlight: { _ in },
        onNavigateToHighlight: { _ in }
    )
}
