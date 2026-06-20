//
//  EmptyStateView.swift
//  HexMac
//

import SwiftUI

struct EmptyStateView: View {
    let onOpen: () -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Open a file to view its hex contents")
                .font(.title3)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(String(localized: "New File…"), action: onNew)
                    .keyboardShortcut("n", modifiers: .command)
                    .controlSize(.large)

                Button(String(localized: "Open File…"), action: onOpen)
                    .keyboardShortcut("o", modifiers: .command)
                    .controlSize(.large)
            }

            Text("Or drag and drop a file here")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    EmptyStateView(onOpen: {}, onNew: {})
}
