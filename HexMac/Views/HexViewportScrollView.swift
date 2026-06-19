//
//  HexViewportScrollView.swift
//  HexMac
//

import AppKit
import SwiftUI

struct HexViewportScrollView<RowContent: View, Overlay: View>: View {
    @Binding var firstVisibleRow: Int
    let rowCount: Int
    let bytesPerRow: Int
    let visibleRowCount: Int
    let scrollTargetRow: Int?
    let scrollAnchor: HexScrollAnchor
    let linkedScrollRow: Binding<Int?>?
    let onVisibleRowChanged: ((Int) -> Void)?
    let onVisibleRowRangeChanged: ((ClosedRange<Int>) -> Void)?
    let onPrefetchRange: ((Range<Int>) -> Void)?
    let onEnsureVisibleRowsLoaded: ((Range<Int>) -> Void)?
    let onScrollTargetHandled: () -> Void
    @ViewBuilder let rowContent: (Int) -> RowContent
    @ViewBuilder let overlay: (Int) -> Overlay

    @State private var scrollPhase: HexScrollPhase = .idle
    @State private var scrollAccumulator: CGFloat = 0
    @State private var isApplyingLinkedScroll = false
    @State private var lastHandledScrollTarget: Int?
    @State private var lastWheelApplyTime: Date = .distantPast

    private var scrollWindow: HexScrollWindow {
        HexScrollWindow(
            firstVisibleRow: firstVisibleRow,
            visibleRowCount: visibleRowCount,
            phase: scrollPhase
        )
    }

