//
//  CompareMinimapView.swift
//  HexMac
//

import SwiftUI

struct CompareMinimapView: View {
    let diffMap: CompareDiffMap?
    let isLoading: Bool
    let visibleRowRange: ClosedRange<Int>
    let rowCount: Int
    let onNavigate: (Int) -> Void

    private let stripWidth: CGFloat = 14
    private let stripGap: CGFloat = 2

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 8)
            }

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

                    viewportIndicator(height: geometry.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            navigate(toY: value.location.y, height: geometry.size.height)
                        }
                )
            }
        }
        .frame(width: stripWidth * 2 + stripGap + 10)
        .padding(.vertical, 8)
        .padding(.trailing, 4)
        .background(.bar)
    }

    private func minimapStrip(kinds: [DiffRegionKind], height: CGFloat) -> some View {
        Canvas { context, size in
            let bucketCount = max(kinds.count, 1)
            let bucketHeight = max(1, size.height / CGFloat(bucketCount))

            for index in 0..<bucketCount {
                let rect = CGRect(
                    x: 0,
                    y: CGFloat(index) * bucketHeight,
                    width: size.width,
                    height: bucketHeight
                )
                context.fill(
                    Path(rect),
                    with: .color(color(for: kinds[safe: index] ?? .equal))
                )
            }
        }
        .frame(width: stripWidth, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
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

    private func navigate(toY y: CGFloat, height: CGFloat) {
        guard rowCount > 0, height > 0 else { return }
        let fraction = min(1, max(0, y / height))
        let row = min(rowCount - 1, Int(fraction * CGFloat(rowCount)))
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
