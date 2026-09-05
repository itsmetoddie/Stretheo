//
//  BackgroundTaskManager.swift
//  Stretheo
//
//  BGAppRefreshTask — fallback when HealthKit observers do not fire (~every 6h, max 1×/day).
//  HealthKit HRV observer remains the primary trigger (BackgroundStressCoordinator).
//

import BackgroundTasks
import Foundation
import OSLog

@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    private var dependencies: AppDependencies?
    private var refreshTask: Task<Void, Never>?

    private init() {}

    func configure(dependencies: AppDependencies) {
        self.dependencies = dependencies
        StretheoLog.bgTask.debug("configure — dependencies attached")
    }

    /// Schedules the next fallback refresh (6 hours). Call on launch and when entering background.
    nonisolated func scheduleNextRefresh() {
        let identifier = ServiceConstants.backgroundTaskID
        let interval = ServiceConstants.backgroundRefreshInterval
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)

        do {
            try BGTaskScheduler.shared.submit(request)
            StretheoLog.bgTask.info(
                "Next refresh scheduled (identifier: \(identifier), earliest: +\(Int(interval / 3600))h)"
            )
        } catch {
            StretheoLog.bgTask.error("Failed to schedule: \(error.localizedDescription)")
        }
    }

    func cancelPendingRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: ServiceConstants.backgroundTaskID)
        StretheoLog.bgTask.debug("Cancelled pending refresh requests")
    }

    func handleRefresh(task: BGAppRefreshTask) async {
        StretheoLog.bgTask.info("handleRefresh called at \(Date())")

        let expiration = RefreshExpirationFlag()
        task.expirationHandler = {
            expiration.markExpired()
            StretheoLog.bgTask.error("EXPIRED — ran out of time")
            Task { @MainActor in
                BackgroundTaskManager.shared.refreshTask?.cancel()
            }
        }

        if shouldSkipDueToRecentMeasurement() {
            StretheoLog.bgTask.debug(
                "IPHONE_MEASUREMENT_SKIPPED_APP_THROTTLE: BG fallback skipped — last measurement within minimumMeasurementInterval (\(Int(ServiceConstants.backgroundMeasurementMinimumInterval))s). This is the 45-minute app-level cap, not a platform limitation."
            )
            scheduleNextRefresh()
            task.setTaskCompleted(success: true)
            return
        }

        if !AppSettings.canRunBGTaskFallback() {
            StretheoLog.bgTask.debug("skipped — fallback already ran within 24 hours")
            scheduleNextRefresh()
            task.setTaskCompleted(success: true)
            return
        }

        guard AppSettings.healthSyncEnabled else {
            StretheoLog.bgTask.debug("skipped — Health sync disabled")
            scheduleNextRefresh()
            task.setTaskCompleted(success: true)
            return
        }

        guard dependencies != nil else {
            StretheoLog.bgTask.error("skipped — dependencies not configured")
            scheduleNextRefresh()
            task.setTaskCompleted(success: false)
            return
        }

        refreshTask?.cancel()
        var workSucceeded = false
        StretheoLog.bgTask.debug(
            "IPHONE_MEASUREMENT_PROCEEDING: BG fallback interval elapsed, attempting on-device stress pipeline"
        )
        refreshTask = Task {
            workSucceeded = await BackgroundStressCoordinator.shared.handleNewHealthData()
        }
        await refreshTask?.value

        if workSucceeded {
            AppSettings.recordBGTaskFallbackRun()
        }

        let success = workSucceeded && !expiration.isExpired
        if success {
            StretheoLog.bgTask.info("completed successfully")
        } else if expiration.isExpired {
            StretheoLog.bgTask.error("completed with expiration")
        } else {
            StretheoLog.bgTask.debug("completed — no measurement saved")
        }

        scheduleNextRefresh()
        task.setTaskCompleted(success: success)
    }

    private func shouldSkipDueToRecentMeasurement() -> Bool {
        guard let dependencies else { return false }
        guard let latest = try? dependencies.stressRepository.latestMeasurement() else {
            return false
        }
        return Date().timeIntervalSince(latest.measuredAt)
            < ServiceConstants.backgroundMeasurementMinimumInterval
    }

    #if DEBUG
    /// Schedules BGAppRefresh with `earliestBeginDate = nil` so Xcode **Debug → Simulate Background Fetch** can fire.
    nonisolated func scheduleForImmediateTesting() {
        let identifier = ServiceConstants.backgroundTaskID
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)

        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = nil

        do {
            try BGTaskScheduler.shared.submit(request)
            StretheoLog.bgTask.info("Scheduled for immediate testing (earliestBeginDate: nil)")
        } catch {
            StretheoLog.bgTask.error("Failed to schedule for testing: \(error.localizedDescription)")
        }
    }

    /// Debug: runs the same pipeline as HealthKit background delivery (does not use BGTaskScheduler).
    func handleRefreshManually() async {
        StretheoLog.bgTask.info("Manual simulation triggered")
        _ = await BackgroundStressCoordinator.shared.handleNewHealthData()
    }
    #endif
}

private final class RefreshExpirationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var expired = false

    func markExpired() {
        lock.lock()
        expired = true
        lock.unlock()
    }

    var isExpired: Bool {
        lock.lock()
        defer { lock.unlock() }
        return expired
    }
}
