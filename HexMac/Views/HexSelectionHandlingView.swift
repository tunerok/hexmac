//
//  HexSelectionHandlingView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct HexSelectionHandlingView: NSViewRepresentable {
    let rowCount: Int
    let fileSize: Int
    let bytesPerRow: Int
    let editingOffset: Int?
    let selection: HexSelection?
    let onFinishEditing: () -> Void
    let onBeginSelection: (Int, Bool) -> Void
    let onUpdateSelection: (Int) -> Void
    let onEndSelection: (Int) -> Void
    let onBeginEdit: (Int) -> Void
    let onAddHighlight: (HighlightColor) -> Void
    let onRemoveHighlight: (Int) -> Void
    let onCopySelection: () -> Void
    let onClearSelection: () -> Void
    let onCalculateCRC: () -> Void
    let highlightColor: (Int) -> HighlightColor?

    func makeNSView(context: Context) -> HexSelectionMouseView {
        let view = HexSelectionMouseView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HexSelectionMouseView, context: Context) {
        context.coordinator.parent = self
        nsView.coordinator = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: HexSelectionHandlingView
        private var isDragging = false

        init(parent: HexSelectionHandlingView) {
            self.parent = parent
        }

        func offset(at point: CGPoint) -> Int? {
            parent.byteOffset(at: point)
        }

        func handleMouseDown(at point: CGPoint, extending: Bool, clickCount: Int) {
            guard let offset = offset(at: point) else { return }

            if clickCount >= 2 {
                if parent.editingOffset != nil, parent.editingOffset != offset {
                    parent.onFinishEditing()
                }
                parent.onBeginEdit(offset)
                isDragging = false
                return
            }

            if parent.editingOffset != nil {
                parent.onFinishEditing()
            }

            isDragging = true
            parent.onBeginSelection(offset, extending)
        }

        func handleMouseDragged(at point: CGPoint) {
            guard isDragging, let offset = offset(at: point) else { return }
            parent.onUpdateSelection(offset)
        }

        func handleMouseUp(at point: CGPoint) {
            defer { isDragging = false }

            guard isDragging, let offset = offset(at: point) else { return }
            parent.onEndSelection(offset)
        }

        func handleRightMouseDown(at point: CGPoint, in view: NSView, event: NSEvent) {
            guard let offset = offset(at: point) else { return }

            if parent.selection == nil {
                parent.onBeginSelection(offset, false)
            }

            let menu = NSMenu()

            if parent.selection != nil {
                let copyItem = NSMenuItem(
                    title: String(localized: "Copy"),
                    action: #selector(copySelection(_:)),
                    keyEquivalent: "c"
                )
                copyItem.keyEquivalentModifierMask = .command
                copyItem.target = self
                menu.addItem(copyItem)

                let clearItem = NSMenuItem(
                    title: String(localized: "Clear…"),
                    action: #selector(clearSelection(_:)),
                    keyEquivalent: ""
                )
                clearItem.target = self
                menu.addItem(clearItem)

                let crcItem = NSMenuItem(
                    title: String(localized: "Calculate CRC…"),
                    action: #selector(calculateCRC(_:)),
                    keyEquivalent: ""
                )
                crcItem.target = self
                menu.addItem(crcItem)

                menu.addItem(.separator())
            }

            let highlightMenu = NSMenuItem(
                title: String(localized: "Highlight"),
                action: nil,
                keyEquivalent: ""
            )
            let submenu = NSMenu()

            for color in HighlightColor.allCases {
                let item = NSMenuItem(
                    title: color.label,
                    action: #selector(highlightColorSelected(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = color
                item.target = self
                submenu.addItem(item)
            }

            highlightMenu.submenu = submenu
            menu.addItem(highlightMenu)

            if parent.highlightColor(offset) != nil {
                let removeItem = NSMenuItem(
                    title: String(localized: "Remove Highlight"),
                    action: #selector(removeHighlightSelected(_:)),
                    keyEquivalent: ""
                )
                removeItem.representedObject = offset
                removeItem.target = self
                menu.addItem(removeItem)
            }

            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }

        @objc func highlightColorSelected(_ sender: NSMenuItem) {
            guard let color = sender.representedObject as? HighlightColor else { return }
            parent.onAddHighlight(color)
        }

        @objc func removeHighlightSelected(_ sender: NSMenuItem) {
            guard let offset = sender.representedObject as? Int else { return }
            parent.onRemoveHighlight(offset)
        }

        @objc func copySelection(_ sender: NSMenuItem) {
            parent.onCopySelection()
        }

        @objc func clearSelection(_ sender: NSMenuItem) {
            parent.onClearSelection()
        }

        @objc func calculateCRC(_ sender: NSMenuItem) {
            parent.onCalculateCRC()
        }
    }

    private func byteOffset(at point: CGPoint) -> Int? {
        HexGridLayout.byteOffset(
            at: point,
            rowCount: rowCount,
            fileSize: fileSize,
            bytesPerRow: bytesPerRow
        )
    }
}

final class HexSelectionMouseView: NSView {
    weak var coordinator: HexSelectionHandlingView.Coordinator?

    override var isOpaque: Bool { false }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard let offset = coordinator?.offset(at: localPoint) else {
            return nil
        }
        if offset == coordinator?.parent.editingOffset {
            return nil
        }
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let extending = event.modifierFlags.contains(.shift)
        coordinator?.handleMouseDown(at: point, extending: extending, clickCount: event.clickCount)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseDragged(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleMouseUp(at: point)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        coordinator?.handleRightMouseDown(at: point, in: self, event: event)
    }
}
