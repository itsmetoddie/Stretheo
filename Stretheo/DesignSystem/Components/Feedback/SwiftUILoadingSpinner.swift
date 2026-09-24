//
//  SwiftUILoadingSpinner.swift
//  Stretheo
//
//  Pure SwiftUI indeterminate spinner (replaces ProgressView in flattened layers).
//

import SwiftUI

struct SwiftUILoadingSpinner: View {
    var tint: Color = AppColors.textOnPrimary
    var size: CGFloat = 22
    var lineWidth: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let degrees = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1) * 360

            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(degrees))
        }
        .accessibilityHidden(true)
    }
}
