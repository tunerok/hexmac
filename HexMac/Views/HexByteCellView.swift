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
    let editingHexText: String
    let highlightColor: HighlightColor?

    var body: some View {
        Text(displayText)
            .font(.body.monospaced())
            .foregroundStyle(isEditing ? Color.accentColor : Color.primary)
            .frame(width: HexGridLayout.cellWidth)
            .padding(.vertical, 1)
            .background(backgroundColor)
            .cornerRadius(2)
            .overlay {
                if isEditing {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                }
            }
    }

    private var displayText: String {
        guard isEditing, !editingHexText.isEmpty else {
            return hexText
        }
        return "\(editingHexText)_"
    }

    private var backgroundColor: Color {
        if isEditing {
            return Color.accentColor.opacity(0.2)
        }
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if let highlightColor {
            return highlightColor.color.opacity(0.3)
        }
        return .clear
    }
}
