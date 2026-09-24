//
//  StressGaugeView.swift
//  Stretheo
//
//  Pure SwiftUI stress ring — no UIKit / UIViewRepresentable.
//

import SwiftUI
import UIKit

struct StressGaugeView: View {
    let level: Int
    var stressLevel: Int?
    let category: StressCategory
    var showsCategory: Bool = true
    var showsValue: Bool = true
    var isMeasuring: Bool = false
    var gaugeProgressValue: Double = 0
    var reduceMotion: Bool = false
    var measurementID: UUID? = nil

    @State private var renderedScore: Int = 0

    private static let gaugeDiameter: CGFloat = 88
    private static let gaugeStroke: CGFloat = 8
    /// Fixed UIKit font — does not scale with Dynamic Type (score sits inside a fixed-size ring).
    private static let scoreUIFont: UIFont = {
        let size: CGFloat = 32
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }()

    private static let arcSpan: CGFloat = 0.75
    private static let arcRotation = Angle.degrees(135)

    private var targetScore: Int {
        stressLevel ?? level
    }

    private var stressColor: Color {
        Color.stressColor(for: category)
    }

    private var valueTrim: CGFloat {
        guard showsValue else { return 0 }
        let progress = CGFloat(min(max(gaugeProgressValue, 0), 1))
        let target = progress > 0 ? progress : 1
        return min(target * Self.arcSpan, Self.arcSpan)
    }

    var body: some View {
        Group {
            if isMeasuring, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    gaugeContent(pulsePhase: pulsePhase(at: context.date))
                }
            } else {
                gaugeContent(pulsePhase: 1)
            }
        }
        .frame(width: Self.gaugeDiameter, height: Self.gaugeDiameter)
    }

    @ViewBuilder
    private func gaugeContent(pulsePhase: Double) -> some View {
        let ringOpacity = isMeasuring && !reduceMotion
            ? 0.55 + 0.45 * pulsePhase
            : 1.0
        let trackStyle = StrokeStyle(lineWidth: Self.gaugeStroke, lineCap: .round)
        let valueStyle = StrokeStyle(lineWidth: Self.gaugeStroke, lineCap: .round)

        ZStack {
            Circle()
                .trim(from: 0, to: Self.arcSpan)
                .stroke(
                    stressColor.opacity(0.15),
                    style: trackStyle
                )
                .rotationEffect(Self.arcRotation)

            Circle()
                .trim(from: 0, to: valueTrim)
                .stroke(
                    stressColor.opacity(ringOpacity),
                    style: valueStyle
                )
                .rotationEffect(Self.arcRotation)

            if showsValue {
                scoreLabel
            }
        }
    }

    @ViewBuilder
    private var scoreLabel: some View {
        if showsCategory {
            VStack(spacing: AppSpacing.xxs) {
                scoreText
                Text(category.localizedTitle)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(stressColor)
            }
        } else {
            scoreText
        }
    }

    private var scoreText: some View {
        Text("\(renderedScore)")
            .font(Font(Self.scoreUIFont))
            .foregroundStyle(stressColor)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            // Cold-launch fix: no score animation on appear. Animate only via .onChange when a new
            // measurement arrives after the view is already on screen (do not add .onAppear animation).
            .onAppear {
                renderedScore = targetScore
            }
            .onChange(of: measurementID) { oldValue, _ in
                guard oldValue != nil else { return }
                withAnimation(.snappy) {
                    renderedScore = targetScore
                }
            }
            .accessibilityLabel(String(localized: "home.stress.level \(renderedScore)"))
    }

    private func pulsePhase(at date: Date) -> Double {
        let period = reduceMotion ? 1 : 3.0
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return (sin(t * 2 * .pi) + 1) / 2
    }
}
