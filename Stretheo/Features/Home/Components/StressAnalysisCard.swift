//
//  StressAnalysisCard.swift
//  Stretheo
//

import SwiftUI

enum MeasureButtonState: Equatable {
    case idle
    case measuring
}

struct StressAnalysisCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let level: Int
    var stressLevel: Int?
    let category: StressCategory
    let hint: String
    let hasMeasurement: Bool
    let isMeasuring: Bool
    @Binding var measureButtonState: MeasureButtonState
    @Binding var stressSaveConfirmed: Bool
    @Binding var stressCardScale: CGFloat
    var gaugeProgressValue: Double = 0
    var reduceMotion: Bool = false
    var measurementID: UUID? = nil
    let onMeasure: () -> Void

    private var accentColor: Color {
        AppColors.stressColor(for: category)
    }

    var body: some View {
        cardContent
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "brain.head.profile",
                title: String(localized: "home.analysis.title"),
                subtitle: String(localized: "home.analysis.subtitle")
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                stressMeasurementPanel
                    .scaleEffect(stressCardScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: stressCardScale)

                MeasureNowButton(
                    state: measureButtonState,
                    isMeasuring: isMeasuring,
                    saveConfirmed: stressSaveConfirmed,
                    accentColor: accentColor,
                    reduceMotion: reduceMotion,
                    action: onMeasure
                )
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.lg)
        }
        .homeScreenCard(padding: 0)
    }

    private var stressMeasurementPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if hasMeasurement {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    stressGauge
                    stressDetailLabels
                }
            } else {
                CardInlineEmptyState(
                    systemImage: "waveform.path.ecg",
                    title: String(localized: "home.analysis.empty.title")
                )
                .frame(height: 120)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColors.stressBackground(for: category, colorScheme: colorScheme),
            in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
        )
    }

    private var stressGauge: some View {
        StressGaugeView(
            level: level,
            stressLevel: stressLevel,
            category: category,
            showsCategory: false,
            showsValue: true,
            isMeasuring: isMeasuring && !reduceMotion,
            gaugeProgressValue: gaugeProgressValue,
            reduceMotion: reduceMotion,
            measurementID: measurementID
        )
    }

    private var stressDetailLabels: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(String(localized: "home.analysis.current"))
                .font(AppTypography.metadata)
                .foregroundStyle(AppColors.secondaryLabel)

            HStack(spacing: AppSpacing.xxs) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                Text(category.localizedTitle)
                    .font(AppTypography.rowPrimary)
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text(hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Measure Now button

private struct MeasureNowButton: View {
    let state: MeasureButtonState
    let isMeasuring: Bool
    let saveConfirmed: Bool
    let accentColor: Color
    var reduceMotion: Bool = false
    let action: () -> Void

    @State private var waveformBounceTrigger = 0

    private var buttonCornerRadius: CGFloat { 16 }

    private var showMeasuringUI: Bool {
        isMeasuring || state == .measuring
    }

    var body: some View {
        Button {
            waveformBounceTrigger += 1
            action()
        } label: {
            Group {
                if saveConfirmed {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                        Text(String(localized: "home.measure.saved"))
                            .font(.headline)
                            .transition(.opacity)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.2), value: saveConfirmed)

                } else if showMeasuringUI {
                    // CLEANED: TimelineView-driven pulse stops when measuring UI is removed (no repeatForever leak)
                    MeasuringButtonLabel(
                        accentColor: accentColor,
                        cornerRadius: buttonCornerRadius,
                        reduceMotion: reduceMotion
                    )

                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .symbolEffect(.bounce, value: waveformBounceTrigger)
                        Text(String(localized: "home.measure_now"))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius, style: .continuous))
                }
            }
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle || saveConfirmed || showMeasuringUI)
        .animation(
            reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75),
            value: state
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: saveConfirmed
        )
        .accessibilityLabel(String(localized: "home.measure_now"))
    }
}

// MARK: - Measuring button label

private struct MeasuringButtonLabel: View {
    let accentColor: Color
    let cornerRadius: CGFloat
    var reduceMotion: Bool = false

    var body: some View {
        Group {
            if reduceMotion {
                measuringContent
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let phase = (sin(context.date.timeIntervalSinceReferenceDate * .pi / 0.4) + 1) / 2
                    measuringContent
                        .opacity(0.7 + 0.3 * phase)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(accentColor.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var measuringContent: some View {
        HStack(spacing: 8) {
            MeasuringWaveformBars(reduceMotion: reduceMotion)
            Text(String(localized: "home.measure.measuring"))
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Measuring waveform bars

private struct MeasuringWaveformBars: View {
    var reduceMotion: Bool = false

    var body: some View {
        if reduceMotion {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.9)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let phase = sin(
                            context.date.timeIntervalSinceReferenceDate * 6
                                + Double(index) * 0.9
                        )
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 3, height: 8 + CGFloat(phase + 1) * 6)
                    }
                }
            }
            .frame(height: 20)
        }
    }
}
