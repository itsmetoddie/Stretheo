//
//  SparklineView.swift
//  Stretheo
//

import Charts
import SwiftUI

struct SparklinePoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct SparklineView: View {
    let points: [SparklinePoint]
    var lineColor: Color = AppColors.appPrimary
    var threshold: Int = AppSettings.stressAlertThreshold

    private let sortedPoints: [SparklinePoint]
    private let xDomain: ClosedRange<Date>?
    private let xAxisEndpoints: [Date]
    private let endpointPointIDs: Set<UUID>

    init(
        points: [SparklinePoint],
        lineColor: Color = AppColors.appPrimary,
        threshold: Int = AppSettings.stressAlertThreshold
    ) {
        self.points = points
        self.lineColor = lineColor
        self.threshold = min(max(threshold, 0), 100)
        self.sortedPoints = points.sorted { $0.date < $1.date }
        self.xDomain = Self.makeXDomain(from: points)
        self.xAxisEndpoints = Self.makeXAxisEndpoints(from: points)
        if let first = self.sortedPoints.first?.id {
            var ids: Set<UUID> = [first]
            if let last = self.sortedPoints.last?.id, last != first {
                ids.insert(last)
            }
            self.endpointPointIDs = ids
        } else {
            self.endpointPointIDs = []
        }
    }

    private var showsChart: Bool {
        !points.isEmpty
    }

    var body: some View {
        Group {
            if showsChart {
                chartContent
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var chartContent: some View {
        let chart = Chart {
            ForEach(sortedPoints) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Min", 0),
                    yEnd: .value("Level", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Stress", point.value)
                )
                .foregroundStyle(lineColor)
                .interpolationMethod(.catmullRom)
            }

            ForEach(sortedPoints.filter { endpointPointIDs.contains($0.id) }) { point in
                PointMark(
                    x: .value("Time", point.date),
                    y: .value("Stress", point.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(28)
            }

            RuleMark(y: .value("Threshold", threshold))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color(.systemRed).opacity(0.4))
                .annotation(position: .trailing, alignment: .center) {
                    Text("limit")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemRed).opacity(0.6))
                }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: xAxisEndpoints) { value in
                if let date = value.as(Date.self) {
                    let isFirst = date == xAxisEndpoints.first
                    AxisValueLabel(anchor: isFirst ? .topLeading : .topTrailing) {
                        Text(
                            date,
                            format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }

        let paddedChart = chart
            .padding(.trailing, 16)

        if let xDomain {
            paddedChart.chartXScale(domain: xDomain)
        } else {
            paddedChart
        }
    }

    private var accessibilityText: String {
        guard showsChart else { return "" }
        return String(localized: "home.sparkline.accessibility")
    }

    private static func makeXDomain(from points: [SparklinePoint]) -> ClosedRange<Date>? {
        guard let first = points.map(\.date).min() else { return nil }
        guard let last = points.map(\.date).max() else { return nil }

        if first >= last {
            let padding: TimeInterval = 60 * 60
            return first.addingTimeInterval(-padding)...first.addingTimeInterval(padding)
        }

        let span = last.timeIntervalSince(first)
        let padding = max(span * 0.08, 90)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private static func makeXAxisEndpoints(from points: [SparklinePoint]) -> [Date] {
        let sorted = points.map(\.date).sorted()
        guard let first = sorted.first else { return [] }
        guard let last = sorted.last, sorted.count > 1, first != last else {
            return [first]
        }
        return [first, last]
    }
}
