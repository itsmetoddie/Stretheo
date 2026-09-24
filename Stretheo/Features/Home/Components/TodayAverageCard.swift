//
//  TodayAverageCard.swift
//  Stretheo
//

import SwiftUI

struct TodayAverageCard: View {
    let average: Int
    let checkInCount: Int
    let category: StressCategory
    let sparklinePoints: [SparklinePoint]
    let lastMeasuredAt: Date?

    private var stressColor: Color {
        AppColors.stressColor(for: category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                systemImage: "chart.line.uptrend.xyaxis",
                title: String(localized: "home.today_average"),
                trailing: {
                    if checkInCount > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(average)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(stressColor)
                                .contentTransition(.numericText())
                            Text("/100")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if checkInCount > 0 {
                    footerLine
                }
                chartOrEmptyState
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .homeScreenCard(padding: 0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerLine: some View {
        Text(footerText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerText: String {
        var parts: [String] = []
        if checkInCount == 1 {
            parts.append(String(localized: "home.checkin.singular"))
        } else {
            parts.append(String(format: String(localized: "home.checkins_count"), checkInCount))
        }
        if let lastMeasuredAt {
            parts.append(lastAtText(for: lastMeasuredAt))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var chartOrEmptyState: some View {
        if checkInCount == 0 {
            CardInlineEmptyState(
                systemImage: "waveform.path.ecg",
                title: String(localized: "home.today_average.empty.readings"),
                hint: String(localized: "home.today_average.empty.start")
            )
        } else {
            SparklineView(
                points: sparklinePoints,
                lineColor: stressColor
            )
        }
    }

    private func lastAtText(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        return String(format: String(localized: "home.today_stress.last_at"), time)
    }
}
