//
//  StressHistoryChartCard.swift
//  Stretheo
//

import OSLog
import SwiftUI

private enum StressHistoryRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case all

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .week: "W"
        case .month: "M"
        case .threeMonths: "3M"
        case .all: String(localized: "history.chart.range.all")
        }
    }

    static func from(period: HistoryPeriod) -> StressHistoryRange {
        switch period {
        case .week, .day: return .week
        case .month: return .month
        case .threeMonths: return .threeMonths
        case .all: return .all
        }
    }

    var historyPeriod: HistoryPeriod {
        switch self {
        case .week: .week
        case .month: .month
        case .threeMonths: .threeMonths
        case .all: .all
        }
    }
}

struct StressHistoryChartCard: View {
    @Bindable var viewModel: HistoryViewModel
    let points: [StressChartPoint]
    let rangeStart: Date
    let rangeEnd: Date
    var chartDrawn: Bool
    var isChartLoading: Bool = false

    @State private var selectedRange: StressHistoryRange = .week
    @State private var averageStress: Int = 0
    @State private var maxStress: Int = 0
    @State private var minStress: Int = 0
    @State private var rangeChangeFeedback = PreparedImpactFeedbackGenerator(style: .light)

    private func updateChartStats(from chartPoints: [StressChartPoint]) {
        let stressLevels = chartPoints.map(\.level)
        averageStress = stressLevels.isEmpty ? 0 : stressLevels.reduce(0, +) / stressLevels.count
        maxStress = stressLevels.max() ?? 0
        minStress = stressLevels.min() ?? 0
    }

    /// Single write path for user range selection — no onChange feedback loop.
    private func selectRange(_ range: StressHistoryRange) {
        let oldValue = selectedRange
        StretheoLog.historyPerf.debug(
            "onChange fired: \(oldValue.rawValue, privacy: .public) -> \(range.rawValue, privacy: .public) at \(Date(), privacy: .public)"
        )
        defer {
            StretheoLog.historyPerf.debug(
                "onChange exit: \(oldValue.rawValue, privacy: .public) -> \(range.rawValue, privacy: .public) at \(Date(), privacy: .public)"
            )
        }

        guard selectedRange != range else { return }

        rangeChangeFeedback.impactAndPrepare()
        selectedRange = range

        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: range selected \(range.rawValue, privacy: .public) currentPeriod=\(viewModel.period.rawValue, privacy: .public)"
        )
        StretheoLog.history.debug(
            "STRESS_HISTORY_RANGE_CHANGE: picker selected \(range.rawValue, privacy: .public), current period=\(viewModel.period.rawValue, privacy: .public)"
        )

        viewModel.setPeriod(range.historyPeriod)

        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: range apply completed period=\(viewModel.period.rawValue, privacy: .public)"
        )
        StretheoLog.history.debug(
            "STRESS_HISTORY_RANGE_CHANGE: apply completed, period=\(viewModel.period.rawValue, privacy: .public)"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeaderView(
                    systemImage: "chart.xyaxis.line",
                    title: String(localized: "history.chart.stress_history")
                )

                StressHistoryRangePicker(
                    selection: selectedRange,
                    onSelect: selectRange
                )
                .padding(.horizontal, AppSpacing.md)
                .accessibilityLabel(String(localized: "history.period.label"))
            }

            ZStack {
                StressLineChart(
                    points: points,
                    period: viewModel.period,
                    chartDrawn: chartDrawn,
                    isEmbedded: true
                )

                if points.isEmpty && isChartLoading {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
            .frame(height: 200)
            .clipped()
            .padding(.horizontal, AppSpacing.xs)
            .padding(.bottom, AppSpacing.sm)

            HStack {
                StatPill(label: String(localized: "history.chart.stat.avg"), value: "\(averageStress)")
                Spacer()
                StatPill(label: String(localized: "history.chart.stat.high"), value: "\(maxStress)")
                Spacer()
                StatPill(label: String(localized: "history.chart.stat.low"), value: "\(minStress)")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .homeScreenCard(padding: 0)
        .onAppear {
            let synced = StressHistoryRange.from(period: viewModel.period)
            if selectedRange != synced {
                selectedRange = synced
            }
            updateChartStats(from: points)
            rangeChangeFeedback.prepare()
        }
        .onChange(of: points) { _, newPoints in
            updateChartStats(from: newPoints)
        }
    }
}

// MARK: - Custom range picker (avoids UISegmentedControl Core Haptics cold-start)

private struct StressHistoryRangePicker: View {
    let selection: StressHistoryRange
    let onSelect: (StressHistoryRange) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(StressHistoryRange.allCases) { range in
                Button {
                    onSelect(range)
                } label: {
                    Text(range.shortLabel)
                        .font(.subheadline.weight(selection == range ? .semibold : .regular))
                        .foregroundStyle(selection == range ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selection == range {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == range ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
