//
//  HexByteCellView.swift
//  HexMac
//

import SwiftUI

struct HexByteCellView: View {
    let offset: Int
    let hexText: String
    let isSelected: Bool
    let isEditing: Bool
    let highlightColor: HighlightColor?
    @Binding var editingText: String
    var focusedEditOffset: FocusState<Int?>.Binding
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $editingText)
                    .font(.body.monospaced())
                    .multilineTextAlignment(.center)
                    .frame(width: HexGridLayout.cellWidth)
                    .textFieldStyle(.plain)
                    .focused(focusedEditOffset, equals: offset)
                    .onSubmit(onCommit)
                    .onExitCommand(perform: onCancel)
            } else {
                Text(hexText)
                    .font(.body.monospaced())
                    .frame(width: HexGridLayout.cellWidth)
            }
        }
        .padding(.vertical, 1)
        .background(backgroundColor)
        .cornerRadius(2)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if let highlightColor {
            return highlightColor.color.opacity(0.3)
        }
        return .clear
    }
}
