//
//  RecentCheckInRow.swift
//  Stretheo
//

import SwiftUI

struct RecentCheckInRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let measurement: StressMeasurement

    private var scoreColor: Color {
        AppColors.stressColor(for: measurement.stressLevel)
    }

    private var checkInCardBackground: Color {
        AppColors.checkInBackground(
            for: measurement.stressCategory,
            colorScheme: colorScheme
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top) {
                Text("\(measurement.stressLevel)")
                    .font(AppTypography.stressIndexMedium)
                    .foregroundStyle(scoreColor)

                Spacer(minLength: AppSpacing.sm)

                HStack(spacing: 6) {
                    SourceBadge(triggerType: measurement.triggerTypeRaw)
                    Text(RecordDateFormatting.formatted(measurement.measuredAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let snap = measurement.healthSnapshot {
                HStack(spacing: AppSpacing.lg) {
                    metric(
                        icon: "heart.fill",
                        color: AppColors.stressColor(for: .high),
                        value: heartRateText(snap)
                    )
                    metric(icon: "waveform.path.ecg", color: AppColors.appPrimary, value: hrvText(snap))
                    if let energyText = energyMetricText(snap) {
                        metric(
                            icon: "bolt.fill",
                            color: AppColors.stressColor(for: .low),
                            value: energyText
                        )
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            checkInCardBackground,
            in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(checkInAccessibilityLabel)
    }

    private var checkInAccessibilityLabel: String {
        let when = measurement.measuredAt.formatted(.relative(presentation: .named))
        return String(
            format: String(localized: "accessibility.checkin.row"),
            measurement.stressLevel,
            measurement.stressCategory.localizedTitle,
            when
        )
    }

    private func metric(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(AppTypography.caption)
                .foregroundStyle(color)
            Text(value)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.label)
        }
    }

    private func heartRateText(_ snap: HealthSnapshot) -> String {
        let bpm = snap.currentHeartRate ?? snap.restingHeartRate
        guard let bpm else { return "—" }
        return "\(Int(bpm.rounded())) bpm"
    }

    private func hrvText(_ snap: HealthSnapshot) -> String {
        guard let hrv = snap.hrv else { return "—" }
        return "\(Int(hrv.rounded())) ms"
    }

    private func energyMetricText(_ snap: HealthSnapshot) -> String? {
        guard let score = snap.sleepQualityScore else { return nil }
        return "\(score)%"
    }
}
