//
//  HistoryDataActor.swift
//  Stretheo
//
//  Background SwiftData reads for History chart data — avoids main-thread
//  performBlockAndWait contention with CloudKit mirroring.
//

import Foundation
import OSLog
import SwiftData

@ModelActor
actor HistoryDataActor {
    func fetchMeasurements(
        from start: Date,
        to end: Date,
        limit: Int = 2_500
    ) throws -> [HistoryMeasurementSnapshot] {
        let range = DateInterval(start: start, end: end)
        StretheoLog.historyPerf.debug(
            "fetchMeasurements entry range=\(range, privacy: .public) limit=\(limit, privacy: .public)"
        )
        let clock = ContinuousClock()
        let fetchStarted = clock.now

        var descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { $0.measuredAt >= start && $0.measuredAt < end },
            sortBy: [SortDescriptor(\StressMeasurement.measuredAt, order: .forward)]
        )
        descriptor.fetchLimit = limit
        let threadLabel = Thread.isMainThread ? "main" : "background"
        StretheoLog.history.debug(
            "loadData ENTER range=\(range, privacy: .public) thread=\(threadLabel, privacy: .public) site=HistoryDataActor.modelContext.fetch"
        )
        let measurements = try modelContext.fetch(descriptor)
        StretheoLog.history.debug(
            "loadData EXIT range=\(range, privacy: .public) site=HistoryDataActor.modelContext.fetch count=\(measurements.count, privacy: .public)"
        )
        let snapshots = measurements.map { measurement in
            HistoryMeasurementSnapshot(
                id: measurement.id,
                measuredAt: measurement.measuredAt,
                stressLevel: measurement.stressLevel
            )
        }

        let elapsed = fetchStarted.duration(to: clock.now)
        StretheoLog.historyPerf.debug(
            "fetchMeasurements exit range=\(range, privacy: .public) count=\(snapshots.count, privacy: .public) elapsed=\(elapsed, privacy: .public)"
        )
        return snapshots
    }
}
