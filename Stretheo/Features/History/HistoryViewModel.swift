//
//  HistoryViewModel.swift
//  Stretheo
//

import Foundation
import OSLog
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    private let dependencies: AppDependencies
    private var loadTask: Task<Void, Never>?
    private var lastLoadedHistoryID: String?

    var period: HistoryPeriod = .week

    var displayedCalendarMonth = Date()

    var isLoading = false
    var errorMessage: String?
    var showError = false
    var exportURL: URL?
    var showExportSheet = false

    var activeDateRange: (start: Date, end: Date) {
        period.dateRange(reference: Date())
    }

    /// Drives `.task(id:)` — reloads when period changes.
    var historyLoadID: String {
        period.rawValue
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        scheduleInitialLoad()
    }

    func setPeriod(_ newPeriod: HistoryPeriod) {
        guard period != newPeriod else { return }
        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: setPeriod entry switching to \(newPeriod.rawValue, privacy: .public)"
        )
        StretheoLog.history.debug("STRESS_HISTORY_RANGE_CHANGE: setPeriod switching to \(newPeriod.rawValue, privacy: .public)")
        period = newPeriod
        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: setPeriod exit period=\(newPeriod.rawValue, privacy: .public)"
        )
    }

    func loadChartData(rangeStart: Date, rangeEnd: Date) async throws -> [StressChartPoint] {
        let periodLabel = period.rawValue
        StretheoLog.historyPerf.debug(
            "loadChartData entry period=\(periodLabel, privacy: .public) rangeStart=\(rangeStart, privacy: .public) rangeEnd=\(rangeEnd, privacy: .public)"
        )
        let clock = ContinuousClock()
        let started = clock.now
        defer {
            let elapsed = started.duration(to: clock.now)
            StretheoLog.historyPerf.debug(
                "loadChartData exit period=\(periodLabel, privacy: .public) elapsed=\(elapsed, privacy: .public)"
            )
        }

        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: loadChartData start rangeStart=\(rangeStart, privacy: .public) rangeEnd=\(rangeEnd, privacy: .public)"
        )
        let range = DateInterval(start: rangeStart, end: rangeEnd)
        StretheoLog.history.debug(
            "loadData ENTER range=\(range, privacy: .public) thread=main site=HistoryViewModel.fetchMeasurements.await"
        )
        let snapshots = try await dependencies.historyDataActor.fetchMeasurements(
            from: rangeStart,
            to: rangeEnd
        )
        StretheoLog.history.debug(
            "loadData EXIT range=\(range, privacy: .public) site=HistoryViewModel.fetchMeasurements.await count=\(snapshots.count, privacy: .public)"
        )

        let aggregationRange = range
        StretheoLog.history.debug(
            "loadData ENTER range=\(aggregationRange, privacy: .public) thread=main site=StressChartPoint.from"
        )
        let points = StressChartPoint.from(
            snapshots: snapshots,
            period: period,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
        StretheoLog.history.debug(
            "loadData EXIT range=\(aggregationRange, privacy: .public) site=StressChartPoint.from count=\(points.count, privacy: .public)"
        )
        StretheoLog.rangeSwitch.debug(
            "RANGE_SWITCH: loadChartData completed snapshots=\(snapshots.count, privacy: .public) points=\(points.count, privacy: .public)"
        )
        return points
    }

    /// Mood calendar data is built in HistoryView from `@Query`; this only tracks load-id for `.task`.
    func loadHistory(for loadID: String, colorScheme: ColorScheme) async {
        if lastLoadedHistoryID == loadID { return }
        lastLoadedHistoryID = loadID
    }

    func refresh(colorScheme: ColorScheme) async {
        lastLoadedHistoryID = nil
        await loadHistory(for: historyLoadID, colorScheme: colorScheme)
    }

    func cancelPendingWork() {
        loadTask?.cancel()
    }

    func displayedMonthDidChange(to month: Date, colorScheme: ColorScheme) {
        displayedCalendarMonth = month
    }

    /// No-op: calendar fills are computed in HistoryView from `@Query` mood entries.
    func refreshCalendarColors(colorScheme: ColorScheme) {}

    func export(type: ExportType) {
        Task {
            do {
                cleanupExportFile()
                let range = activeDateRange
                exportURL = try dependencies.exportDataUseCase.execute(
                    type: type,
                    from: range.start,
                    to: range.end
                )
                showExportSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    /// PRIVACY FIX: remove temporary export files after the share sheet closes.
    func cleanupExportFile() {
        if let url = exportURL {
            try? FileManager.default.removeItem(at: url)
        }
        exportURL = nil
    }

    // MARK: - Private

    private func scheduleInitialLoad() {
        let id = historyLoadID
        loadTask = Task { await loadHistory(for: id, colorScheme: .light) }
    }
}
