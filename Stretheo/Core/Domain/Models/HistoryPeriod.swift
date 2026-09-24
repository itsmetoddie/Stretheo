//
//  HistoryPeriod.swift
//  Stretheo
//

import Foundation

enum HistoryPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case threeMonths
    case all

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .day: String(localized: "history.period.day")
        case .week: String(localized: "history.period.week")
        case .month: String(localized: "history.period.month")
        case .threeMonths: "3M"
        case .all: String(localized: "history.chart.range.all")
        }
    }

    /// Inclusive start, exclusive end — matches `StressRepository.measurements(from:to:)`.
    func dateRange(reference: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current

        switch self {
        case .day:
            let start = calendar.startOfDay(for: reference)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? reference
            return (start, end)

        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: reference) ?? reference
            let end = calendar.date(byAdding: .day, value: 1, to: reference) ?? reference
            return (start, end)

        case .month:
            let start = calendar.date(byAdding: .day, value: -30, to: reference) ?? reference
            let end = calendar.date(byAdding: .day, value: 1, to: reference) ?? reference
            return (start, end)

        case .threeMonths:
            let start = calendar.date(byAdding: .day, value: -90, to: reference) ?? reference
            let end = calendar.date(byAdding: .day, value: 1, to: reference) ?? reference
            return (start, end)

        case .all:
            let start = calendar.date(byAdding: .year, value: -10, to: reference) ?? reference
            let end = calendar.date(byAdding: .day, value: 1, to: reference) ?? reference
            return (start, end)
        }
    }
}
