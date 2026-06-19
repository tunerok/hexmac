//
//  HexVerticalScrollbar.swift
//  HexMac
//

import SwiftUI

struct HexVerticalScrollbar: View {
    @Binding var firstVisibleRow: Int
    let rowCount: Int
    let visibleRowCount: Int

    var body: some View {
        let maxRow = max(0, rowCount - visibleRowCount)
        if rowCount > visibleRowCount {
            ScrollbarTrack(
                value: Binding(
                    get: { Double(firstVisibleRow) },
                    set: { newValue in
                        firstVisibleRow = min(max(0, Int(newValue.rounded())), maxRow)
                    }
                ),
                range: 0...Double(maxRow),
                visibleFraction: Double(visibleRowCount) / Double(max(rowCount, 1))
            )
            .frame(width: 14)
            .padding(.leading, 2)
        }
    }
}

private struct ScrollbarTrack: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let visibleFraction: Double

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = geometry.size.height
            let thumbHeight = max(24, trackHeight * visibleFraction)
            let travel = max(0, trackHeight - thumbHeight)
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let thumbY = travel * fraction

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: 8, height: thumbHeight)
                    .offset(y: thumbY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                guard travel > 0 else { return }
                                let newFraction = min(1, max(0, gesture.location.y / trackHeight))
                                value = range.lowerBound + newFraction * span
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
