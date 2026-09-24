//
//  StressChartPoint.swift
//  Stretheo
//

import Foundation
import OSLog

struct StressChartPoint: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let level: Int

    init(snapshot: HistoryMeasurementSnapshot) {
        id = snapshot.id.uuidString
        date = snapshot.measuredAt
        level = snapshot.stressLevel
    }

    init(bucketDate: Date, level: Int) {
        id = "bucket-\(bucketDate.timeIntervalSinceReferenceDate)"
        date = bucketDate
        self.level = level
    }

    static func from(
        snapshots: [HistoryMeasurementSnapshot],
        period: HistoryPeriod,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [StressChartPoint] {
        StretheoLog.historyPerf.debug(
            "chartPoints.from entry period=\(period.rawValue, privacy: .public) snapshotCount=\(snapshots.count, privacy: .public) rangeStart=\(rangeStart, privacy: .public) rangeEnd=\(rangeEnd, privacy: .public)"
        )
        let clock = ContinuousClock()
        let started = clock.now

        let inRange = snapshots.filter { $0.measuredAt >= rangeStart && $0.measuredAt < rangeEnd }
        let sorted = inRange.sorted { $0.measuredAt < $1.measuredAt }
        let points: [StressChartPoint]
        if shouldBucket(period: period, rangeStart: rangeStart, rangeEnd: rangeEnd) {
            points = bucketByFifteenMinutes(sorted)
        } else {
            points = sorted.map(StressChartPoint.init(snapshot:))
        }

        let elapsed = started.duration(to: clock.now)
        StretheoLog.historyPerf.debug(
            "chartPoints.from exit period=\(period.rawValue, privacy: .public) pointCount=\(points.count, privacy: .public) elapsed=\(elapsed, privacy: .public)"
        )
        return points
    }

    static func from(
        measurements: [StressMeasurement],
        period: HistoryPeriod,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [StressChartPoint] {
        from(
            snapshots: measurements.map {
                HistoryMeasurementSnapshot(
                    id: $0.id,
                    measuredAt: $0.measuredAt,
                    stressLevel: $0.stressLevel
                )
            },
            period: period,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    // MARK: - Intraday bucketing

    private static let bucketInterval: TimeInterval = 15 * 60

    private static func shouldBucket(
        period: HistoryPeriod,
        rangeStart: Date,
        rangeEnd: Date
    ) -> Bool {
        switch period {
        case .day:
            return true
        case .week, .month, .threeMonths, .all:
            return false
        }
    }

    private static func intradaySpanDays(rangeStart: Date, rangeEnd: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd.addingTimeInterval(-1))
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days, 1)
    }

    /// Rounds timestamps to the nearest 15 minutes and averages levels per bucket.
    private static func bucketByFifteenMinutes(_ snapshots: [HistoryMeasurementSnapshot]) -> [StressChartPoint] {
        guard !snapshots.isEmpty else { return [] }

        var levelsByBucket: [Date: [Int]] = [:]
        for snapshot in snapshots {
            let bucket = bucketStart(for: snapshot.measuredAt)
            levelsByBucket[bucket, default: []].append(snapshot.stressLevel)
        }

        return levelsByBucket.keys.sorted().map { bucket in
            let levels = levelsByBucket[bucket] ?? []
            let average = levels.reduce(0, +) / max(levels.count, 1)
            return StressChartPoint(bucketDate: bucket, level: average)
        }
    }

    private static func bucketStart(for date: Date) -> Date {
        let rounded = (date.timeIntervalSinceReferenceDate / bucketInterval).rounded() * bucketInterval
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}
