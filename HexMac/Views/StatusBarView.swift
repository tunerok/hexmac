//
//  StatusBarView.swift
//  HexMac
//

import SwiftUI

struct StatusBarView: View {
    let selectedOffset: Int?
    let fileSize: Int
    @Binding var textEncoding: TextEncodingMode
    @Binding var bytesPerRow: BytesPerRowSetting

    var body: some View {
        HStack(spacing: 16) {
            if let selectedOffset {
                Text("Offset: 0x\(HexFormatter.offsetString(for: selectedOffset))")
            } else {
                Text("Offset: —")
            }

            Text("Size: \(HexFormatter.formattedFileSize(fileSize))")

            Spacer()

            Picker(String(localized: "Bytes per row"), selection: $bytesPerRow) {
                ForEach(BytesPerRowSetting.allCases) { setting in
                    Text(setting.label).tag(setting)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Picker(String(localized: "Encoding"), selection: $textEncoding) {
                ForEach(TextEncodingMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)
        }
        .font(.callout.monospaced())
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
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
