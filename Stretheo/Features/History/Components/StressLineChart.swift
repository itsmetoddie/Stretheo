//
//  StressLineChart.swift
//  Stretheo
//

import Charts
import OSLog
import SwiftUI

struct StressLineChart: View {
    let points: [StressChartPoint]
    let period: HistoryPeriod
    var chartDrawn: Bool = true
    var isEmbedded: Bool = false

    private var lineInterpolation: InterpolationMethod {
        period == .day && points.count <= 48 ? .catmullRom : .linear
    }

    private var showsPointMarks: Bool {
        period == .day && points.count <= 48
    }

    private var weekAxisDates: [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var day = calendar.startOfDay(for: xDomain.lowerBound)
        let endDay = calendar.startOfDay(for: xDomain.upperBound)
        let maxDays = 14 // a real "week" axis never needs more than this; guards
                          // against transient prop desync producing a huge domain
        var count = 0
        while day <= endDay && count < maxDays {
            dates.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
            count += 1
        }
        return dates
    }

    private var chartAccentColor: Color {
        guard !points.isEmpty else { return AppColors.stressColor(for: .low) }
        let average = points.map(\.level).reduce(0, +) / points.count
        return AppColors.stressColor(for: StressCategory.from(level: average))
    }

    private var xDomain: ClosedRange<Date> {
        switch period {
        case .day:
            return intradayXDomain
        case .all:
            return allXDomain
        case .week, .month, .threeMonths:
            let computed = period.dateRange(reference: Date())
            let end = max(computed.end, computed.start.addingTimeInterval(60))
            return computed.start...end
        }
    }

    /// ±30 minutes around data; if empty, current time ±2 hours.
    private var intradayXDomain: ClosedRange<Date> {
        let padding: TimeInterval = 30 * 60
        if let first = points.first?.date, let last = points.last?.date {
            let start = first.addingTimeInterval(-padding)
            let end = last.addingTimeInterval(padding)
            if start < end {
                return start...end
            }
            return start...start.addingTimeInterval(padding * 2)
        }
        let now = Date()
        let twoHours: TimeInterval = 2 * 60 * 60
        return now.addingTimeInterval(-twoHours)...now.addingTimeInterval(twoHours)
    }

    /// Spans from the earliest loaded measurement to now; falls back to the
    /// period's default range if no data has loaded yet.
    private var allXDomain: ClosedRange<Date> {
        guard let first = points.first?.date else {
            let computed = period.dateRange(reference: Date())
            let end = max(computed.end, computed.start.addingTimeInterval(60))
            return computed.start...end
        }
        let now = Date()
        if first < now {
            return first...now
        }
        return first...first.addingTimeInterval(60)
    }

    var body: some View {
        Group {
            if isEmbedded {
                embeddedBody
            } else {
                standaloneBody
            }
        }
        .accessibilityLabel(String(localized: "history.chart.accessibility"))
    }

    private var standaloneBody: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            chartHeader

            if points.isEmpty {
                EmptyStateView(
                    title: String(localized: "history.empty.title"),
                    message: String(localized: "history.chart.empty"),
                    systemImage: "chart.xyaxis.line"
                )
                .frame(maxWidth: .infinity, minHeight: chartHeight)
            } else {
                chartPlotRow
            }
        }
        .homeScreenCard(padding: AppSpacing.md)
    }

    private var embeddedBody: some View {
        Group {
            if points.isEmpty {
                EmptyStateView(
                    title: String(localized: "history.empty.title"),
                    message: String(localized: "history.chart.empty"),
                    systemImage: "chart.xyaxis.line"
                )
                .frame(maxWidth: .infinity, minHeight: chartHeight)
            } else {
                chartPlotRow
            }
        }
    }

    private var chartPlotRow: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(String(localized: "history.chart.y_axis_label"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(width: 16)

            stressChart
        }
    }

    private var chartHeight: CGFloat {
        isEmbedded ? 180 : 220
    }

    private var chartHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.xyaxis.line")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(chartSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var stressChart: some View {
        let _ = logChartRenderContext()
        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Min", 0),
                    yEnd: .value("Level", point.level)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [chartAccentColor.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(lineInterpolation)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Stress", point.level)
                )
                .foregroundStyle(chartAccentColor)
                .interpolationMethod(lineInterpolation)
            }

            if showsPointMarks {
                ForEach(points) { point in
                    PointMark(
                        x: .value("Time", point.date),
                        y: .value("Stress", point.level)
                    )
                    .foregroundStyle(chartAccentColor)
                    .symbolSize(36)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: chartDrawn ? -8...108 : 0...1)
        .modifier(EmbeddedChartAnimationModifier(isEmbedded: isEmbedded, points: points))
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                if let level = value.as(Int.self), [25, 50, 75].contains(level) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color(.separator))
                }
                AxisValueLabel()
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis {
            periodXAxis
        }
        .clipped(antialiased: false)
        .chartPlotStyle { plotArea in
            plotArea
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(height: chartHeight)
    }

    @AxisContentBuilder
    private var periodXAxis: some AxisContent {
        switch period {
        case .day:
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        case .week:
            AxisMarks(values: weekAxisDates) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(.secondaryLabel))
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(.secondaryLabel))
            }
        case .threeMonths:
            AxisMarks(values: .stride(by: .month, count: 1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(.secondaryLabel))
            }
        case .all:
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(.systemGray5))
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }

    private var allViewStride: Int {
        guard let first = points.first?.date,
              let last = points.last?.date else { return 2 }
        let months = Calendar.current.dateComponents([.month], from: first, to: last).month ?? 0
        return months > 12 ? 3 : 2
    }

    private func logChartRenderContext() {
        let computed = period.dateRange(reference: Date())
        let spanDays = Calendar.current.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 0
        StretheoLog.history.debug(
            "STRESS_HISTORY_RANGE_CHANGE: chart render period=\(period.rawValue, privacy: .public) points=\(points.count, privacy: .public) xDomainDays=\(spanDays, privacy: .public) domainStart=\(computed.start, privacy: .public) domainEnd=\(computed.end, privacy: .public)"
        )
    }

    private var chartTitle: String {
        switch period {
        case .day:
            String(localized: "history.chart.today_title")
        case .week:
            String(localized: "history.chart.week_title")
        case .month:
            String(localized: "history.chart.month_title")
        case .threeMonths:
            String(localized: "history.chart.custom_title")
        case .all:
            String(localized: "history.chart.custom_title")
        }
    }

    private var chartSubtitle: String {
        switch period {
        case .day:
            String(localized: "history.chart.today_subtitle")
        case .week:
            String(localized: "history.chart.week_subtitle")
        case .month:
            String(localized: "history.chart.month_subtitle")
        case .threeMonths:
            String(localized: "history.chart.custom_subtitle")
        case .all:
            String(localized: "history.chart.custom_subtitle")
        }
    }
}

private struct EmbeddedChartAnimationModifier: ViewModifier {
    let isEmbedded: Bool
    let points: [StressChartPoint]

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content.animation(.easeInOut(duration: 0.7), value: points)
        }
    }
}
