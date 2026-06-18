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
    let onFinishEditing: () -> Void
    let onBeginSelection: (Int, Bool) -> Void
    let onUpdateSelection: (Int) -> Void
    let onEndSelection: (Int) -> Void
    let onBeginEdit: (Int) -> Void

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

    final class Coordinator {
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
}
