//
//  InspectorCompareSection.swift
//  ediHex
//

import SwiftUI

struct CompareInspectorState {
    let leftName: String
    let rightName: String
    let isLoading: Bool
    let progress: Double?
    let diffCount: Int
    let currentDiffOffset: Int?
    let canNavigatePrevious: Bool
    let canNavigateNext: Bool
    let onNavigatePrevious: () -> Void
    let onNavigateNext: () -> Void
}

struct InspectorCompareSection: View {
    let state: CompareInspectorState

    var body: some View {
        Section(String(localized: "Comparison")) {
            LabeledContent(String(localized: "Left")) {
                Text(state.leftName)
                    .font(.callout)
                    .lineLimit(2)
            }

            LabeledContent(String(localized: "Right")) {
                Text(state.rightName)
                    .font(.callout)
                    .lineLimit(2)
            }

            if state.isLoading {
                if let progress = state.progress {
                    ProgressView(value: progress) {
                        Text(String(localized: "Scanning differences…"))
                            .font(.callout)
                    } currentValueLabel: {
                        Text("\(Int(progress * 100))%")
                            .font(.callout.monospacedDigit())
                    }
                } else {
                    ProgressView(String(localized: "Scanning differences…"))
                }
            } else if state.diffCount == 0 {
                Text(String(localized: "Files are identical."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent(String(localized: "Differing chunks")) {
                    Text("\(state.diffCount)")
                        .font(.callout.monospaced())
                }

                if let offset = state.currentDiffOffset {
                    LabeledContent(String(localized: "Offset")) {
                        Text("0x\(HexFormatter.offsetString(for: offset))")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                }

                HStack {
                    Button(String(localized: "Previous"), action: state.onNavigatePrevious)
                        .disabled(!state.canNavigatePrevious)

                    Button(String(localized: "Next"), action: state.onNavigateNext)
                        .disabled(!state.canNavigateNext)

                    Spacer()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    Form {
        InspectorCompareSection(
            state: CompareInspectorState(
                leftName: "firmware.bin",
                rightName: "firmware_patched.bin",
                isLoading: false,
                progress: nil,
                diffCount: 12,
                currentDiffOffset: 0x1A40,
                canNavigatePrevious: true,
                canNavigateNext: true,
                onNavigatePrevious: {},
                onNavigateNext: {}
            )
        )
    }
    .formStyle(.grouped)
}
#endif
