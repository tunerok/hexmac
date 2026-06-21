//
//  InspectorPanelView.swift
//  ediHex
//

import SwiftUI

struct InspectorPanelView: View {
    let selection: HexSelection?
    let bytes: [UInt8]
    let selectedOffset: Int?
    let highlights: [HexHighlight]
    let findSession: FindSession?
    let compareState: CompareInspectorState?
    let canFindPrevious: Bool
    let canFindNext: Bool
    let onAddHighlight: (HighlightColor) -> Void
    let onRemoveHighlight: (UUID) -> Void
    let onNavigateToHighlight: (HexHighlight) -> Void
    let onFindPrevious: () -> Void
    let onFindNext: () -> Void
    let onClearFind: () -> Void

    private var integerInterpretations: [IntegerInterpretation] {
        SelectionIntegerParser.interpretations(for: bytes)
    }

    private var displayStartOffset: Int {
        selection?.start ?? 0
    }

    private var displayLength: Int {
        selection?.length ?? 0
    }

    private var displayBinaryBitWidth: Int {
        let byteCount = bytes.isEmpty ? 1 : min(bytes.count, 4)
        return byteCount * 8
    }

    private var displayBinary: String {
        HexFormatter.binaryString(for: bytes, bitWidth: displayBinaryBitWidth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ScrollView {
                Form {
                    if let compareState {
                        InspectorCompareSection(state: compareState)
                    } else {
                        Section(String(localized: "Selection")) {
                            InspectorRow(title: String(localized: "Offset (hex)")) {
                                Text("0x\(HexFormatter.offsetString(for: displayStartOffset))")
                            }

                            InspectorRow(title: String(localized: "Offset (dec)")) {
                                Text("\(displayStartOffset)")
                            }

                            InspectorRow(title: String(localized: "Length")) {
                                Text("\(displayLength) \(String(localized: "bytes"))")
                            }
                        }

                        if let findSession {
                            InspectorFindResultsSection(
                                session: findSession,
                                canFindPrevious: canFindPrevious,
                                canFindNext: canFindNext,
                                onFindPrevious: onFindPrevious,
                                onFindNext: onFindNext,
                                onClearFind: onClearFind
                            )
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

                        Section(String(localized: "Values")) {
                            InspectorRow(title: String(localized: "Binary")) {
                                Text(displayBinary)
                            }

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
                }
                .formStyle(.grouped)
                .font(.callout)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 360, idealWidth: 520, maxWidth: 1200)
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
                        .font(.callout.monospaced())
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
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
    }
}

#Preview("With selection") {
    InspectorPanelView(
        selection: .single(at: 72),
        bytes: [0x48],
        selectedOffset: 72,
        highlights: [HexHighlight(start: 64, end: 80, color: .yellow)],
        findSession: FindSession(
            queryText: "48",
            pattern: [0x48],
            mode: .hex,
            entireFile: true,
            direction: .down,
            matches: [72],
            currentIndex: 0
        ),
        compareState: nil,
        canFindPrevious: false,
        canFindNext: false,
        onAddHighlight: { _ in },
        onRemoveHighlight: { _ in },
        onNavigateToHighlight: { _ in },
        onFindPrevious: {},
        onFindNext: {},
        onClearFind: {}
    )
}

#Preview("No selection") {
    InspectorPanelView(
        selection: nil,
        bytes: [],
        selectedOffset: nil,
        highlights: [],
        findSession: nil,
        compareState: nil,
        canFindPrevious: false,
        canFindNext: false,
        onAddHighlight: { _ in },
        onRemoveHighlight: { _ in },
        onNavigateToHighlight: { _ in },
        onFindPrevious: {},
        onFindNext: {},
        onClearFind: {}
    )
}
