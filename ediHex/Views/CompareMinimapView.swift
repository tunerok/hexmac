//
//  CompareMinimapView.swift
//  ediHex
//

import SwiftUI

struct CompareMinimapView: View {
    let diffMap: CompareDiffMap?
    let isLoading: Bool
    let progress: Double?
    let visibleRowRange: ClosedRange<Int>
    let rowCount: Int
    let onNavigate: (Int) -> Void

    @State private var lastNavigatedRow: Int?
    @State private var lastNavigateTime = Date.distantPast

    private let stripWidth: CGFloat = 14
    private let stripGap: CGFloat = 2
    private let scrubInterval: TimeInterval = 0.075
    private let minDiffMarkerHeight: CGFloat = 3
    private let scanProgressLineHeight: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack(spacing: stripGap) {
                    minimapStrip(
                        kinds: diffMap?.leftKinds ?? [],
                        height: geometry.size.height
                    )
                    minimapStrip(
                        kinds: diffMap?.rightKinds ?? [],
                        height: geometry.size.height
                    )
                }

                if isLoading {
                    scanProgressIndicator(
                        height: geometry.size.height,
                        progress: progress ?? 0
                    )
                }

                viewportIndicator(height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        navigate(
                            toY: value.location.y,
                            height: geometry.size.height,
                            isFinal: false
                        )
                    }
                    .onEnded { value in
                        navigate(
                            toY: value.location.y,
                            height: geometry.size.height,
                            isFinal: true
                        )
                    }
            )
        }
        .frame(width: stripWidth * 2 + stripGap + 10)
        .padding(.vertical, 8)
        .padding(.trailing, 4)
        .background(.bar)
    }

    private func minimapStrip(kinds: [DiffRegionKind], height: CGFloat) -> some View {
        Canvas { context, size in
            let bucketCount = max(kinds.count, 1)

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.secondary.opacity(0.12))
            )

            for index in 0..<bucketCount {
                let kind = kinds[safe: index] ?? .equal
                guard kind != .equal else { continue }

                let centerY = (CGFloat(index) + 0.5) / CGFloat(bucketCount) * size.height
                let proportionalHeight = size.height / CGFloat(bucketCount)
                let markerHeight = max(minDiffMarkerHeight, proportionalHeight)
                let rect = CGRect(
                    x: 0,
                    y: centerY - markerHeight / 2,
                    width: size.width,
                    height: markerHeight
                )
                context.fill(
                    Path(rect),
                    with: .color(color(for: kind))
                )
            }
        }
        .frame(width: stripWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func scanProgressIndicator(height: CGFloat, progress: Double) -> some View {
        let fraction = CGFloat(min(1, max(0, progress)))

        return Capsule()
            .fill(Color.primary.opacity(0.55))
            .frame(width: stripWidth * 2 + stripGap, height: scanProgressLineHeight)
            .offset(y: fraction * height - scanProgressLineHeight / 2)
            .allowsHitTesting(false)
    }

    private func viewportIndicator(height: CGFloat) -> some View {
        let totalRows = max(rowCount, 1)
        let startFraction = CGFloat(visibleRowRange.lowerBound) / CGFloat(totalRows)
        let endFraction = CGFloat(visibleRowRange.upperBound + 1) / CGFloat(totalRows)
        let indicatorHeight = max(6, (endFraction - startFraction) * height)

        return RoundedRectangle(cornerRadius: 2)
            .stroke(Color.accentColor.opacity(0.9), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.12))
            )
            .frame(width: stripWidth * 2 + stripGap, height: indicatorHeight)
            .offset(y: startFraction * height)
            .allowsHitTesting(false)
    }

    private func navigate(toY y: CGFloat, height: CGFloat, isFinal: Bool) {
        guard rowCount > 0, height > 0 else { return }
        let fraction = min(1, max(0, y / height))
        let row = min(rowCount - 1, Int(fraction * CGFloat(rowCount)))

        if !isFinal {
            if row == lastNavigatedRow { return }
            let now = Date()
            if now.timeIntervalSince(lastNavigateTime) < scrubInterval { return }
            lastNavigateTime = now
        }

        lastNavigatedRow = row
        onNavigate(row)
    }

    private func color(for kind: DiffRegionKind) -> Color {
        switch kind {
        case .equal:
            Color.secondary.opacity(0.12)
        case .deleted:
            Color.red.opacity(0.85)
        case .added:
            Color.green.opacity(0.85)
        case .changed:
            Color.yellow.opacity(0.9)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
