//
//  SettingsView.swift
//  HexMac
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("textEncoding") private var storedEncoding = TextEncodingMode.ascii.rawValue

    private var textEncoding: Binding<TextEncodingMode> {
        Binding(
            get: { TextEncodingMode(rawValue: storedEncoding) ?? .ascii },
            set: { storedEncoding = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Picker(String(localized: "Text encoding"), selection: textEncoding) {
                ForEach(TextEncodingMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }
}

#Preview {
    SettingsView()
}
