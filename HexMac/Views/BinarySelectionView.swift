//
//  BinarySelectionView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct BinarySelectionView: View {
    let selectionStart: Int
    let selectionEnd: Int
    let byteCount: Int
    let bytesProvider: (Range<Int>) -> [UInt8]
    let onClose: () -> Void

    @State private var integerInterpretations: [BinaryIntegerInterpretation] = []
    @State private var copyAlertMessage: String?
    @State private var copyPlainBinary = true
    @State private var outputAreaWidth: CGFloat = 0

    private static let monospacedCharacterWidth: CGFloat = {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return ceil(("0" as NSString).size(withAttributes: [.font: font]).width)
    }()

    private var displayedByteCount: Int {
        BinarySelectionFormatter.displayedByteCount(for: byteCount)
    }

    private var lineCount: Int {
        BinarySelectionFormatter.lineCount(for: displayedByteCount)
    }

    private var showsTruncationNotice: Bool {
        byteCount > BinarySelectionFormatter.maxDisplayBytes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Binary Representation"))
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    String(
                        localized: "Selection: 0x\(HexFormatter.offsetString(for: selectionStart)) – 0x\(HexFormatter.offsetString(for: selectionEnd))"
                    )
                )
                Text(
                    String(
                        localized: "\(byteCount) bytes",
                        comment: "Binary view byte count"
                    )
                )
            }
            .foregroundStyle(.secondary)

            if showsTruncationNotice {
                Text(
                    String(
                        localized: "Showing the first \(BinarySelectionFormatter.maxDisplayBytes) bytes of \(byteCount).",
                        comment: "Binary view truncation notice"
                    )
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }

            if !integerInterpretations.isEmpty {
                Form {
                    Section(String(localized: "As integer")) {
                        ForEach(integerInterpretations) { interpretation in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(interpretation.endianness)
                                    .font(.headline)

                                Text(interpretation.decimalValue)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)

                                Group {
                                    if copyPlainBinary {
                                        Text(
                                            interpretationBinaryText(
                                                interpretation,
                                                forWidth: outputAreaWidth
                                            )
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ScrollView(.horizontal) {
                                            Text(interpretation.formattedBinaryText)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                }
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .formStyle(.grouped)
            }

            GeometryReader { geometry in
                Group {
                    if copyPlainBinary {
                        ScrollView(.vertical) {
                            Text(displayText(forWidth: geometry.size.width, byteCount: displayedByteCount))
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(0..<lineCount, id: \.self) { lineIndex in
                                    Text(formattedLine(at: lineIndex))
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .onAppear {
                    outputAreaWidth = geometry.size.width
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    outputAreaWidth = newWidth
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button(String(localized: "Copy")) {
                    copyToPasteboard()
                }

                Toggle(
                    String(
                        localized: "Digits only",
                        comment: "Binary view copy option; copies 0/1 without offsets or separators"
                    ),
                    isOn: $copyPlainBinary
                )
                .toggleStyle(.checkbox)

                Spacer()

                Button(String(localized: "Close")) {
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 672, idealWidth: 864, minHeight: 420, idealHeight: 560)
        .onAppear {
            loadIntegerInterpretations()
        }
        .alert(
            String(localized: "Copy Failed"),
            isPresented: Binding(
                get: { copyAlertMessage != nil },
                set: { if !$0 { copyAlertMessage = nil } }
            )
        ) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(copyAlertMessage ?? "")
        }
    }

    private func binaryText(byteCount: Int) -> String {
        if copyPlainBinary {
            return BinarySelectionFormatter.plainBinaryText(
                selectionStart: selectionStart,
                byteCount: byteCount,
                bytesProvider: bytesProvider
            )
        }

        return BinarySelectionFormatter.fullText(
            selectionStart: selectionStart,
            byteCount: byteCount,
            bytesProvider: bytesProvider
        )
    }

    private func formattedLine(at lineIndex: Int) -> String {
        let relativeRange = BinarySelectionFormatter.relativeLineRange(
            for: lineIndex,
            totalByteCount: displayedByteCount
        )
        let absoluteRange = (selectionStart + relativeRange.lowerBound)..<(selectionStart + relativeRange.upperBound)
        let bytes = bytesProvider(absoluteRange)
        return BinarySelectionFormatter.formattedLine(
            bytes: bytes,
            lineStartOffset: absoluteRange.lowerBound
        )
    }

    private func displayText(forWidth width: CGFloat, byteCount: Int) -> String {
        let text = binaryText(byteCount: byteCount)
        guard copyPlainBinary else { return text }

        let charactersPerLine = charactersPerLine(forWidth: width)
        return BinarySelectionFormatter.wrappedPlainBinaryText(text, charactersPerLine: charactersPerLine)
    }

    private func interpretationBinaryText(
        _ interpretation: BinaryIntegerInterpretation,
        forWidth width: CGFloat
    ) -> String {
        if copyPlainBinary {
            let charactersPerLine = charactersPerLine(forWidth: width)
            return BinarySelectionFormatter.wrappedPlainBinaryText(
                interpretation.plainBinaryText,
                charactersPerLine: charactersPerLine
            )
        }

        return interpretation.formattedBinaryText
    }

    private func charactersPerLine(forWidth width: CGFloat) -> Int {
        guard width > 0, Self.monospacedCharacterWidth > 0 else { return 64 }
        return max(1, Int(width / Self.monospacedCharacterWidth))
    }

    private func loadIntegerInterpretations() {
        guard byteCount <= 8 else {
            integerInterpretations = []
            return
        }

        let bytes = bytesProvider(selectionStart..<(selectionStart + byteCount))
        integerInterpretations = BinarySelectionFormatter.integerInterpretations(for: bytes)
    }

    private func copyToPasteboard() {
        let copyByteCount = min(byteCount, BinarySelectionFormatter.maxCopyBytes)
        guard copyByteCount == byteCount else {
            copyAlertMessage = String(
                localized: "Selection is too large to copy. Maximum size is \(BinarySelectionFormatter.maxCopyBytes) bytes."
            )
            return
        }

        let text = binaryText(byteCount: copyByteCount)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    BinarySelectionView(
        selectionStart: 0,
        selectionEnd: 2,
        byteCount: 3,
        bytesProvider: { _ in [0x48, 0x65, 0x6C] },
        onClose: {}
    )
}