    var body: some View {
        let window = scrollWindow
        let renderedRange = window.renderedRange(for: rowCount)
        let rowHeight = HexGridLayout.rowHeight
        let topPadding = HexGridLayout.contentPadding

        ZStack(alignment: .topLeading) {
            ForEach(Array(renderedRange), id: \.self) { rowIndex in
                rowContent(rowIndex)
                    .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
                    .offset(y: topPadding + CGFloat(rowIndex - firstVisibleRow) * rowHeight)
            }

            overlay(firstVisibleRow)
                .padding(.top, topPadding)

            ViewportScrollWheelInstaller { deltaY, phase in
                handleScrollWheel(deltaY: deltaY, phase: phase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .onChange(of: firstVisibleRow) { _, _ in
            reportVisibleState(window: scrollWindow)
        }
        .onAppear {
            reportVisibleState(window: window)
        }
        .onChange(of: bytesPerRow) { oldValue, newValue in
            guard oldValue != newValue else { return }
            var window = scrollWindow
            window.adaptToBytesPerRowChange(
                from: oldValue,
                to: newValue,
                rowCount: rowCount
            )
            applyWindow(window)
            reportVisibleState(window: window)
        }
        .onChange(of: visibleRowCount) { _, _ in
            clampFirstVisibleRow()
            reportVisibleState(window: scrollWindow)
        }
        .onChange(of: rowCount) { _, _ in
            clampFirstVisibleRow()
            reportVisibleState(window: scrollWindow)
        }
        .onChange(of: scrollTargetRow) { _, newValue in
            if newValue == nil {
                lastHandledScrollTarget = nil
                return
            }
            guard let newValue else { return }
            applyScrollTarget(newValue, anchor: scrollAnchor)
        }
        .onChange(of: linkedScrollRow?.wrappedValue) { _, row in
            guard let row, !isApplyingLinkedScroll else { return }
            isApplyingLinkedScroll = true
            var window = scrollWindow
            window.jumpTo(row: row, rowCount: rowCount, anchor: .top)
            applyWindow(window)
            #if DEBUG
            HexScrollLog.windowState(window, rowCount: rowCount, event: "linkedScroll")
            #endif
            reportVisibleState(window: window)
            DispatchQueue.main.async {
                isApplyingLinkedScroll = false
            }
        }
    }

    private func clampFirstVisibleRow() {
        var window = scrollWindow
        window.clamp(for: rowCount)
        applyWindow(window)
    }

    private func applyWindow(_ window: HexScrollWindow) {
        firstVisibleRow = window.firstVisibleRow
        scrollPhase = window.phase
    }

    private func handleScrollWheel(deltaY: CGFloat, phase: NSEvent.Phase) {
        guard rowCount > 0 else { return }

        if phase.contains(.began) {
            scrollAccumulator = 0
            scrollPhase = .scrolling
        }

        scrollAccumulator += deltaY

        if phase.contains(.ended) || phase.contains(.cancelled) {
            applyAccumulatedScroll(force: true)
            scrollPhase = .idle
            scrollAccumulator = 0
            reportVisibleState(window: scrollWindow)
            return
        }

        applyAccumulatedScroll(force: false)
    }

    private func applyAccumulatedScroll(force: Bool) {
        let threshold = HexGridLayout.rowHeight * 0.15
        guard force || abs(scrollAccumulator) >= threshold else { return }

        let now = Date()
        let minInterval: TimeInterval = 1.0 / 60.0
        if !force, now.timeIntervalSince(lastWheelApplyTime) < minInterval {
            return
        }

        let rows: Int
        if abs(scrollAccumulator) < threshold {
            if !force { return }
            rows = scrollAccumulator > 0 ? -1 : (scrollAccumulator < 0 ? 1 : 0)
        } else {
            rows = scrollAccumulator > 0
                ? -max(1, Int(round(scrollAccumulator / HexGridLayout.rowHeight)))
                : max(1, Int(round(-scrollAccumulator / HexGridLayout.rowHeight)))
        }

        guard rows != 0 else { return }

        var window = scrollWindow
        window.beginScrolling()
        window.scrollBy(delta: rows, rowCount: rowCount)
        applyWindow(window)
        scrollAccumulator = 0
        lastWheelApplyTime = now

        #if DEBUG
        HexScrollLog.windowState(window, rowCount: rowCount, event: "wheel")
        #endif
        reportVisibleState(window: window)
    }

    private func applyScrollTarget(_ row: Int, anchor: HexScrollAnchor) {
        if row == lastHandledScrollTarget {
            onScrollTargetHandled()
            return
        }
        lastHandledScrollTarget = row
        var window = scrollWindow
        window.jumpTo(row: row, rowCount: rowCount, anchor: anchor)
        scrollPhase = .idle
        applyWindow(window)
        #if DEBUG
        HexScrollLog.windowState(window, rowCount: rowCount, event: "jump")
        #endif
        reportVisibleState(window: window)
        onScrollTargetHandled()
    }

    private func reportVisibleState(window: HexScrollWindow) {
        guard !isApplyingLinkedScroll else { return }
        let visible = window.visibleRowRange(for: rowCount)
        onVisibleRowRangeChanged?(visible)
        onVisibleRowChanged?(window.firstVisibleRow)

        let visibleLoadRange = window.firstVisibleRow..<min(
            rowCount,
            window.firstVisibleRow + max(1, visibleRowCount)
        )
        onEnsureVisibleRowsLoaded?(visibleLoadRange)
        onPrefetchRange?(window.prefetchRange(for: rowCount))
    }
}

// MARK: - Scroll wheel monitor

private struct ViewportScrollWheelInstaller: NSViewRepresentable {
    let onScroll: (CGFloat, NSEvent.Phase) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> InstallerNSView {
        let view = InstallerNSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: InstallerNSView, context: Context) {
        context.coordinator.onScroll = onScroll
        context.coordinator.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: InstallerNSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onScroll: (CGFloat, NSEvent.Phase) -> Void
        private weak var view: InstallerNSView?
        private var monitor: Any?

        init(onScroll: @escaping (CGFloat, NSEvent.Phase) -> Void) {
            self.onScroll = onScroll
        }

        func attach(to view: InstallerNSView) {
            self.view = view
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let view = self.view, let window = view.window else { return event }
                let location = window.mouseLocationOutsideOfEventStream
                let local = view.convert(location, from: nil)
                guard view.bounds.contains(local) else { return event }
                self.onScroll(event.scrollingDeltaY, event.phase)
                return event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            view = nil
        }
    }
}

private final class InstallerNSView: NSView {
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
