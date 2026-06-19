//
//  StatusBarView.swift
//  HexMac
//

import SwiftUI

struct StatusBarView: View {
    private enum LayoutMode {
        case full
        case compact
        case minimal
    }

    let selectedOffset: Int?
    let fileSize: Int
    @Binding var textEncoding: TextEncodingMode
    @Binding var bytesPerRow: BytesPerRowSetting

    var body: some View {
        GeometryReader { geometry in
            let layoutMode = layoutMode(for: geometry.size.width)

            HStack(spacing: layoutMode == .minimal ? 8 : 16) {
                if let selectedOffset {
                    Text("Offset: 0x\(HexFormatter.offsetString(for: selectedOffset))")
                        .lineLimit(1)
                } else {
                    Text("Offset: —")
                        .lineLimit(1)
                }

                Text("Size: \(HexFormatter.formattedFileSize(fileSize))")
                    .lineLimit(1)

                Spacer(minLength: 0)

                switch layoutMode {
                case .full:
                    bytesPerRowPicker
                    encodingPicker
                case .compact:
                    encodingPicker
                    viewOptionsMenu(showBytesPerRow: true, showEncoding: false)
                case .minimal:
                    viewOptionsMenu(showBytesPerRow: true, showEncoding: true)
                }
            }
            .font(.callout.monospaced())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .frame(height: 28)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }

    private var bytesPerRowPicker: some View {
        Picker(String(localized: "Bytes per row"), selection: $bytesPerRow) {
            ForEach(BytesPerRowSetting.allCases) { setting in
                Text(setting.label).tag(setting)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }

    private var encodingPicker: some View {
        Picker(String(localized: "Encoding"), selection: $textEncoding) {
            ForEach(TextEncodingMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 160)
    }

    private func viewOptionsMenu(showBytesPerRow: Bool, showEncoding: Bool) -> some View {
        Menu {
            if showBytesPerRow {
                Section(String(localized: "Bytes per row")) {
                    ForEach(BytesPerRowSetting.allCases) { setting in
                        Button {
                            bytesPerRow = setting
                        } label: {
                            if bytesPerRow == setting {
                                Text("✓ \(setting.label)")
                            } else {
                                Text(setting.label)
                            }
                        }
                    }
                }
            }

            if showEncoding {
                Section(String(localized: "Encoding")) {
                    ForEach(TextEncodingMode.allCases) { mode in
                        Button {
                            textEncoding = mode
                        } label: {
                            if textEncoding == mode {
                                Text("✓ \(mode.label)")
                            } else {
                                Text(mode.label)
                            }
                        }
                    }
                }
            }
        } label: {
            Label(String(localized: "View Options"), systemImage: "slider.horizontal.3")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func layoutMode(for width: CGFloat) -> LayoutMode {
        if width < 600 {
            return .minimal
        }
        if width < 800 {
            return .compact
        }
        return .full
    }
}

#Preview {
    StatusBarView(
        selectedOffset: 0,
        fileSize: 1024,
        textEncoding: .constant(.ascii),
        bytesPerRow: .constant(.sixteen)
    )
}
